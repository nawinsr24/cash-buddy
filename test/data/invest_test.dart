import 'package:cash_buddy/data/db.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/invest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('xirr / projection', () {
    test('known return: 100 in, 110 out after a year = 10%', () {
      final r = xirr([
        Flow(DateTime(2025, 1, 1), -100),
        Flow(DateTime(2026, 1, 1), 110),
      ]);
      expect(r, closeTo(0.10, 0.002));
    });
    test('undefined without both directions', () {
      expect(xirr([Flow(DateTime(2025), -100)]), isNull);
      expect(
        xirr([Flow(DateTime(2025), -100), Flow(DateTime(2026), -5)]),
        isNull,
      );
    });
    test('projection compounds per year', () {
      final v = projectedValue(
        [(date: DateTime(2025, 1, 1), amountMinor: 100000)],
        0.12,
        DateTime(2026, 1, 1),
      );
      expect(v, closeTo(112000, 50));
    });
  });

  group('ledger', () {
    test('contribution reduces balance, is not spending, and withdrawal returns it', () async {
      final e = await newEnv(opening: 1000000);
      final id = await e.repo.createInvestment(
        kind: 'mutual_fund',
        name: 'Nifty',
      );
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 200000,
      );
      expect(await e.repo.totalBalance(), 800000);
      final d = await e.repo.dashboard(DateRange.thisMonth(e.repo.today));
      expect(d.spending, 0);
      await e.repo.addInvestmentEntry(id, type: 'withdraw', amountMinor: 50000);
      expect(await e.repo.totalBalance(), 850000);
      expect(
        (await e.repo.dashboard(DateRange.thisMonth(e.repo.today))).income,
        0,
      );
      expect(await e.repo.checkInvariants(), isEmpty);
    });

    test('per-entry flag leaves the balance alone', () async {
      final e = await newEnv(opening: 1000000);
      final id = await e.repo.createInvestment(kind: 'stock', name: 'TCS');
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 300000,
        postToBalance: false,
      );
      expect(await e.repo.totalBalance(), 1000000);
      final s = await e.repo.investSummary(await e.repo.getInvestment(id));
      expect(s.contributed, 300000);
    });

    test(
      'global rule toggles the ledger both ways and is idempotent',
      () async {
        final e = await newEnv(opening: 1000000);
        final id = await e.repo.createInvestment(kind: 'stock', name: 'INFY');
        await e.repo.addInvestmentEntry(
          id,
          type: 'contribute',
          amountMinor: 100000,
        );
        expect(await e.repo.totalBalance(), 900000);
        await e.repo.setBalanceRule('investReducesBalance', false);
        expect(await e.repo.totalBalance(), 1000000);
        await e.repo.setBalanceRule('investReducesBalance', true);
        await e.repo.setBalanceRule('investReducesBalance', true);
        expect(await e.repo.totalBalance(), 900000);
        expect(await e.repo.checkInvariants(), isEmpty);
      },
    );

    test('deleting an entry or the investment restores the balance', () async {
      final e = await newEnv(opening: 1000000);
      final id = await e.repo.createInvestment(kind: 'mutual_fund', name: 'X');
      final en = await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 100000,
      );
      await e.repo.deleteInvestmentEntry(en);
      expect(await e.repo.totalBalance(), 1000000);
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 70000,
      );
      await e.repo.deleteInvestment(id);
      expect(await e.repo.totalBalance(), 1000000);
      expect(await e.repo.investments(), isEmpty);
    });

    test('lending rule: off keeps lent principal out of the balance', () async {
      final e = await newEnv(opening: 1000000);
      final id = await e.repo.createDebt(
        direction: 'receivable',
        counterparty: 'Ravi',
        principalMinor: 200000,
        issuedOn: e.repo.today,
      );
      expect(await e.repo.totalBalance(), 800000);
      await e.repo.setBalanceRule('lendReducesBalance', false);
      expect(await e.repo.totalBalance(), 1000000);
      await e.repo.addRepayment(id, 50000);
      expect(await e.repo.totalBalance(), 1000000);
      await e.repo.setBalanceRule('lendReducesBalance', true);
      expect(await e.repo.totalBalance(), 850000);
      expect(await e.repo.checkInvariants(), isEmpty);
    });

    test('validation and duplicate instalment', () async {
      final e = await newEnv();
      expect(
        () => e.repo.createInvestment(kind: 'stock', name: '  '),
        throwsA(isA<ValidationException>()),
      );
      final id = await e.repo.createInvestment(kind: 'custom', name: 'Chit');
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 5000,
        periodKey: 0,
      );
      expect(
        () => e.repo.addInvestmentEntry(
          id,
          type: 'contribute',
          amountMinor: 5000,
          periodKey: 0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  test('summary: gain, no-value case, projection', () async {
    final e = await newEnv(opening: 5000000);
    final id = await e.repo.createInvestment(
      kind: 'mutual_fund',
      name: 'Fund',
      expectedGrowthBps: 1200,
    );
    await e.repo.addInvestmentEntry(
      id,
      type: 'contribute',
      amountMinor: 100000,
    );
    var s = await e.repo.investSummary(await e.repo.getInvestment(id));
    expect(s.valueIsEstimate, isTrue);
    expect(s.gain, 0);
    expect(s.projected, isNotNull);
    await e.repo.setCurrentValue(id, 120000);
    s = await e.repo.investSummary(await e.repo.getInvestment(id));
    expect(s.gain, 20000);
    expect(s.gainPct, closeTo(0.2, 1e-9));
  });

  group('custom investments', () {
    test(
      'one-time and recurring are stored and read back as a schedule',
      () async {
        final e = await newEnv();
        final one = await e.repo.createInvestment(kind: 'custom', name: 'Gold');
        expect((await e.repo.getInvestment(one)).schedule, isNull);
        final rec = await e.repo.createInvestment(
          kind: 'custom',
          name: 'Gold SIP',
          sipMinor: 100000,
          startDate: DateTime.utc(2026, 11, 5),
          recurring: true,
          cycle: 'weekly',
          everyN: 2,
          weekday: 1,
          installments: 6,
        );
        final sch = (await e.repo.getInvestment(rec)).schedule!;
        expect(sch.describe(), 'Every 2 weeks on Mon');
        expect(sch.total, 6);
        expect(sch.at(0), DateTime.utc(2026, 11, 9));
      },
    );

    test('recurring needs a start date and a valid rule', () async {
      final e = await newEnv();
      expect(
        () => e.repo.createInvestment(
          kind: 'custom',
          name: 'X',
          recurring: true,
          cycle: 'monthly',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => e.repo.createInvestment(
          kind: 'custom',
          name: 'X',
          recurring: true,
          cycle: 'monthly',
          startDate: DateTime.utc(2026, 1, 1),
          monthDay: 40,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => e.repo.createInvestment(
          kind: 'custom',
          name: 'X',
          recurring: true,
          cycle: 'daily',
          startDate: DateTime.utc(2026, 1, 5),
          endDate: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'paying instalments tracks progress; one payment per instalment',
      () async {
        final e = await newEnv(opening: 1000000);
        final id = await e.repo.createInvestment(
          kind: 'custom',
          name: 'Chit',
          sipMinor: 100000,
          startDate: DateTime.utc(2026, 10, 1),
          recurring: true,
          cycle: 'monthly',
          installments: 12,
        );
        for (var k = 0; k < 3; k++) {
          await e.repo.addInvestmentEntry(
            id,
            type: 'contribute',
            amountMinor: 100000,
            periodKey: k,
          );
        }
        expect(await e.repo.totalBalance(), 700000);
        final inv = await e.repo.getInvestment(id);
        // clock is 4 Nov 2026: instalments of 1 Oct and 1 Nov are due, 1 Dec is not
        expect(inv.schedule!.dueCount(e.repo.today), 2);
        expect(
          () => e.repo.addInvestmentEntry(
            id,
            type: 'contribute',
            amountMinor: 1,
            periodKey: 1,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('old chit funds migrate to custom monthly plans', () async {
      final e = await newEnv();
      final id = await e.repo.createInvestment(
        kind: 'custom',
        name: 'Old chit',
      );
      await e.db.customStatement(
        "UPDATE investments SET kind='chit', tenure_months=10, "
        "monthly_minor=250000 WHERE id='$id'",
      );
      await e.db.customStatement(AppDatabase.chitMigrationSql);
      final inv = await e.repo.getInvestment(id);
      expect(inv.kind, 'custom');
      expect(inv.recurring, isTrue);
      expect(inv.cycle, 'monthly');
      expect(inv.installments, 10);
      expect(inv.sipMinor, 250000);
    });
  });
}

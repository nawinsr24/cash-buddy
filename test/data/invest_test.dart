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

    test('each investment entry asks: take from balance or not', () async {
      final e = await newEnv(opening: 1000000);
      final id = await e.repo.createInvestment(kind: 'stock', name: 'INFY');
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 100000,
      );
      expect(await e.repo.totalBalance(), 900000);
      await e.repo.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: 50000,
        postToBalance: false,
      );
      expect(await e.repo.totalBalance(), 900000);
      expect(
        (await e.repo.investSummary(await e.repo.getInvestment(id)))
            .contributed,
        150000,
      );
      expect(await e.repo.checkInvariants(), isEmpty);
    });

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

    test(
      'lending asks each time: off keeps that loan out of the balance',
      () async {
        final e = await newEnv(opening: 1000000);
        final on = await e.repo.createDebt(
          direction: 'receivable',
          counterparty: 'Ravi',
          principalMinor: 200000,
          issuedOn: e.repo.today,
        );
        expect(await e.repo.totalBalance(), 800000);
        final off = await e.repo.createDebt(
          direction: 'receivable',
          counterparty: 'Kumar',
          principalMinor: 100000,
          issuedOn: e.repo.today,
          affectsBalance: false,
        );
        expect(await e.repo.totalBalance(), 800000);
        await e.repo.addRepayment(off, 40000);
        expect(await e.repo.totalBalance(), 800000);
        await e.repo.addRepayment(on, 50000);
        expect(await e.repo.totalBalance(), 850000);
        // changing the answer later re-derives only that loan
        await e.repo.setDebtAffectsBalance(off, true);
        expect(await e.repo.totalBalance(), 850000 - 100000 + 40000);
        expect(await e.repo.checkInvariants(), isEmpty);
      },
    );

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

  group('stocks: buying and selling really move the balance', () {
    test('buying shares reduces the balance by shares x price, and tracks the average', () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      final id = await r.createInvestment(kind: 'stock', name: 'TCS');
      await r.buyShares(id, units: 10, pricePerUnitMinor: 250000); // 10 x 2,500
      expect(await r.totalBalance(), 10000000 - 2500000);
      var inv = await r.getInvestment(id);
      expect(inv.units, 10);
      expect(inv.buyPriceMinor, 250000);
      await r.buyShares(id, units: 10, pricePerUnitMinor: 350000); // 10 x 3,500
      expect(await r.totalBalance(), 10000000 - 2500000 - 3500000);
      inv = await r.getInvestment(id);
      expect(inv.units, 20);
      expect(inv.buyPriceMinor, 300000); // average 3,000
      // not spending
      final d = await r.dashboard(DateRange.thisMonth(e.repo.today));
      expect(d.spending, 0);
      expect(await r.checkInvariants(), isEmpty);
    });

    test('selling gives the money back; cannot sell more than held', () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      final id = await r.createInvestment(kind: 'stock', name: 'INFY');
      await r.buyShares(id, units: 10, pricePerUnitMinor: 100000);
      await r.sellShares(id, units: 4, pricePerUnitMinor: 120000);
      expect(await r.totalBalance(), 10000000 - 1000000 + 480000);
      expect((await r.getInvestment(id)).units, 6);
      expect(
        () => r.sellShares(id, units: 7, pricePerUnitMinor: 100000),
        throwsA(isA<ValidationException>()),
      );
      // profit shows once a price is set: 6 shares x 1,300 = 7,800
      await r.setSharePrice(id, 130000);
      final s = await r.investSummary(await r.getInvestment(id));
      expect(s.currentValue, 780000);
      expect(s.gain, 780000 + 480000 - 1000000);
    });

    test('the balance can be left alone for shares bought earlier', () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      final id = await r.createInvestment(kind: 'stock', name: 'WIPRO');
      await r.buyShares(
        id,
        units: 5,
        pricePerUnitMinor: 100000,
        postToBalance: false,
      );
      expect(await r.totalBalance(), 10000000);
      expect((await r.getInvestment(id)).units, 5);
    });

    test('mutual fund: a one-time purchase and a SIP instalment both reduce the balance', () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      final oneTime = await r.createInvestment(
        kind: 'mutual_fund',
        name: 'Nifty',
      );
      await r.addInvestmentEntry(
        oneTime,
        type: 'contribute',
        amountMinor: 1000000,
      );
      expect(await r.totalBalance(), 9000000);
      final sip = await r.createInvestment(
        kind: 'mutual_fund',
        name: 'Flexi SIP',
        sipMinor: 500000,
        startDate: DateTime.utc(2026, 11, 4),
        recurring: true,
        cycle: 'monthly',
        monthDay: 4,
      );
      await r.addInvestmentEntry(
        sip,
        type: 'contribute',
        amountMinor: 500000,
        periodKey: 0,
      );
      expect(await r.totalBalance(), 8500000);
      expect(
        (await r.getInvestment(sip)).schedule!.describe(),
        'Every month on the 4th',
      );
    });
  });
}

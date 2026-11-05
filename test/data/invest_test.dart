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
    test('chit month dates clamp to month end', () {
      expect(chitMonthDate(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(chitMonthDate(DateTime(2026, 11, 5), 2), DateTime(2027, 1, 5));
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

    test('validation and duplicate chit month', () async {
      final e = await newEnv();
      expect(
        () => e.repo.createInvestment(kind: 'stock', name: '  '),
        throwsA(isA<ValidationException>()),
      );
      final id = await e.repo.createInvestment(kind: 'chit', name: 'Chit');
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
}

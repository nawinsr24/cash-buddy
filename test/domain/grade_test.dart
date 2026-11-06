import 'package:cash_buddy/domain/grade.dart';
import 'package:flutter_test/flutter_test.dart';

MonthStats base({
  int income = 5000000,
  int spending = 3500000,
  int invested = 0,
  int txn = 30,
  int days = 15,
  String? top = 'Bills',
  int share = 2000,
  int overdue = 0,
  int prevAvg = 0,
  bool prevOver = false,
  int liab = 0,
  int paid = 0,
}) => MonthStats(
  income: income,
  spending: spending,
  invested: invested,
  txnCount: txn,
  activeDays: days,
  topCategory: top,
  topShareBps: share,
  overdueCount: overdue,
  prevAvgSpending: prevAvg,
  prevMonthOverspent: prevOver,
  liabilities: liab,
  paidToLiabilities: paid,
);

void main() {
  test('title rules, in priority order', () {
    expect(pickTitle(base(txn: 3)), TitleId.freshVictim);
    expect(pickTitle(base(income: 0)), TitleId.incomeGhost);
    expect(pickTitle(base(spending: 6000000)), TitleId.overdraftArtist);
    // overspending beats a high consistency streak
    expect(
      pickTitle(base(spending: 6000000, days: 28)),
      TitleId.overdraftArtist,
    );
    expect(pickTitle(base(overdue: 2, spending: 1000000)), TitleId.lateLegend);
    expect(
      pickTitle(base(spending: 2500000, invested: 100000)),
      TitleId.moneyMaster,
    );
    expect(pickTitle(base(invested: 800000)), TitleId.wealthBuilder);
    expect(pickTitle(base(liab: 500000, paid: 200000)), TitleId.debtCrusher);
    expect(pickTitle(base(spending: 3800000)), TitleId.steadySaver);
    expect(
      pickTitle(base(spending: 4100000, prevAvg: 5000000)),
      TitleId.budgetNinja,
    );
    expect(
      pickTitle(base(spending: 4200000, prevOver: true)),
      TitleId.comebackKid,
    );
    expect(
      pickTitle(base(spending: 4200000, days: 27)),
      TitleId.consistencyHero,
    );
    expect(pickTitle(base(spending: 4900000)), TitleId.salaryEvaporator);
    expect(
      pickTitle(base(spending: 4200000, top: 'Food', share: 4000)),
      TitleId.foodieBankrupt,
    );
    expect(
      pickTitle(base(spending: 4200000, top: 'Entertainment', share: 2500)),
      TitleId.treatChampion,
    );
    expect(pickTitle(base(spending: 4200000)), TitleId.balancedSpender);
  });

  test('grade parts add up, bounded, letters map', () {
    final g = computeGrade(base(spending: 2500000, invested: 800000, days: 20));
    expect(g.parts.fold<double>(0, (a, p) => a + p.max), 100);
    expect(g.score, inInclusiveRange(0, 100));
    expect(g.score, greaterThan(70));
    final bad = computeGrade(
      base(spending: 6500000, overdue: 3, days: 2, prevAvg: 3000000),
    );
    expect(bad.score, lessThan(35));
    expect(bad.letter, 'F');
    expect(const MoneyGrade(92, [], false).letter, 'A+');
    expect(const MoneyGrade(76, [], false).letter, 'B+');
    expect(const MoneyGrade(41, [], false).letter, 'D');
  });

  test(
    'budget discipline: full while within budget, falls to zero at 25% over',
    () {
      MonthStats withBudget(int spent, int budget) => MonthStats(
        income: 5000000,
        spending: spent,
        txnCount: 30,
        activeDays: 15,
        budgetMinor: budget,
      );
      expect(budgetAdherence(withBudget(900000, 1000000)), 1);
      expect(budgetAdherence(withBudget(1000000, 1000000)), 1); // exactly on
      expect(budgetAdherence(withBudget(1125000, 1000000)), closeTo(0.5, 1e-9));
      expect(budgetAdherence(withBudget(1250000, 1000000)), 0);
      expect(budgetAdherence(withBudget(9000000, 1000000)), 0);
      expect(
        budgetAdherence(const MonthStats(spending: 5)),
        1,
      ); // no budget: neutral
    },
  );

  test(
    'with a budget the grade has six parts, without it five; both add to 100',
    () {
      final withB = computeGrade(
        const MonthStats(
          income: 5000000,
          spending: 2000000,
          txnCount: 20,
          activeDays: 10,
          budgetMinor: 3000000,
        ),
      );
      final without = computeGrade(
        const MonthStats(
          income: 5000000,
          spending: 2000000,
          txnCount: 20,
          activeDays: 10,
        ),
      );
      expect(withB.parts.length, 6);
      expect(without.parts.length, 5);
      expect(withB.parts.any((p) => p.label == 'Budget discipline'), isTrue);
      expect(without.parts.any((p) => p.label == 'Budget discipline'), isFalse);
      expect(
        withB.parts.fold<double>(0, (a, p) => a + p.max),
        closeTo(100, 1e-9),
      );
      expect(
        without.parts.fold<double>(0, (a, p) => a + p.max),
        closeTo(100, 1e-9),
      );
    },
  );

  test('blowing the budget costs score; staying inside does not', () {
    MonthStats m(int spent) => MonthStats(
      income: 5000000,
      spending: spent,
      txnCount: 30,
      activeDays: 15,
      budgetMinor: 2000000,
    );
    final ok = computeGrade(m(1900000));
    final blown = computeGrade(m(2600000));
    expect(
      ok.parts.firstWhere((p) => p.label == 'Budget discipline').score,
      20,
    );
    expect(
      blown.parts.firstWhere((p) => p.label == 'Budget discipline').score,
      0,
    );
    expect(ok.score, greaterThan(blown.score));
  });

  test('level names follow the score', () {
    expect(levelFor(95), 'Excellent');
    expect(levelFor(85), 'Very good');
    expect(levelFor(72), 'Good');
    expect(levelFor(61), 'Okay');
    expect(levelFor(52), 'Average');
    expect(levelFor(42), 'Weak');
    expect(levelFor(10), 'Needs care');
  });

  test('biggest gap points at the weakest part', () {
    final g = computeGrade(
      const MonthStats(
        income: 5000000,
        spending: 1000000,
        txnCount: 30,
        activeDays: 20,
      ),
    );
    expect(g.biggestGap, isNotNull);
    expect(g.biggestGap!.label, 'Wealth growth'); // nothing invested
  });

  test('thin data is flagged as building', () {
    expect(computeGrade(base(txn: 4)).building, isTrue);
    expect(computeGrade(base()).building, isFalse);
  });

  test('every title has roast and kind lines with numbers filled in', () {
    final s = base(
      spending: 6000000,
      top: 'Food',
      share: 4000,
      overdue: 2,
      invested: 900000,
      liab: 1,
      paid: 1,
    );
    for (final t in TitleId.values) {
      for (final roast in [true, false]) {
        final lines = titleLines(t, s, roast: roast);
        expect(lines, isNotEmpty, reason: '$t');
        for (final l in lines) {
          expect(
            l.contains('\$'),
            isFalse,
            reason: 'unfilled placeholder in $l',
          );
          expect(l.contains('null'), isFalse, reason: l);
        }
      }
      expect(t.emoji, isNotEmpty);
      expect(t.rule, isNotEmpty);
    }
  });

  test('next step is concrete and tone follows roast mode', () {
    final s = base(spending: 4500000);
    expect(nextStep(s, roast: true), contains('Steady Saver'));
    expect(nextStep(s, roast: false), contains('Steady Saver'));
    expect(nextStep(base(income: 0)), isNotEmpty);
  });

  test('projected spending scales an unfinished month', () {
    const s = MonthStats(spending: 100000, daysInMonth: 30, daysElapsed: 10);
    expect(s.projectedSpending, 300000);
    expect(s.complete, isFalse);
  });

  group('health', () {
    MonthStats hs(int health, int count, {int spending = 3000000}) =>
        MonthStats(
          income: 5000000,
          spending: spending,
          txnCount: 30,
          activeDays: 10,
          healthSpending: health,
          healthCount: count,
        );

    test('no health spending means no note', () {
      expect(healthNote(hs(0, 0)), isNull);
    });

    test('light month: kind note with the amount, no jokes', () {
      final n = healthNote(hs(50000, 1))!;
      expect(n, contains('₹500.00'));
      expect(n.toLowerCase(), isNot(contains('roast')));
      expect(hs(50000, 1).healthHeavy, isFalse);
      expect(hs(50000, 1).healthDriven, isFalse);
    });

    test('heavy month (3+ payments or 15%+) gets the stronger caring note', () {
      expect(hs(50000, 3).healthHeavy, isTrue);
      expect(hs(500000, 1).healthHeavy, isTrue); // 16.7% of spending
      final n = healthNote(hs(500000, 4))!;
      expect(n, contains('doctor'));
    });

    test('note is stable for the same month and varies by seed', () {
      final a = healthNote(hs(50000, 1), seed: '2026-10');
      expect(healthNote(hs(50000, 1), seed: '2026-10'), a);
      final all = {
        for (final seed in ['a', 'b', 'c', 'd', 'e', 'f'])
          healthNote(hs(50000, 1), seed: seed),
      };
      expect(all.length, greaterThan(1));
    });

    test('a health-driven month is never roasted, even in roast mode', () {
      final s = MonthStats(
        income: 4000000,
        spending: 5000000, // overspent because of a medical month
        txnCount: 30,
        activeDays: 10,
        healthSpending: 2500000,
        healthCount: 6,
      );
      expect(s.healthDriven, isTrue);
      expect(pickTitle(s), TitleId.overdraftArtist);
      final lines = titleLines(TitleId.overdraftArtist, s, roast: true);
      final kind = titleLines(TitleId.overdraftArtist, s, roast: false);
      expect(lines, kind); // same gentle lines
      expect(nextStep(s, roast: true), nextStep(s, roast: false));
    });

    test('a non-medical overspend is still roasted', () {
      final s = MonthStats(
        income: 4000000,
        spending: 5000000,
        txnCount: 30,
        activeDays: 10,
      );
      expect(
        titleLines(TitleId.overdraftArtist, s, roast: true),
        isNot(titleLines(TitleId.overdraftArtist, s, roast: false)),
      );
    });
  });

  test('high-interest borrowing cannot hide behind good saving', () {
    const great = MonthStats(
      income: 10000000,
      spending: 5000000,
      invested: 2000000,
      activeDays: 25,
      txnCount: 40,
      prevAvgSpending: 6000000,
    );
    final clean = computeGrade(great);
    expect(clean.score, greaterThanOrEqualTo(85));
    // ₹3,00,000 owed at 2% a month (24% a year): interest ₹6,000 a month
    final borrowed = computeGrade(
      MonthStats(
        income: 10000000,
        spending: 5000000,
        invested: 2000000,
        activeDays: 25,
        txnCount: 40,
        prevAvgSpending: 6000000,
        liabilities: 30000000,
        debtMonthlyInterest: 600000,
        maxDebtApr: 24,
      ),
    );
    expect(borrowed.score, lessThanOrEqualTo(69));
    expect(borrowed.score, lessThan(clean.score - 15));
    // 3% a month is worse still
    final worse = computeGrade(
      MonthStats(
        income: 10000000,
        spending: 5000000,
        invested: 2000000,
        activeDays: 25,
        txnCount: 40,
        prevAvgSpending: 6000000,
        liabilities: 30000000,
        debtMonthlyInterest: 900000,
        maxDebtApr: 36,
      ),
    );
    expect(worse.score, lessThan(borrowed.score));
    // cheap debt (8% a year) costs little
    final cheap = computeGrade(
      MonthStats(
        income: 10000000,
        spending: 5000000,
        invested: 2000000,
        activeDays: 25,
        txnCount: 40,
        prevAvgSpending: 6000000,
        liabilities: 30000000,
        debtMonthlyInterest: 200000,
        maxDebtApr: 8,
      ),
    );
    expect(cheap.score, greaterThan(borrowed.score));
  });
}

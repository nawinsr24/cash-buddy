import 'package:cash_buddy/domain/grade.dart';
import 'package:cash_buddy/domain/summary.dart';
import 'package:flutter_test/flutter_test.dart';

List<SummaryLine> sum(MonthStats s) => performanceSummary(s, computeGrade(s));

MonthStats base({
  int income = 10000000,
  int spending = 5000000,
  int invested = 0,
  int liabilities = 0,
  int interest = 0,
  double apr = 0,
  int overdue = 0,
}) => MonthStats(
  income: income,
  spending: spending,
  invested: invested,
  txnCount: 30,
  activeDays: 20,
  liabilities: liabilities,
  debtMonthlyInterest: interest,
  maxDebtApr: apr,
  overdueCount: overdue,
  topCategory: 'Food',
  topShareBps: 2000,
);

void main() {
  test('always three lines, each with an emoji and text', () {
    for (final s in [
      const MonthStats(),
      base(),
      base(spending: 12000000),
      base(liabilities: 30000000, interest: 600000, apr: 24),
    ]) {
      final lines = sum(s);
      expect(lines.length, 3);
      for (final l in lines) {
        expect(l.emoji, isNotEmpty);
        expect(l.text.length, greaterThan(10));
      }
    }
  });

  test('a new month asks for entries instead of judging', () {
    final l = sum(const MonthStats(txnCount: 2, spending: 10000));
    expect(l[0].text, contains('just begun'));
  });

  test('high-interest debt is called out with its monthly cost and tells you to clear it first', () {
    final l = sum(base(liabilities: 30000000, interest: 600000, apr: 24));
    expect(l[1].text, contains('24%'));
    expect(l[1].text, contains('₹6,000'));
    expect(l[2].text.toLowerCase(), contains('highest interest'));
  });

  test('overspending is stated in plain numbers', () {
    final l = sum(base(spending: 12000000));
    expect(l[0].text, contains('₹20,000.00 more than you have'));
  });

  test('a good month ends on encouragement', () {
    final l = sum(base(spending: 5000000, invested: 2000000));
    expect(l[2].emoji, '🌟');
  });

  test('no income never ends on "doing really well"', () {
    final l = sum(
      const MonthStats(
        spending: 953500,
        txnCount: 20,
        daysElapsed: 6,
        daysInMonth: 30,
        budgetMinor: 3500000,
      ),
    );
    expect(l[2].emoji, isNot('🌟'));
    expect(l[2].text, contains('income'));
  });

  test('names the biggest want and roasts it only when roast is on', () {
    final s = MonthStats(
      income: 10000000,
      spending: 5000000,
      txnCount: 30,
      subs: const {'Hotel & Restaurant': 1500000},
      mains: const {'Food': 1500000},
    );
    final hot = performanceSummary(s, computeGrade(s));
    expect(hot[1].text, contains('Hotel & Restaurant'));
    expect(hot[1].text, contains('kitchen'));
    final mild = performanceSummary(s, computeGrade(s), roast: false);
    expect(mild[1].text, isNot(contains('kitchen')));
  });

  test('over-budget pace gives a daily allowance', () {
    final s = MonthStats(
      income: 10000000,
      spending: 2000000,
      txnCount: 30,
      daysElapsed: 10,
      daysInMonth: 30,
      budgetMinor: 4000000,
    );
    final l = performanceSummary(s, computeGrade(s));
    expect(l[2].text, contains('a day for the next 20 days'));
  });

  test('new category titles are picked', () {
    MonthStats m(Map<String, int> subs) => MonthStats(
      income: 10000000,
      spending: 9000000,
      txnCount: 30,
      activeDays: 10,
      subs: subs,
    );
    expect(pickTitle(m({'Hotel & Restaurant': 3000000})), TitleId.orderInKing);
    expect(pickTitle(m({'Gift to Lover': 900000})), TitleId.giftCupid);
    expect(pickTitle(m({'Late Fees': 400000})), TitleId.feeDonor);
  });
}

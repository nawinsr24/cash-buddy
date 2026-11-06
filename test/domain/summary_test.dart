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
    expect(l[0].text, contains('₹20,000.00 more than you earned'));
  });

  test('a good month ends on encouragement', () {
    final l = sum(base(spending: 5000000, invested: 2000000));
    expect(l[2].emoji, '🌟');
  });
}

import 'grade.dart';
import 'money.dart';

/// One line of the performance summary.
class SummaryLine {
  final String emoji, text;
  const SummaryLine(this.emoji, this.text);
}

String _m(int minor) => Money.format(minor.abs());

/// A short, personal 3-line read of the month, built only from the user's own
/// numbers (nothing leaves the phone). Line 1: how the month is going.
/// Line 2: the single most important thing behind it. Line 3: one clear step.
List<SummaryLine> performanceSummary(MonthStats s, MoneyGrade g) {
  if (s.thin || (s.income <= 0 && s.spending <= 0)) {
    return const [
      SummaryLine(
        '🌱',
        'Your month has just begun, so there is not much to read yet.',
      ),
      SummaryLine(
        '📝',
        'Add your income and spending as they happen, even small ones.',
      ),
      SummaryLine(
        '✨',
        'After 10 entries I will give you your first full summary.',
      ),
    ];
  }

  // ── line 1: the money story ──
  final SummaryLine one;
  if (s.income <= 0) {
    one = SummaryLine(
      '🧾',
      'You spent ${_m(s.spending)} this month, but no income is added yet.',
    );
  } else if (s.spending > s.income) {
    one = SummaryLine(
      '🚨',
      'You earned ${_m(s.income)} but spent ${_m(s.spending)}. That is ${_m(s.spending - s.income)} more than you earned.',
    );
  } else {
    final pct = (s.saveRate * 100).round();
    one = SummaryLine(
      pct >= 20 ? '💚' : '🙂',
      'You earned ${_m(s.income)}, spent ${_m(s.spending)} and kept ${_m(s.saved)} ($pct% of your income).',
    );
  }

  // ── line 2: what matters most (first match wins) ──
  SummaryLine two;
  final highDebt = s.debtMonthlyInterest > 0 && s.maxDebtApr >= 18;
  if (highDebt) {
    two = SummaryLine(
      '🏦',
      'You owe ${_m(s.liabilities)} with interest up to ${s.maxDebtApr.round()}% a year. This costs you about ${_m(s.debtMonthlyInterest)} every month.',
    );
  } else if (s.overdueCount > 0) {
    two = SummaryLine(
      '⏰',
      '${s.overdueCount} payment${s.overdueCount == 1 ? ' is' : 's are'} overdue. Paying late can cost you extra.',
    );
  } else if (s.budgetMinor != null &&
      s.budgetMinor! > 0 &&
      s.projectedSpending > s.budgetMinor!) {
    two = SummaryLine(
      '🎯',
      'At this speed you will spend ${_m(s.projectedSpending)}, which is ${_m(s.projectedSpending - s.budgetMinor!)} above your budget.',
    );
  } else if (s.topCategory != null && s.topShareBps >= 3500 && s.spending > 0) {
    two = SummaryLine(
      '📊',
      '${s.topCategory} took ${(s.topShareBps / 100).round()}% of your spending (${_m((s.spending * s.topShareBps / 10000).round())}). That is your biggest area.',
    );
  } else if (s.prevAvgSpending > 0 &&
      s.projectedSpending < s.prevAvgSpending * 0.9) {
    two = SummaryLine(
      '📉',
      'You are spending less than your usual. Good control.',
    );
  } else if (s.invested > 0) {
    two = SummaryLine(
      '📈',
      'You invested ${_m(s.invested)} this month. Good for your future.',
    );
  } else {
    two = SummaryLine(
      '⚖️',
      'Your spending is close to your usual. No big surprises this month.',
    );
  }

  // ── line 3: one clear step ──
  final SummaryLine three;
  if (highDebt) {
    three = const SummaryLine(
      '👉',
      'Pay back the loan with the highest interest first. It is the fastest way to raise your Money Health.',
    );
  } else if (s.overdueCount > 0) {
    three = const SummaryLine(
      '👉',
      'Clear the overdue payments first, then everything else.',
    );
  } else if (s.income > 0 && s.spending > s.income) {
    three = SummaryLine(
      '👉',
      'Cut ${_m(s.spending - s.income)} from spending, starting with ${s.topCategory ?? 'your biggest area'}.',
    );
  } else if (s.income > 0 && s.saveRate < 0.2) {
    three = SummaryLine(
      '👉',
      'Try to keep ${_m((s.income * 0.2).round() - s.saved)} more this month to reach 20% savings.',
    );
  } else if (s.income > 0 && s.investRate < 0.15) {
    three = SummaryLine(
      '👉',
      'Invest ${_m((s.income * 0.15).round() - s.invested)} more to reach 15% of your income.',
    );
  } else {
    three = const SummaryLine(
      '🌟',
      'You are doing really well. Keep the same habits next month.',
    );
  }
  return [one, two, three];
}

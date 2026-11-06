import 'grade.dart';
import 'money.dart';

/// One line of the performance summary.
class SummaryLine {
  final String emoji, text;
  const SummaryLine(this.emoji, this.text);
}

String _m(int minor) => Money.format(minor.abs());

const _wants = [
  'Hotel & Restaurant',
  'Food Delivery',
  'Snacks',
  'Sweets & Bakery',
  'Online Shopping',
  'Clothes',
  'Footwear',
  'Electronics & Gadgets',
  'Mobile & Accessories',
  'Salon & Parlour',
  'Cosmetics & Makeup',
  'Movies & Outings',
  'Events & Shows',
  'Gift to Lover',
  'Dates & Outings',
  'Cigarettes',
  'Liquor',
];

const _quips = {
  'Hotel & Restaurant': 'Your kitchen is feeling ignored.',
  'Food Delivery':
      'The delivery partner knows your door better than your neighbours do.',
  'Snacks': 'Small bites, big bill.',
  'Sweets & Bakery': 'Sweet tooth, bitter bank balance.',
  'Online Shopping': 'One-click is the most expensive click.',
  'Clothes': 'The wardrobe is full, the wallet is not.',
  'Footwear': 'Walking in style, walking away from savings.',
  'Electronics & Gadgets': 'The old one was working fine, was it not?',
  'Mobile & Accessories': 'Your phone upgrades faster than your savings.',
  'Salon & Parlour': 'Looking sharp, feeling light in the pocket.',
  'Cosmetics & Makeup': 'Glowing face, dim account.',
  'Movies & Outings': 'The popcorn alone could pay a bill.',
  'Gift to Lover': 'Love is priceless, gifts are not.',
  'Dates & Outings': 'Romance is great, but so is a balance.',
  'Cigarettes': 'It goes up in smoke, literally.',
  'Liquor': 'Cheers, but your wallet is not drinking to that.',
};

/// A short, personal 3-line read of the month, built only from the user's own
/// numbers (nothing leaves the phone). Line 1: how the month is going.
/// Line 2: the single most important thing behind it. Line 3: one clear step
/// that always agrees with the first two lines.
List<SummaryLine> performanceSummary(
  MonthStats s,
  MoneyGrade g, {
  bool roast = true,
}) {
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
  if (s.healthDriven || s.homeDriven) roast = false;

  final elapsed = s.daysElapsed < 1 ? 1 : s.daysElapsed;
  final perDay = (s.spending / elapsed).round();
  final left = s.daysInMonth - s.daysElapsed;
  final budget = s.budgetMinor ?? 0;
  final overBudgetPace = budget > 0 && s.projectedSpending > budget;
  final budgetGone = budget > 0 && s.spending >= budget;
  final highDebt = s.debtMonthlyInterest > 0 && s.maxDebtApr >= 18;
  final noIncome = s.income <= 0;
  final overspent = s.income > 0 && s.spending > s.income;
  final lowSave = s.income > 0 && s.saveRate < 0.2;

  // The biggest "want" (restaurant, shopping, gadgets...) by name.
  String? wantName;
  var wantAmt = 0;
  for (final n in _wants) {
    final a = s.subs[n] ?? 0;
    if (a > wantAmt) {
      wantAmt = a;
      wantName = n;
    }
  }
  // The biggest sub-category of all.
  String? topSub;
  var topSubAmt = 0;
  s.subs.forEach((n, a) {
    if (a > topSubAmt) {
      topSubAmt = a;
      topSub = n;
    }
  });

  // ── line 1: the money story ──
  final SummaryLine one;
  final vsLast = s.prevSpending > 0 && s.daysElapsed >= 7
      ? ((s.projectedSpending - s.prevSpending) * 100 / s.prevSpending).round()
      : null;
  final trend = vsLast == null || vsLast.abs() < 8
      ? ''
      : vsLast > 0
      ? ' At this pace the month ends $vsLast% above last month.'
      : ' At this pace the month ends ${-vsLast}% below last month.';
  if (noIncome) {
    one = SummaryLine(
      '🧾',
      '${_m(s.spending)} gone in ${s.daysElapsed} days (${_m(perDay)} a day) and no income added, so I cannot tell if this is safe.$trend',
    );
  } else if (overspent) {
    one = SummaryLine(
      '🚨',
      'You earned ${_m(s.income)} but spent ${_m(s.spending)}, which is ${_m(s.spending - s.income)} more than you have.$trend',
    );
  } else {
    final pct = (s.saveRate * 100).round();
    one = SummaryLine(
      pct >= 20 ? '💚' : '🙂',
      'You earned ${_m(s.income)}, spent ${_m(s.spending)} and kept ${_m(s.saved)} ($pct%).$trend',
    );
  }

  // ── line 2: the one thing that matters most (highest score wins) ──
  final cands = <(int, SummaryLine)>[];
  void add(int score, String emoji, String text) =>
      cands.add((score, SummaryLine(emoji, text)));
  if (highDebt) {
    add(
      100,
      '🏦',
      'You owe ${_m(s.liabilities)} at up to ${s.maxDebtApr.round()}% a year, which costs about ${_m(s.debtMonthlyInterest)} every month.',
    );
  }
  if (s.overdueCount > 0) {
    add(
      95,
      '⏰',
      '${s.overdueCount} payment${s.overdueCount == 1 ? ' is' : 's are'} overdue. Late payments cost extra.',
    );
  }
  if (budgetGone) {
    add(
      92,
      '🛑',
      'Your whole budget of ${_m(budget)} is already used, with $left day${left == 1 ? '' : 's'} still to go.',
    );
  } else if (overBudgetPace) {
    add(
      85,
      '🎯',
      'At ${_m(perDay)} a day you will spend ${_m(s.projectedSpending)}, which is ${_m(s.projectedSpending - budget)} above your budget.',
    );
  }
  if (s.pctOf(['Late Fees', 'Bank Charges', 'Fines']) >= 3) {
    add(
      80,
      '🪙',
      '${_m(s.catSum(['Late Fees', 'Bank Charges', 'Fines']))} went on fees and fines. That is money for nothing.',
    );
  }
  if (s.viceSpending * 100 >= s.spending * 12 && s.spending > 0) {
    add(
      78,
      '🚬',
      'Cigarettes and liquor took ${_m(s.viceSpending)} (${(s.viceSpending * 100 / s.spending).round()}% of spending).${roast ? ' Money that burns twice.' : ''}',
    );
  }
  if (wantName != null && wantAmt * 100 >= s.spending * 15) {
    final p = (wantAmt * 100 / s.spending).round();
    add(
      76,
      '🔎',
      '$wantName alone took ${_m(wantAmt)} ($p% of spending).${roast ? ' ${_quips[wantName]}' : ''}',
    );
  } else if (topSub != null && topSubAmt * 100 >= s.spending * 20) {
    add(
      70,
      '🔎',
      '$topSub is your biggest sub-category at ${_m(topSubAmt)} (${(topSubAmt * 100 / s.spending).round()}% of spending).',
    );
  }
  if (s.topCategory != null && s.topShareBps >= 3500 && s.spending > 0) {
    add(
      68,
      '📊',
      '${s.topCategory} took ${(s.topShareBps / 100).round()}% of your spending (${_m((s.spending * s.topShareBps / 10000).round())}). Everything else is small next to it.',
    );
  }
  if (s.biggestAmt * 100 >= s.spending * 25 && s.biggestLabel != null) {
    add(
      64,
      '🧨',
      'One payment (${s.biggestLabel}, ${_m(s.biggestAmt)}) is ${(s.biggestAmt * 100 / s.spending).round()}% of the whole month.',
    );
  }
  if (vsLast != null && vsLast >= 25) {
    add(
      60,
      '📈',
      'Your spending is running $vsLast% above last month.${roast ? ' Who hurt you?' : ''}',
    );
  }
  if (s.prevAvgSpending > 0 && s.projectedSpending < s.prevAvgSpending * 0.9) {
    add(45, '📉', 'You are spending less than your usual. Good control.');
  }
  if (s.invested > 0) {
    add(
      40,
      '📈',
      'You invested ${_m(s.invested)} this month. That is future you saying thanks.',
    );
  }
  add(
    10,
    '⚖️',
    'Your spending is close to your usual. No big surprises this month.',
  );
  cands.sort((a, b) => b.$1.compareTo(a.$1));
  final two = cands.first.$2;

  // ── line 3: one clear step that agrees with the lines above ──
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
  } else if (noIncome) {
    three = const SummaryLine(
      '👉',
      'Add your income so I can check your savings. Until then, watch the daily spending.',
    );
  } else if (budgetGone) {
    three = SummaryLine(
      '👉',
      'Budget is finished. Pause eating out and shopping for the next $left day${left == 1 ? '' : 's'} and keep only the must-haves.',
    );
  } else if (overBudgetPace && left > 0) {
    final perDayLeft = ((budget - s.spending) / left).round();
    three = SummaryLine(
      '👉',
      'Keep to ${_m(perDayLeft)} a day for the next $left days to finish inside your budget.',
    );
  } else if (overspent) {
    three = SummaryLine(
      '👉',
      'Cut ${_m(s.spending - s.income)} from spending${wantName != null ? ', starting with $wantName' : ''}.',
    );
  } else if (lowSave) {
    final need = (s.income * 0.2).round() - s.saved;
    three = wantName != null
        ? SummaryLine(
            '👉',
            'Cutting $wantName by a third frees ${_m((wantAmt / 3).round())}. Keep ${_m(need)} more to reach 20% savings.',
          )
        : SummaryLine(
            '👉',
            'Try to keep ${_m(need)} more this month to reach 20% savings.',
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

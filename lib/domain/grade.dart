import 'dart:math' as math;

import 'money.dart';

/// Everything the Money Grade and the monthly title are computed from.
/// All amounts are minor units. Pure data: no database, no clock.
class MonthStats {
  final int income, spending, invested;

  /// Average spending of the previous three months (0 when there is no history).
  final int prevAvgSpending;
  final bool prevMonthOverspent;
  final int txnCount, activeDays;

  /// Biggest spending category (rolled up to its parent) and its share of
  /// spending in basis points.
  final String? topCategory;
  final int topShareBps;
  final int overdueCount;

  /// Liabilities still owed at month end, and what was repaid on them in the month.
  final int liabilities, paidToLiabilities;

  /// Month length and how many of its days have passed (equal when complete).
  final int daysInMonth, daysElapsed;

  /// Spending on health care (medicine, doctors, hospitals, labs) and how many
  /// payments that was.
  final int healthSpending, healthCount;

  /// The month's budget, when one is set.
  final int? budgetMinor;

  const MonthStats({
    this.income = 0,
    this.spending = 0,
    this.invested = 0,
    this.prevAvgSpending = 0,
    this.prevMonthOverspent = false,
    this.txnCount = 0,
    this.activeDays = 0,
    this.topCategory,
    this.topShareBps = 0,
    this.overdueCount = 0,
    this.liabilities = 0,
    this.paidToLiabilities = 0,
    this.daysInMonth = 30,
    this.daysElapsed = 30,
    this.healthSpending = 0,
    this.healthCount = 0,
    this.budgetMinor,
  });

  bool get complete => daysElapsed >= daysInMonth;

  /// The month as it is likely to end: spending scaled to the full month.
  /// Used for the live title so a half-finished month is not judged against
  /// a whole one.
  MonthStats projectedForTitle() => complete
      ? this
      : MonthStats(
          income: income,
          spending: projectedSpending,
          invested: invested,
          prevAvgSpending: prevAvgSpending,
          prevMonthOverspent: prevMonthOverspent,
          txnCount: txnCount,
          activeDays: activeDays,
          topCategory: topCategory,
          topShareBps: topShareBps,
          overdueCount: overdueCount,
          liabilities: liabilities,
          paidToLiabilities: paidToLiabilities,
          daysInMonth: daysInMonth,
          daysElapsed: daysInMonth,
          healthSpending: healthSpending,
          healthCount: healthCount,
          budgetMinor: budgetMinor,
        );
  int get saved => income - spending;
  double get saveRate => income <= 0 ? 0 : saved / income;
  double get investRate => income <= 0 ? 0 : invested / income;

  /// Spending for the whole month: actual when complete, else scaled up by pace.
  int get projectedSpending => complete || daysElapsed <= 0
      ? spending
      : (spending * daysInMonth / daysElapsed).round();

  /// Too little to judge: under 10 entries.
  bool get thin => txnCount < 10;

  /// Health took a big part of the month (30%+ of spending): never roast that.
  bool get healthDriven =>
      healthSpending > 0 && spending > 0 && healthSpending * 10 >= spending * 3;

  /// Several payments or a real share of spending: a rough health month.
  bool get healthHeavy =>
      healthSpending > 0 &&
      (healthCount >= 3 ||
          (spending > 0 && healthSpending * 100 >= spending * 15));
}

enum TitleId {
  freshVictim,
  incomeGhost,
  overdraftArtist,
  lateLegend,
  moneyMaster,
  wealthBuilder,
  debtCrusher,
  steadySaver,
  budgetNinja,
  comebackKid,
  consistencyHero,
  salaryEvaporator,
  foodieBankrupt,
  treatChampion,
  balancedSpender,
}

extension TitleInfo on TitleId {
  String get emoji => switch (this) {
    TitleId.freshVictim => '🌱',
    TitleId.incomeGhost => '👻',
    TitleId.overdraftArtist => '🕳️',
    TitleId.lateLegend => '🧾',
    TitleId.moneyMaster => '👑',
    TitleId.wealthBuilder => '📈',
    TitleId.debtCrusher => '🧹',
    TitleId.steadySaver => '🛡️',
    TitleId.budgetNinja => '🥷',
    TitleId.comebackKid => '🧗',
    TitleId.consistencyHero => '🔥',
    TitleId.salaryEvaporator => '💸',
    TitleId.foodieBankrupt => '🍔',
    TitleId.treatChampion => '🛍️',
    TitleId.balancedSpender => '🧭',
  };

  String get title => switch (this) {
    TitleId.freshVictim => 'Fresh Victim',
    TitleId.incomeGhost => 'Income Ghost',
    TitleId.overdraftArtist => 'Overdraft Artist',
    TitleId.lateLegend => 'Late Payment Legend',
    TitleId.moneyMaster => 'Money Master',
    TitleId.wealthBuilder => 'Wealth Builder',
    TitleId.debtCrusher => 'Debt Crusher',
    TitleId.steadySaver => 'Steady Saver',
    TitleId.budgetNinja => 'Budget Ninja',
    TitleId.comebackKid => 'Comeback Kid',
    TitleId.consistencyHero => 'Consistency Hero',
    TitleId.salaryEvaporator => 'Salary Evaporator',
    TitleId.foodieBankrupt => 'Foodie Bankrupt',
    TitleId.treatChampion => 'Treat Yourself Champion',
    TitleId.balancedSpender => 'Balanced Spender',
  };

  /// Why you got it, in plain words (shown on the reveal card).
  String get rule => switch (this) {
    TitleId.freshVictim => 'Fewer than 10 entries this month.',
    TitleId.incomeGhost => 'Spending recorded but no income.',
    TitleId.overdraftArtist => 'You spent more than you earned.',
    TitleId.lateLegend => 'You had overdue instalments or debts.',
    TitleId.moneyMaster => 'Saved 40%+ of income and invested.',
    TitleId.wealthBuilder => 'Invested 15%+ of income.',
    TitleId.debtCrusher => 'Repaid 15%+ of what you owed.',
    TitleId.steadySaver => 'Saved 20%+ of income.',
    TitleId.budgetNinja => 'Spent 10%+ below your 3-month average.',
    TitleId.comebackKid => 'Last month overspent, this month did not.',
    TitleId.consistencyHero => 'Logged on 25+ days.',
    TitleId.salaryEvaporator => 'Spent 95%+ of your income.',
    TitleId.foodieBankrupt => 'Food was your top spend at 30%+.',
    TitleId.treatChampion => 'Shopping or fun was your top spend.',
    TitleId.balancedSpender => 'Nothing stood out, good or bad.',
  };

  bool get positive => switch (this) {
    TitleId.moneyMaster ||
    TitleId.wealthBuilder ||
    TitleId.debtCrusher ||
    TitleId.steadySaver ||
    TitleId.budgetNinja ||
    TitleId.comebackKid ||
    TitleId.consistencyHero => true,
    _ => false,
  };
}

bool _isFood(String? c) => (c ?? '').toLowerCase().contains('food');
bool _isFun(String? c) {
  final n = (c ?? '').toLowerCase();
  return n.contains('entertain') || n.contains('shop');
}

/// First matching rule wins. Order matters: bad months are called out before
/// mild positives so nobody gets a medal for overspending.
TitleId pickTitle(MonthStats s) {
  if (s.thin) return TitleId.freshVictim;
  if (s.income <= 0 && s.spending > 0) return TitleId.incomeGhost;
  if (s.income > 0 && s.spending > s.income) return TitleId.overdraftArtist;
  if (s.overdueCount > 0) return TitleId.lateLegend;
  if (s.saveRate >= 0.4 && s.invested > 0) return TitleId.moneyMaster;
  if (s.investRate >= 0.15) return TitleId.wealthBuilder;
  final owedBase = s.liabilities + s.paidToLiabilities;
  if (s.paidToLiabilities > 0 &&
      owedBase > 0 &&
      s.paidToLiabilities / owedBase >= 0.15) {
    return TitleId.debtCrusher;
  }
  if (s.saveRate >= 0.2) return TitleId.steadySaver;
  if (s.prevAvgSpending > 0 && s.spending <= s.prevAvgSpending * 0.9) {
    return TitleId.budgetNinja;
  }
  if (s.prevMonthOverspent) return TitleId.comebackKid;
  if (s.activeDays >= 25) return TitleId.consistencyHero;
  if (s.income > 0 && s.spending >= s.income * 0.95) {
    return TitleId.salaryEvaporator;
  }
  if (_isFood(s.topCategory) && s.topShareBps >= 3000) {
    return TitleId.foodieBankrupt;
  }
  if (_isFun(s.topCategory)) return TitleId.treatChampion;
  return TitleId.balancedSpender;
}

/// The title you hold right now, mid-month. The first week is too noisy to
/// judge, so it stays "Fresh Victim" until a week of entries exists.
TitleId liveTitleFor(MonthStats s) {
  if (!s.complete && s.daysElapsed < 7) return TitleId.freshVictim;
  return pickTitle(s.projectedForTitle());
}

// ───────────────────────── Plus Score ─────────────────────────
/// One of the parts the Plus Score is made of.
class GradePart {
  final String label, hint;
  final double score, max;
  const GradePart(this.label, this.score, this.max, [this.hint = '']);
  double get fraction => max == 0 ? 0 : score / max;
}

/// The Plus Score: 0..100 for a month, with a named level.
/// (The class keeps its old name; the app calls it "Plus Score".)
class MoneyGrade {
  final int score; // 0..100
  final List<GradePart> parts;
  final bool building; // not enough data to be fair yet
  const MoneyGrade(this.score, this.parts, this.building);

  /// Named level shown next to the number.
  String get level => levelFor(score);

  String get letter {
    const steps = [
      (90, 'A+'),
      (85, 'A'),
      (80, 'A−'),
      (75, 'B+'),
      (70, 'B'),
      (65, 'B−'),
      (60, 'C+'),
      (55, 'C'),
      (50, 'C−'),
      (40, 'D'),
    ];
    for (final s in steps) {
      if (score >= s.$1) return s.$2;
    }
    return 'F';
  }

  /// The part with the most points still on the table.
  GradePart? get biggestGap {
    GradePart? worst;
    for (final p in parts) {
      if (worst == null || (p.max - p.score) > (worst.max - worst.score)) {
        worst = p;
      }
    }
    return worst;
  }
}

String levelFor(int score) {
  if (score >= 90) return 'Elite';
  if (score >= 80) return 'Excellent';
  if (score >= 70) return 'Strong';
  if (score >= 60) return 'Solid';
  if (score >= 50) return 'Fair';
  if (score >= 40) return 'Needs work';
  return 'Reset needed';
}

double _clamp01(double v) => v.isNaN ? 0 : math.max(0.0, math.min(1.0, v));

/// How well spending followed the budget: 1.0 while at or under it, then
/// falling in a straight line to 0 at 25% over. Early in a month the actual
/// figure is used; later the month-end projection.
double budgetAdherence(MonthStats s) {
  final b = s.budgetMinor;
  if (b == null || b <= 0) return 1;
  final basis = s.daysElapsed < 7 ? s.spending : s.projectedSpending;
  final ratio = basis / b;
  return ratio <= 1 ? 1 : _clamp01(1 - (ratio - 1) / 0.25);
}

MoneyGrade computeGrade(MonthStats s) {
  // Saving power: 30% of income saved earns full marks.
  final saving = s.income <= 0 ? 0.0 : _clamp01(s.saveRate / 0.30);
  // Spending discipline: against the 3-month average (neutral without history).
  double discipline;
  if (s.prevAvgSpending <= 0) {
    discipline = 0.6;
  } else {
    final ratio = s.projectedSpending / s.prevAvgSpending;
    discipline = _clamp01((1.5 - ratio) / 0.6); // <=0.9 full, >=1.5 zero
  }
  // Debt freedom: overdue items and a heavy liability load cost points.
  var debt = 1.0 - math.min(0.5, s.overdueCount * 0.25);
  if (s.income > 0 && s.liabilities > 0) {
    debt -= 0.5 * _clamp01(s.liabilities / (s.income * 6.0));
  }
  debt = _clamp01(debt);
  // Wealth growth: 15% of income invested earns full marks.
  final wealth = s.income <= 0 ? 0.0 : _clamp01(s.investRate / 0.15);
  // Money awareness: logging on 20 days earns full marks.
  final aware = _clamp01(s.activeDays / 20.0);

  final hasBudget = s.budgetMinor != null && s.budgetMinor! > 0;
  // weights: with a budget they add to 100; without, the rest are scaled up
  const wSave = 25.0,
      wBudget = 20.0,
      wDisc = 15.0,
      wDebt = 15.0,
      wWealth = 15.0,
      wAware = 10.0;
  final total =
      wSave + wDisc + wDebt + wWealth + wAware + (hasBudget ? wBudget : 0);
  final k = 100 / total;
  GradePart part(String label, double frac, double w, String hint) =>
      GradePart(label, frac * w * k, w * k, hint);
  final parts = [
    part('Saving power', saving, wSave, 'Save more of what you earn'),
    if (hasBudget)
      part(
        'Budget discipline',
        budgetAdherence(s),
        wBudget,
        'Stay inside your monthly budget',
      ),
    part(
      'Spending discipline',
      discipline,
      wDisc,
      'Spend less than your usual',
    ),
    part('Debt freedom', debt, wDebt, 'Clear overdue payments and debts'),
    part('Wealth growth', wealth, wWealth, 'Invest a little every month'),
    part('Money awareness', aware, wAware, 'Log your spending on more days'),
  ];
  final sum = parts.fold<double>(0, (a, p) => a + p.score);
  return MoneyGrade(sum.round().clamp(0, 100), parts, s.thin);
}

// ───────────────────────── words ─────────────────────────
String _m(int minor) => Money.format(minor.abs());

/// One concrete next step toward a better title.
String nextStep(MonthStats s, {bool roast = true}) {
  if (s.healthDriven) roast = false;
  if (s.income <= 0) {
    return roast
        ? 'Log your income. Right now the app thinks you live on air.'
        : 'Log your income so the app can score your month properly.';
  }
  final need20 = (s.income * 0.2).round() - s.saved;
  if (need20 > 0) {
    final top = s.topCategory;
    return roast
        ? 'Cut ${_m(need20)}${top != null ? ' from $top' : ''} and you become a Steady Saver. Try it, coward.'
        : 'Save ${_m(need20)} more to become a Steady Saver.';
  }
  final need15 = (s.income * 0.15).round() - s.invested;
  if (need15 > 0) {
    return roast
        ? 'Invest ${_m(need15)} more to be a Wealth Builder. Your money is bored.'
        : 'Invest ${_m(need15)} more to become a Wealth Builder.';
  }
  return roast
      ? 'Keep this up and I will have nothing to roast. Disappointing.'
      : 'Keep it up. You are on a strong run.';
}

/// Lines for [t]; the caller picks one by a stable seed so the same month
/// always shows the same line. Numbers are filled in from [s].
List<String> titleLines(TitleId t, MonthStats s, {required bool roast}) {
  // A medical month is never a joke, whatever the setting.
  if (s.healthDriven) roast = false;
  final over = _m(s.spending - s.income);
  final spent = _m(s.spending);
  final saved = _m(s.saved);
  final cat = s.topCategory ?? 'stuff';
  final catAmt = _m((s.spending * s.topShareBps / 10000).round());
  if (!roast) {
    return switch (t) {
      TitleId.freshVictim => [
        'Not enough entries yet. Keep logging and your first title will arrive.',
      ],
      TitleId.incomeGhost => [
        'Spending is recorded but no income. Add your income for a fuller picture.',
      ],
      TitleId.overdraftArtist => [
        'You spent $over more than you earned this month. A small cut next month will fix it.',
      ],
      TitleId.lateLegend => [
        'Some instalments or debts are overdue. Clearing them is the quickest win.',
      ],
      TitleId.moneyMaster => [
        'You saved $saved and invested. Outstanding month.',
      ],
      TitleId.wealthBuilder => [
        'You invested ${_m(s.invested)} this month. Great habit.',
      ],
      TitleId.debtCrusher => [
        'You repaid ${_m(s.paidToLiabilities)} of what you owed. Well done.',
      ],
      TitleId.steadySaver => ['You saved $saved. Steady and strong.'],
      TitleId.budgetNinja => [
        'You spent well below your usual. Nicely controlled.',
      ],
      TitleId.comebackKid => [
        'You bounced back after an overspent month. Good recovery.',
      ],
      TitleId.consistencyHero => [
        'You logged on ${s.activeDays} days. Fantastic consistency.',
      ],
      TitleId.salaryEvaporator => [
        'Almost all your income went out this month. Try setting a little aside first.',
      ],
      TitleId.foodieBankrupt => [
        '$cat was your biggest spend at $catAmt. Worth a look.',
      ],
      TitleId.treatChampion => [
        '$cat was your biggest spend at $catAmt. Treats are fine in balance.',
      ],
      TitleId.balancedSpender => [
        'A steady month with nothing out of the ordinary.',
      ],
    };
  }
  return switch (t) {
    TitleId.freshVictim => [
      'Not enough data to roast you yet. Log more. We are sharpening the knives.',
      'Under 10 entries. Your finances are either perfect or you are hiding something.',
    ],
    TitleId.incomeGhost => [
      'You logged $spent of spending and zero income. Are you being funded by ghosts?',
      'Spending with no income recorded. Either you are a monk or you are lazy about the app.',
    ],
    TitleId.overdraftArtist => [
      'You spent $over MORE than you earned. That is not budgeting, that is a hostage situation with your bank.',
      'Spent $spent against an income of ${_m(s.income)}. Maths was never your subject, was it?',
      'You are spending money you have not even earned yet. Bold. Stupid, but bold.',
    ],
    TitleId.lateLegend => [
      'You have ${s.overdueCount} overdue payment${s.overdueCount == 1 ? '' : 's'}. The reminders are begging at this point.',
      'Late again. Deadlines are suggestions to you, aren\'t they?',
    ],
    TitleId.moneyMaster => [
      'You saved $saved AND invested. Who are you and what did you do with the real you?',
      'Saving ${(s.saveRate * 100).round()}% of income. Show-off. We hate it here.',
    ],
    TitleId.wealthBuilder => [
      'You invested ${_m(s.invested)}. Your money works harder than you do.',
      'Investing ${(s.investRate * 100).round()}% of income. Future you says thanks. Present you is eating plain rice.',
    ],
    TitleId.debtCrusher => [
      'You repaid ${_m(s.paidToLiabilities)}. Finally. Your creditors almost fainted.',
      'Paying debts on time? Who raised you?',
    ],
    TitleId.steadySaver => [
      'You saved $saved. Boring. Responsible. Disgustingly adult.',
      'Saved ${(s.saveRate * 100).round()}% of income. Not bad for someone who clearly can\'t say no to biryani.',
    ],
    TitleId.budgetNinja => [
      'Your wallet stayed shut this month. Is it broken or are you just scared?',
      'You spent far less than usual. Suspicious. Did the delivery app go down?',
    ],
    TitleId.comebackKid => [
      'Last month was a disaster. This month is a slightly smaller disaster.',
      'You clawed back from overspending. Slow clap. Do not do it again.',
    ],
    TitleId.consistencyHero => [
      'You tracked money on ${s.activeDays} days. You open this app more than you text your family.',
      'Logging nearly every day. Obsessive. We love it.',
    ],
    TitleId.salaryEvaporator => [
      'Your salary lasted about as long as your phone battery at 2%.',
      'You spent ${(s.income > 0 ? s.spending / s.income * 100 : 0).round()}% of your income. Payday is basically a donation to shops.',
      'Salary came in. Salary left. Nobody even got to say goodbye.',
    ],
    TitleId.foodieBankrupt => [
      '$cat ate $catAmt of your money. Your biggest relationship is with the delivery app.',
      'The delivery guy knows your name, your address and your weaknesses. $catAmt on $cat. Seek help.',
    ],
    TitleId.treatChampion => [
      '$cat cost you $catAmt. Retail therapy is billing you monthly.',
      '"I deserve it" has cost you $catAmt this month. You deserve a budget.',
    ],
    TitleId.balancedSpender => [
      'Not rich, not broke, just vibing on the edge of mediocrity.',
      'Nothing stood out. Not good, not terrible. The beige of finance.',
    ],
  };
}

/// A caring note shown next to the title whenever there was health spending.
/// Always kind, in every tone setting. General encouragement, not medical advice.
String? healthNote(MonthStats s, {String seed = ''}) {
  if (s.healthSpending <= 0) return null;
  final amt = _m(s.healthSpending);
  final pick = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  final light = [
    'You spent $amt on your health this month. Good. Keep looking after yourself: drink water, sleep well and take a 20-minute walk.',
    '$amt went on health care. Money well spent. Eat on time, rest enough and do not ignore small aches.',
    'Health spending of $amt this month. Your body carries you everywhere, so give it a little care every day.',
  ];
  final heavy = [
    'Health took $amt across ${s.healthCount} payments this month. Please look after yourself first: rest, follow your doctor\'s advice and do not skip follow-ups. Everything else can wait.',
    '${s.healthCount} health payments totalling $amt. Take it easy on yourself. Finish the course, keep your appointments and ask for help when you need it. You matter more than any budget.',
  ];
  final list = s.healthHeavy ? heavy : light;
  return list[pick % list.length];
}

// ───────────────────────── month-over-month ─────────────────────────
/// One line of the "this month vs last month" card.
class CompareRow {
  final String label, current, previous;

  /// true = this month is better, false = worse, null = about the same.
  final bool? better;

  /// Which way the number actually moved: 1 up, -1 down, 0 about the same.
  final int trend;
  const CompareRow(
    this.label,
    this.current,
    this.previous,
    this.better, [
    this.trend = 0,
  ]);
}

int _signCompare(num a, num b, {num tolerance = 0}) =>
    (a - b).abs() <= tolerance ? 0 : (a > b ? 1 : -1);

/// Compares a finished month with the one before it. Higher is better for
/// saving, investing and the score; lower is better for spending.
List<CompareRow> compareMonths(
  MonthStats cur,
  MonthStats prev, {
  required int curScore,
  required int prevScore,
}) {
  String pct(double v) => '${(v * 100).round()}%';
  // [t] is how the number moved; [lowerIsBetter] decides whether that is good.
  CompareRow row(
    String label,
    String c,
    String p,
    int t, {
    bool lowerIsBetter = false,
  }) => CompareRow(
    label,
    c,
    p,
    t == 0 ? null : (lowerIsBetter ? t < 0 : t > 0),
    t,
  );
  final rows = <CompareRow>[];
  if (cur.income > 0 || prev.income > 0) {
    rows.add(
      row(
        'Saved',
        cur.income > 0 ? pct(cur.saveRate) : '—',
        prev.income > 0 ? pct(prev.saveRate) : '—',
        _signCompare(cur.saveRate, prev.saveRate, tolerance: 0.01),
      ),
    );
  }
  rows.add(
    row(
      'Spent',
      Money.format(cur.spending),
      Money.format(prev.spending),
      _signCompare(
        cur.spending,
        prev.spending,
        tolerance: prev.spending * 0.02,
      ),
      lowerIsBetter: true,
    ),
  );
  if (cur.invested > 0 || prev.invested > 0) {
    rows.add(
      row(
        'Invested',
        Money.format(cur.invested),
        Money.format(prev.invested),
        _signCompare(cur.invested, prev.invested),
      ),
    );
  }
  rows.add(
    row(
      'Plus Score',
      '$curScore',
      '$prevScore',
      _signCompare(curScore, prevScore, tolerance: 1),
    ),
  );
  final cb = cur.budgetMinor, pb = prev.budgetMinor;
  if (cb != null && pb != null) {
    String word(MonthStats m, int b) =>
        m.spending < b ? 'Under' : (m.spending == b ? 'Exactly on' : 'Over');
    int rank(MonthStats m, int b) =>
        m.spending < b ? 2 : (m.spending == b ? 1 : 0);
    rows.add(
      row(
        'Budget',
        word(cur, cb),
        word(prev, pb),
        _signCompare(rank(cur, cb), rank(prev, pb)),
      ),
    );
  }
  return rows;
}

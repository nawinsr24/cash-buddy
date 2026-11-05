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
  });

  bool get complete => daysElapsed >= daysInMonth;
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

// ───────────────────────── Money Grade ─────────────────────────
class GradePart {
  final String label;
  final double score, max;
  const GradePart(this.label, this.score, this.max);
  double get fraction => max == 0 ? 0 : score / max;
}

class MoneyGrade {
  final int score; // 0..100
  final List<GradePart> parts;
  final bool building; // not enough data to be fair yet
  const MoneyGrade(this.score, this.parts, this.building);

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
}

double _clamp01(double v) => v.isNaN ? 0 : math.max(0.0, math.min(1.0, v));

MoneyGrade computeGrade(MonthStats s) {
  // Savings rate: 30% saved earns full marks.
  final savings = s.income <= 0 ? 0.0 : _clamp01(s.saveRate / 0.30) * 30;
  // Spending control: against the 3-month average (neutral without history).
  double control;
  if (s.prevAvgSpending <= 0) {
    control = 12;
  } else {
    final ratio = s.projectedSpending / s.prevAvgSpending;
    control = 20 * _clamp01((1.5 - ratio) / 0.6); // <=0.9 full, >=1.5 zero
  }
  // Debt health: overdue items and a heavy liability load cost points.
  var debt = 20.0 - math.min(10, s.overdueCount * 5.0);
  if (s.income > 0 && s.liabilities > 0) {
    debt -= 10 * _clamp01(s.liabilities / (s.income * 6.0));
  }
  debt = math.max(0, debt);
  // Investing: 15% of income earns full marks.
  final investing = s.income <= 0 ? 0.0 : _clamp01(s.investRate / 0.15) * 20;
  // Tracking: logging on 20 days earns full marks.
  final tracking = _clamp01(s.activeDays / 20.0) * 10;
  final parts = [
    GradePart('Savings', savings, 30),
    GradePart('Spending control', control, 20),
    GradePart('Debt health', debt, 20),
    GradePart('Investing', investing, 20),
    GradePart('Tracking', tracking, 10),
  ];
  final total = parts.fold<double>(0, (a, p) => a + p.score);
  return MoneyGrade(total.round().clamp(0, 100), parts, s.thin);
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

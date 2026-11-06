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

  /// What the open loans cost in interest per month, and the highest yearly
  /// rate (percent) among them. 0 when nothing is owed with interest.
  final int debtMonthlyInterest;
  final double maxDebtApr;

  /// Month length and how many of its days have passed (equal when complete).
  final int daysInMonth, daysElapsed;

  /// Spending on health care (medicine, doctors, hospitals, labs) and how many
  /// payments that was.
  final int healthSpending, healthCount;

  /// Spending in the everyday-life categories (each includes its subcategories).
  final int smokeSpending,
      liquorSpending,
      friendsSpending,
      hobbySpending,
      tripSpending;

  /// Money sent home to family.
  final int homeSent;

  /// The month's budget, when one is set.
  final int? budgetMinor;

  /// Spending per main category and per sub-category (name → minor units).
  final Map<String, int> mains, subs;

  /// The single biggest expense and what it was for.
  final int biggestAmt;
  final String? biggestLabel;

  /// Total spending of the previous full month (0 when unknown).
  final int prevSpending;

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
    this.debtMonthlyInterest = 0,
    this.maxDebtApr = 0,
    this.daysInMonth = 30,
    this.daysElapsed = 30,
    this.healthSpending = 0,
    this.healthCount = 0,
    this.smokeSpending = 0,
    this.liquorSpending = 0,
    this.friendsSpending = 0,
    this.hobbySpending = 0,
    this.tripSpending = 0,
    this.homeSent = 0,
    this.budgetMinor,
    this.mains = const {},
    this.subs = const {},
    this.biggestAmt = 0,
    this.biggestLabel,
    this.prevSpending = 0,
  });

  /// Spending in the main category or sub-category called [name].
  int cat(String name) => (mains[name] ?? 0) + (subs[name] ?? 0);

  /// Sum of several categories (mains and subs by name).
  int catSum(List<String> names) => names.fold(0, (a, n) => a + cat(n));

  /// Share of spending, in percent, taken by [names].
  int pctOf(List<String> names) =>
      spending <= 0 ? 0 : (catSum(names) * 100 / spending).round();

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
          smokeSpending: smokeSpending,
          liquorSpending: liquorSpending,
          friendsSpending: friendsSpending,
          hobbySpending: hobbySpending,
          tripSpending: tripSpending,
          homeSent: homeSent,
          budgetMinor: budgetMinor,
          debtMonthlyInterest: debtMonthlyInterest,
          maxDebtApr: maxDebtApr,
          mains: mains,
          subs: subs,
          biggestAmt: biggestAmt,
          biggestLabel: biggestLabel,
          prevSpending: prevSpending,
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

  /// Cigarettes and liquor together.
  int get viceSpending => smokeSpending + liquorSpending;

  /// A big part of the month (30%+) went to family: never roast that either.
  bool get homeDriven =>
      homeSent > 0 && spending > 0 && homeSent * 10 >= spending * 3;

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
  smokeSignal,
  foodieBankrupt,
  socialButterfly,
  wanderlust,
  gearAddict,
  treatChampion,
  homeHero,
  orderInKing,
  giftCupid,
  gadgetFan,
  glowUp,
  bingeMode,
  roadWarrior,
  partyMode,
  feeDonor,
  petParent,
  kidsFirst,
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
    TitleId.smokeSignal => '💨',
    TitleId.foodieBankrupt => '🍔',
    TitleId.socialButterfly => '👯',
    TitleId.wanderlust => '🧳',
    TitleId.gearAddict => '🚴',
    TitleId.treatChampion => '🛍️',
    TitleId.homeHero => '🏡',
    TitleId.orderInKing => '🛵',
    TitleId.giftCupid => '💘',
    TitleId.gadgetFan => '📱',
    TitleId.glowUp => '💅',
    TitleId.bingeMode => '🍿',
    TitleId.roadWarrior => '⛽',
    TitleId.partyMode => '🎉',
    TitleId.feeDonor => '🪙',
    TitleId.petParent => '🐾',
    TitleId.kidsFirst => '🧸',
    TitleId.balancedSpender => '🧭',
  };

  /// Short, plain names anyone can understand.
  String get title => switch (this) {
    TitleId.freshVictim => 'New Here',
    TitleId.incomeGhost => 'No Income Added',
    TitleId.overdraftArtist => 'Overspender',
    TitleId.lateLegend => 'Late Payer',
    TitleId.moneyMaster => 'Money Master',
    TitleId.wealthBuilder => 'Investor',
    TitleId.debtCrusher => 'Debt Clearer',
    TitleId.steadySaver => 'Steady Saver',
    TitleId.budgetNinja => 'Budget Boss',
    TitleId.comebackKid => 'Back on Track',
    TitleId.consistencyHero => 'Daily Tracker',
    TitleId.salaryEvaporator => 'Salary Gone Fast',
    TitleId.smokeSignal => 'Smoke & Drink',
    TitleId.foodieBankrupt => 'Food Lover',
    TitleId.socialButterfly => 'Friends First',
    TitleId.wanderlust => 'Trip Lover',
    TitleId.gearAddict => 'Hobby Lover',
    TitleId.treatChampion => 'Shopping Lover',
    TitleId.homeHero => 'Family First',
    TitleId.orderInKing => 'Order-In King',
    TitleId.giftCupid => 'Gift Cupid',
    TitleId.gadgetFan => 'Gadget Fan',
    TitleId.glowUp => 'Glow-Up Mode',
    TitleId.bingeMode => 'Binge Mode',
    TitleId.roadWarrior => 'Road Warrior',
    TitleId.partyMode => 'Party Mode',
    TitleId.feeDonor => 'Fee Donor',
    TitleId.petParent => 'Pet Parent',
    TitleId.kidsFirst => 'Kids First',
    TitleId.balancedSpender => 'Balanced',
  };

  /// Why you got it, in plain words (shown on the reveal card).
  String get rule => switch (this) {
    TitleId.freshVictim => 'You have fewer than 10 entries this month.',
    TitleId.incomeGhost => 'You added spending but no income.',
    TitleId.overdraftArtist => 'You spent more than you earned.',
    TitleId.lateLegend => 'You have overdue payments or debts.',
    TitleId.moneyMaster =>
      'You saved 40% or more of your income and also invested.',
    TitleId.wealthBuilder => 'You invested 15% or more of your income.',
    TitleId.debtCrusher => 'You paid back 15% or more of what you owed.',
    TitleId.steadySaver => 'You saved 20% or more of your income.',
    TitleId.budgetNinja => 'You spent 10% or more less than your usual.',
    TitleId.comebackKid => 'You overspent last month, but not this month.',
    TitleId.consistencyHero => 'You noted your spending on 25 or more days.',
    TitleId.salaryEvaporator => 'You spent 95% or more of your income.',
    TitleId.smokeSignal =>
      'Cigarettes and liquor took 12% or more of your spending.',
    TitleId.foodieBankrupt => 'Food was your biggest spend, 30% or more.',
    TitleId.socialButterfly => 'Friends took 20% or more of your spending.',
    TitleId.wanderlust => 'Tours and trips took 30% or more of your spending.',
    TitleId.gearAddict => 'Hobbies took 15% or more of your spending.',
    TitleId.treatChampion =>
      'Shopping or entertainment was your biggest spend.',
    TitleId.homeHero => 'You sent 10% or more of your income home.',
    TitleId.orderInKing =>
      'Restaurants, delivery and snacks took 25% or more of your spending.',
    TitleId.giftCupid =>
      'Gifts and dates for your partner took 8% or more of your spending.',
    TitleId.gadgetFan =>
      'Gadgets and phones took 12% or more of your spending.',
    TitleId.glowUp =>
      'Salon, skin care and grooming took 10% or more of your spending.',
    TitleId.bingeMode =>
      'Movies, shows and fun took 15% or more of your spending.',
    TitleId.roadWarrior =>
      'Fuel, rides and vehicle costs took 25% or more of your spending.',
    TitleId.partyMode =>
      'Gifts, functions and celebrations took 15% or more of your spending.',
    TitleId.feeDonor =>
      'Late fees, bank charges and fines took 3% or more of your spending.',
    TitleId.petParent => 'Your pets took 8% or more of your spending.',
    TitleId.kidsFirst => 'Your kids took 20% or more of your spending.',
    TitleId.balancedSpender => 'Nothing was too high or too low.',
  };

  bool get positive => switch (this) {
    TitleId.moneyMaster ||
    TitleId.wealthBuilder ||
    TitleId.debtCrusher ||
    TitleId.steadySaver ||
    TitleId.budgetNinja ||
    TitleId.comebackKid ||
    TitleId.homeHero ||
    TitleId.petParent ||
    TitleId.kidsFirst ||
    TitleId.consistencyHero => true,
    _ => false,
  };
}

const _kids = ['Kids'];
const _pets = ['Pets'];
const _fees = ['Late Fees', 'Bank Charges', 'Fines'];
const _eatOut = [
  'Hotel & Restaurant',
  'Food Delivery',
  'Snacks',
  'Sweets & Bakery',
  'Canteen Meals',
];
const _lover = ['Gift to Lover', 'Partner'];
const _gadgets = ['Electronics & Gadgets', 'Mobile & Accessories'];
const _glow = ['Personal Care'];
const _screen = ['Entertainment'];
const _road = ['Transport'];
const _party = [
  'Birthday & Anniversary',
  'Wedding & Function',
  'Festival Expenses',
  'Gift to Friends',
];

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
  if (s.income > 0 && s.homeSent * 10 >= s.income) return TitleId.homeHero;
  if (s.prevAvgSpending > 0 && s.spending <= s.prevAvgSpending * 0.9) {
    return TitleId.budgetNinja;
  }
  if (s.prevMonthOverspent) return TitleId.comebackKid;
  if (s.activeDays >= 25) return TitleId.consistencyHero;
  if (s.income > 0 && s.spending >= s.income * 0.95) {
    return TitleId.salaryEvaporator;
  }
  final sp = s.spending;
  if (sp > 0 && s.viceSpending * 100 >= sp * 12) return TitleId.smokeSignal;
  if (_isFood(s.topCategory) && s.topShareBps >= 3000) {
    return TitleId.foodieBankrupt;
  }
  if (sp > 0 && s.friendsSpending * 100 >= sp * 20) {
    return TitleId.socialButterfly;
  }
  if (sp > 0 && s.tripSpending * 100 >= sp * 30) return TitleId.wanderlust;
  if (sp > 0 && s.hobbySpending * 100 >= sp * 15) return TitleId.gearAddict;
  if (sp > 0) {
    if (s.pctOf(_kids) >= 20) return TitleId.kidsFirst;
    if (s.pctOf(_pets) >= 8) return TitleId.petParent;
    if (s.pctOf(_fees) >= 3) return TitleId.feeDonor;
    if (s.pctOf(_eatOut) >= 25) return TitleId.orderInKing;
    if (s.pctOf(_lover) >= 8) return TitleId.giftCupid;
    if (s.pctOf(_gadgets) >= 12) return TitleId.gadgetFan;
    if (s.pctOf(_glow) >= 10) return TitleId.glowUp;
    if (s.pctOf(_screen) >= 15) return TitleId.bingeMode;
    if (s.pctOf(_road) >= 25) return TitleId.roadWarrior;
    if (s.pctOf(_party) >= 15) return TitleId.partyMode;
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

// ───────────────────────── Money Health ─────────────────────────
/// One of the parts the Money Health is made of.
class GradePart {
  final String label, hint;
  final double score, max;
  const GradePart(this.label, this.score, this.max, [this.hint = '']);
  double get fraction => max == 0 ? 0 : score / max;
}

/// The Money Health: 0..100 for a month, with a named level.
/// (The class keeps its old name; the app calls it "Money Health".)
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
  if (score >= 90) return 'Excellent';
  if (score >= 80) return 'Very good';
  if (score >= 70) return 'Good';
  if (score >= 60) return 'Okay';
  if (score >= 50) return 'Average';
  if (score >= 40) return 'Weak';
  return 'Needs care';
}

/// The best score allowed while the debt picture is poor (null = no cap).
/// High-interest borrowing (24%+ a year) or anything overdue holds the score
/// at "Okay" (69) or lower; interest above a fifth of income holds it lower.
int? debtCap(MonthStats s) {
  final heavyInterest =
      s.debtMonthlyInterest > 0 &&
      (s.income <= 0 || s.debtMonthlyInterest / s.income >= 0.2);
  if (heavyInterest) return 49;
  if (s.maxDebtApr >= 36) return 59;
  if (s.maxDebtApr >= 24 || s.overdueCount > 0 && s.liabilities > 0) return 69;
  return null;
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
  // Debt freedom: overdue items, a heavy debt load, the interest it costs and
  // a high rate all cost points. Borrowing at 24% a year or more can never
  // look "good" (see the cap below).
  var debt = 1.0 - math.min(0.4, s.overdueCount * 0.2);
  if (s.income > 0 && s.liabilities > 0) {
    debt -= 0.3 * _clamp01(s.liabilities / (s.income * 6.0));
  }
  if (s.income > 0 && s.debtMonthlyInterest > 0) {
    // interest eating 10% of income or more is the worst case
    debt -= 0.4 * _clamp01(s.debtMonthlyInterest / (s.income * 0.10));
  } else if (s.debtMonthlyInterest > 0) {
    debt -= 0.4;
  }
  if (s.maxDebtApr >= 36) {
    debt -= 0.3;
  } else if (s.maxDebtApr >= 18) {
    debt -= 0.15 + 0.15 * _clamp01((s.maxDebtApr - 18) / 18);
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
      wDebt = 20.0,
      wWealth = 15.0,
      wAware = 5.0;
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
  var score = sum.round().clamp(0, 100);
  // Strong saving can never hide a debt problem.
  final cap = debtCap(s);
  if (cap != null && score > cap) score = cap;
  return MoneyGrade(score, parts, s.thin);
}

// ───────────────────────── words ─────────────────────────
String _m(int minor) => Money.format(minor.abs());

/// One concrete next step toward a better title.
String nextStep(MonthStats s, {bool roast = true}) {
  if (s.healthDriven || s.homeDriven) roast = false;
  if (s.income <= 0) {
    return roast
        ? 'Add your income. Without it we cannot check your month.'
        : 'Add your income so we can check your month properly.';
  }
  final need20 = (s.income * 0.2).round() - s.saved;
  if (need20 > 0) {
    final top = s.topCategory;
    return roast
        ? 'Spend ${_m(need20)} less${top != null ? ', maybe on $top' : ''}, and you will be a Steady Saver.'
        : 'Save ${_m(need20)} more to become a Steady Saver.';
  }
  final need15 = (s.income * 0.15).round() - s.invested;
  if (need15 > 0) {
    return roast
        ? 'Invest ${_m(need15)} more to become an Investor. Money sitting idle earns nothing.'
        : 'Invest ${_m(need15)} more to become an Investor.';
  }
  return roast
      ? 'You are doing really well. Keep it up!'
      : 'You are doing very well. Keep it up.';
}

/// Lines for [t]; the caller picks one by a stable seed so the same month
/// always shows the same line. Numbers are filled in from [s].
/// Everything is in short, plain English.
List<String> titleLines(TitleId t, MonthStats s, {required bool roast}) {
  // A medical month, or money sent to family, is never a joke.
  if (s.healthDriven || s.homeDriven) roast = false;
  if (t == TitleId.petParent || t == TitleId.kidsFirst) roast = false;
  final vice = _m(s.viceSpending);
  final eatOut = _m(s.catSum(_eatOut));
  final lover = _m(s.catSum(_lover));
  final gadgets = _m(s.catSum(_gadgets));
  final glow = _m(s.catSum(_glow));
  final screen = _m(s.catSum(_screen));
  final road = _m(s.catSum(_road));
  final party = _m(s.catSum(_party));
  final fees = _m(s.catSum(_fees));
  final pets = _m(s.catSum(_pets));
  final kids = _m(s.catSum(_kids));
  final friends = _m(s.friendsSpending);
  final trip = _m(s.tripSpending);
  final hobby = _m(s.hobbySpending);
  final home = _m(s.homeSent);
  final over = _m(s.spending - s.income);
  final spent = _m(s.spending);
  final income = _m(s.income);
  final saved = _m(s.saved);
  final cat = s.topCategory ?? 'shopping';
  final catAmt = _m((s.spending * s.topShareBps / 10000).round());
  final spentPct = s.income > 0 ? (s.spending / s.income * 100).round() : 0;
  final savedPct = (s.saveRate * 100).round();
  final investPct = (s.investRate * 100).round();
  if (!roast) {
    return switch (t) {
      TitleId.freshVictim => [
        'Not enough entries yet. Add more and you will get your first title.',
      ],
      TitleId.incomeGhost => [
        'You added spending but no income. Please add your income too.',
      ],
      TitleId.overdraftArtist => [
        'You spent $over more than you earned this month. Try to spend a little less next month.',
      ],
      TitleId.lateLegend => [
        'Some of your payments are overdue. Paying them first is the quickest win.',
      ],
      TitleId.moneyMaster => [
        'You saved $saved and also invested. Excellent month!',
      ],
      TitleId.wealthBuilder => [
        'You invested ${_m(s.invested)} this month. A very good habit.',
      ],
      TitleId.debtCrusher => [
        'You paid back ${_m(s.paidToLiabilities)} of what you owed. Well done.',
      ],
      TitleId.steadySaver => [
        'You saved $saved this month. Steady and strong.',
      ],
      TitleId.budgetNinja => [
        'You spent less than your usual. Nicely controlled.',
      ],
      TitleId.comebackKid => [
        'You overspent last month, but this month you did better. Good recovery.',
      ],
      TitleId.consistencyHero => [
        'You noted your spending on ${s.activeDays} days. Great habit.',
      ],
      TitleId.salaryEvaporator => [
        'Almost all of your income was spent this month. Try keeping a little aside first.',
      ],
      TitleId.smokeSignal => [
        'Cigarettes and liquor cost $vice this month. Cutting down helps your health and your wallet.',
      ],
      TitleId.foodieBankrupt => [
        'Food was your biggest spend: $catAmt. Worth a look.',
      ],
      TitleId.socialButterfly => [
        'You spent $friends on friends this month. Nice, just keep an eye on the total.',
      ],
      TitleId.wanderlust => ['Trips cost $trip this month. Good memories!'],
      TitleId.gearAddict => [
        'You spent $hobby on hobbies this month. Staying active is worth it.',
      ],
      TitleId.treatChampion => [
        '$cat was your biggest spend: $catAmt. A little treat now and then is fine.',
      ],
      TitleId.homeHero => [
        'You sent $home home. Looking after family is the best spending.',
      ],
      TitleId.orderInKing => [
        'Eating out and snacks cost $eatOut this month. Cooking a few meals at home would help.',
      ],
      TitleId.giftCupid => [
        '$lover on gifts and dates. Lovely, just keep an eye on the total.',
      ],
      TitleId.gadgetFan => [
        '$gadgets on gadgets and phones this month. Worth checking if you needed them all.',
      ],
      TitleId.glowUp => [
        '$glow on personal care. Looking after yourself is fine, in a balance.',
      ],
      TitleId.bingeMode => [
        '$screen on entertainment this month. Fun is good, just keep it in check.',
      ],
      TitleId.roadWarrior => [
        '$road on travel and vehicle costs. Sharing rides or planning trips can bring it down.',
      ],
      TitleId.partyMode => [
        '$party on gifts and celebrations. Nice memories, but plan the next ones.',
      ],
      TitleId.feeDonor => [
        '$fees went on fees and fines. Most of it can be avoided with reminders.',
      ],
      TitleId.petParent => [
        '$pets on your pets this month. They are lucky to have you.',
      ],
      TitleId.kidsFirst => [
        '$kids on your kids this month. That is money well spent.',
      ],
      TitleId.balancedSpender => [
        'A normal month. Nothing too high or too low.',
      ],
    };
  }
  return switch (t) {
    TitleId.freshVictim => [
      'Not enough entries yet. Add more and we will give you a title.',
      'Fewer than 10 entries so far. Keep adding your spending.',
    ],
    TitleId.incomeGhost => [
      'You added $spent of spending but no income. Where is the salary?',
      'Spending is there, income is missing. Please add your income.',
    ],
    TitleId.overdraftArtist => [
      'You spent $over more than you earned. That is a dangerous habit.',
      'You earned $income but spent $spent. Where will the extra money come from?',
      'Spending more than you earn is how debts start. Slow down!',
    ],
    TitleId.lateLegend => [
      'You have ${s.overdueCount} overdue payment${s.overdueCount == 1 ? '' : 's'}. Please pay them soon.',
      'Late again? Clear your dues first, then enjoy.',
    ],
    TitleId.moneyMaster => [
      'You saved $saved and also invested. Very good!',
      'You saved $savedPct% of your income. Excellent work!',
    ],
    TitleId.wealthBuilder => [
      'You invested ${_m(s.invested)} this month. Your money is working for you.',
      '$investPct% of your income went into investments. Good for your future.',
    ],
    TitleId.debtCrusher => [
      'You paid back ${_m(s.paidToLiabilities)}. Good, keep going!',
      'Paying loans on time is a great habit.',
    ],
    TitleId.steadySaver => [
      'You saved $saved. Small savings every month become big savings.',
      'You saved $savedPct% of your income. Nice and simple.',
    ],
    TitleId.budgetNinja => [
      'You spent less than your usual this month. Very controlled!',
      'Your spending came down well this month. Great job.',
    ],
    TitleId.comebackKid => [
      'Last month you overspent. This month you did better. Keep going!',
      'Good recovery after an expensive month. Do not slip back.',
    ],
    TitleId.consistencyHero => [
      'You noted your spending on ${s.activeDays} days. That is a great habit.',
      'You track almost every day. That is how money control starts.',
    ],
    TitleId.salaryEvaporator => [
      'Your salary was almost finished this month. You spent $spentPct% of it.',
      'Salary came and went very fast. Keep some money aside first.',
    ],
    TitleId.smokeSignal => [
      'You spent $vice on cigarettes and liquor. That money could do much better things.',
      '$vice on smoking and drinking this month. Think about your health and your wallet.',
      'Cigarettes and liquor cost $vice. Even a small cut will help your health and savings.',
    ],
    TitleId.foodieBankrupt => [
      'Food took $catAmt of your money. Cooking at home can save a lot.',
      'You spent $catAmt on food. Order less, cook more!',
    ],
    TitleId.socialButterfly => [
      'You spent $friends on friends. Being generous is nice, but do not forget yourself.',
      '$friends on friends this month. Who is saving for your future?',
    ],
    TitleId.wanderlust => [
      'Trips took $trip this month. Enjoy, but plan your savings too.',
      '$trip on tours and trips. Good memories, but check your balance.',
    ],
    TitleId.gearAddict => [
      'You spent $hobby on hobbies. Being active is good. Do you really need new gear?',
      'Hobbies took $hobby. Use what you already have first.',
    ],
    TitleId.treatChampion => [
      '$cat took $catAmt. Ask yourself: do I really need it?',
      'You spent $catAmt on $cat. A treat is fine, but not every week.',
    ],
    TitleId.homeHero => [
      'You sent $home home. That is a great heart!',
      'Family first: $home sent home. Well done.',
    ],
    TitleId.orderInKing => [
      '$eatOut on restaurants, delivery and snacks. Your kitchen is filing a missing-person report.',
      'Delivery guy knows your address better than your family does. $eatOut gone on eating out.',
      '$eatOut on food you did not cook. Even the stove is jealous of the delivery bag.',
    ],
    TitleId.giftCupid => [
      '$lover spent on love. Romance is great, but your bank balance is not in love with you.',
      'Cupid called. He wants his commission back. $lover on gifts and dates.',
      '$lover on the partner. Hope they at least say thank you in public.',
    ],
    TitleId.gadgetFan => [
      '$gadgets on gadgets. The old phone was fine, was it not?',
      'Another gadget, another dent. $gadgets this month. Does it make you richer? No.',
      '$gadgets on tech. Your wallet needs a software update too.',
    ],
    TitleId.glowUp => [
      '$glow on glow-up. Looking good, feeling broke. Choose one.',
      'Salon and skin care took $glow. Your savings could use a facial too.',
      '$glow on grooming. Shine bright, but not brighter than your savings.',
    ],
    TitleId.bingeMode => [
      '$screen on movies and fun. The popcorn cost more than the movie.',
      '$screen on entertainment. Your life is a show, and the budget is the villain.',
      'You paid $screen to be entertained, while your savings watched in silence.',
    ],
    TitleId.roadWarrior => [
      '$road on travel and vehicle. Your tank is full, your wallet is empty.',
      'Fuel, rides and service: $road. Is your vehicle a pet or a vehicle?',
      '$road went on the road. Try one bus ride, your bank will thank you.',
    ],
    TitleId.partyMode => [
      '$party on gifts and celebrations. Everyone had a party, except your savings.',
      'Birthdays, functions and festivals took $party. You are the sponsor of everyone\'s happiness.',
      '$party on celebrations. Generous heart, tired wallet.',
    ],
    TitleId.feeDonor => [
      '$fees on fees and fines. That is free money to the bank, with a thank-you note from you.',
      'You donated $fees to banks and late fees. They did not even send a thank-you.',
      '$fees wasted on charges. Set a reminder, it is cheaper than a fine.',
    ],
    TitleId.petParent => [
      '$pets on your pets this month. They are lucky to have you.',
    ],
    TitleId.kidsFirst => [
      '$kids on your kids this month. That is money well spent.',
    ],
    TitleId.balancedSpender => [
      'A normal month. Nothing too good or too bad.',
      'Nothing special this month. Try to save a little more next time.',
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
      'Money Health',
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

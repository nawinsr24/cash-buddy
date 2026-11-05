import 'money.dart';

enum BudgetState { under, exact, over }

/// Against the overall monthly budget: strictly below, exactly equal, or above.
BudgetState budgetState(int spent, int budget) => spent < budget
    ? BudgetState.under
    : (spent == budget ? BudgetState.exact : BudgetState.over);

extension BudgetStateInfo on BudgetState {
  String get emoji => switch (this) {
    BudgetState.under => '✅',
    BudgetState.exact => '🎯',
    BudgetState.over => '🚨',
  };
  String get label => switch (this) {
    BudgetState.under => 'Under budget',
    BudgetState.exact => 'Exactly on budget',
    BudgetState.over => 'Over budget',
  };
}

/// One line of the splitup: money set aside for a category, and what went out.
/// Splits are a guide. Only the overall budget decides under / exact / over.
class SplitRow {
  final String id, name;
  final int colorValue;
  final int allocated; // 0 for the "everything else" row
  final int spent;
  const SplitRow({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.allocated,
    required this.spent,
  });
  bool get isElse => id == '_else';
  BudgetState get state => budgetState(spent, allocated);
  int get left => allocated - spent;
}

class BudgetStatus {
  final int year, month;
  final int budget, spent;
  final bool monthOnly; // this month has its own amount
  final List<SplitRow> splits;
  final int daysInMonth, daysElapsed;
  const BudgetStatus({
    required this.year,
    required this.month,
    required this.budget,
    required this.spent,
    required this.monthOnly,
    required this.splits,
    required this.daysInMonth,
    required this.daysElapsed,
  });

  BudgetState get state => budgetState(spent, budget);
  int get remaining => budget - spent; // negative once over
  double get fraction => budget <= 0 ? 0 : spent / budget;
  int get daysLeft => (daysInMonth - daysElapsed).clamp(0, daysInMonth);
  bool get complete => daysElapsed >= daysInMonth;

  /// What can still be spent each remaining day (0 when nothing is left).
  int get safePerDay =>
      remaining <= 0 || daysLeft == 0 ? 0 : (remaining / daysLeft).floor();

  /// Month-end spending if the pace so far continues.
  int get projected => complete || daysElapsed <= 0
      ? spent
      : (spent * daysInMonth / daysElapsed).round();

  int get allocatedTotal => splits.fold(0, (a, s) => a + s.allocated);
  int get unallocated => budget - allocatedTotal;
  bool get overAllocated => allocatedTotal > budget;

  /// Splits over their own allocation while the overall budget still holds.
  /// That is fine by design: money moved between categories.
  List<SplitRow> get overSplits => [
    for (final s in splits)
      if (!s.isElse && s.allocated > 0 && s.state == BudgetState.over) s,
  ];
  bool get splitsOffButFine =>
      state != BudgetState.over && overSplits.isNotEmpty;
}

class BudgetMonth {
  final String month; // YYYY-MM
  final int budget, spent;
  const BudgetMonth(this.month, this.budget, this.spent);
  BudgetState get state => budgetState(spent, budget);
}

String budgetHeadline(BudgetStatus b, {required bool roast}) {
  String m(int v) => Money.format(v.abs());
  switch (b.state) {
    case BudgetState.under:
      return roast
          ? (b.complete
                ? 'Under budget by ${m(b.remaining)}. Suspiciously responsible.'
                : '${m(b.remaining)} left. Try not to ruin it.')
          : (b.complete
                ? 'You finished ${m(b.remaining)} under budget. Well done.'
                : '${m(b.remaining)} left this month. You are on track.');
    case BudgetState.exact:
      return roast
          ? 'Exactly on budget. Not a rupee spare. Are you a robot?'
          : 'Exactly on budget. Spot on.';
    case BudgetState.over:
      return roast
          ? 'Blew past the budget by ${m(b.remaining)}. Bold strategy.'
          : '${m(b.remaining)} over budget. A lighter month ahead will balance it.';
  }
}

/// One month in the year chart. [budget] is null for months before a budget
/// existed; [spent] is always shown.
class BudgetYearMonth {
  final int month, spent;
  final int? budget;
  final bool current, future;
  const BudgetYearMonth({
    required this.month,
    required this.spent,
    required this.budget,
    this.current = false,
    this.future = false,
  });
  BudgetState? get state =>
      budget == null || future ? null : budgetState(spent, budget!);
}

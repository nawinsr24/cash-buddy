import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/budget.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'budget.dart';
import 'group.dart';

/// This month's budget as a round card, shared by both while home sharing is
/// on. With no budget it shows only a plus.
class BudgetRings extends ConsumerWidget {
  const BudgetRings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(budgetStatusProvider);
    final home = ref.watch(homeMonthProvider).value;
    if (!mine.hasValue) return const SizedBox.shrink();
    final today = ref.watch(repoProvider).today;
    final days = Dates.daysInMonth(today.year, today.month) - today.day;
    // While sharing there is one budget for both; my earlier one is the
    // starting figure until it is changed.
    final budget = home == null
        ? mine.value?.budget
        : home.budget ?? mine.value?.budget;
    return _Ring(
      key: const ValueKey('my-budget'),
      title: tr('Budget'),
      spent: home == null ? mine.value?.spent ?? 0 : home.sharedTotal,
      budget: budget,
      daysLeft: days,
      onTap: home == null
          ? () => pushReveal(context, const BudgetPage())
          : () => _setHomeBudget(context, ref, budget),
    );
  }

  Future<void> _setHomeBudget(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final c = TextEditingController(
      text: current == null ? '' : Money.edit(current),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Budget')),
        content: AmountField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    final v = Money.parse(c.text);
    if (ok != true || v == null) return;
    await ref
        .read(groupServiceProvider)
        ?.change((g) => g.put('budget', {'kind': 'budget', 'limitMinor': v}));
  }
}

class _Ring extends StatelessWidget {
  final String title;
  final int spent;
  final int? budget;
  final int daysLeft;
  final VoidCallback onTap;
  const _Ring({
    super.key,
    required this.title,
    required this.spent,
    required this.budget,
    required this.daysLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final limit = budget;
    final set = limit != null && limit > 0;
    final state = set ? budgetState(spent, limit) : null;
    final color = state == null
        ? context.scheme.primary
        : budgetColor(context, state);
    final over = state == BudgetState.over;
    final muted = context.text.bodyMedium?.copyWith(
      color: context.cash.textMuted,
    );
    return Pressable(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          // laid out like the Money Health card below it
          child: Row(
            children: [
              SizedBox.square(
                dimension: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: set ? (spent / limit).clamp(0, 1).toDouble() : 0,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: context.scheme.primaryContainer,
                    ),
                    Center(
                      child: set
                          ? Padding(
                              padding: const EdgeInsets.all(Sp.x3),
                              child: FittedBox(
                                child: Text(
                                  '${(spent * 100 / limit).round()}%',
                                  style: context.text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.add,
                              size: 30,
                              color: context.scheme.primary,
                              semanticLabel: tr('Set a budget'),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // the badge drops below the title when there is no room
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Sp.x2,
                      runSpacing: Sp.x1,
                      children: [
                        Eyebrow(title),
                        if (state != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sp.x3,
                              vertical: Sp.x1,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              tr(state.label),
                              style: context.text.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (set) ...[
                      const SizedBox(height: Sp.x1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              Money.format((limit - spent).abs()),
                              style: context.text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: over ? color : null,
                              ),
                            ),
                            const SizedBox(width: Sp.x2),
                            Text(tr(over ? 'over' : 'left'), style: muted),
                          ],
                        ),
                      ),
                      Text(
                        '${tr('of')} ${Money.format(limit)}  ·  '
                        '$daysLeft ${tr('days left')}',
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Sp.x1),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

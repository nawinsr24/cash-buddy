import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import 'debts.dart';

/// "Card bills due: ... After paying, your budget would be ... left." Shown
/// under the budget on Home only when card spends are kept out of the budget
/// until the bill is paid and a bill is due this month.
class CardWarningLine extends ConsumerWidget {
  const CardWarningLine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(cardWarningProvider).value;
    if (w == null) return const SizedBox.shrink();
    final over = w.after < 0;
    final color = over ? context.cash.spending : context.cash.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.x2),
      child: Pressable(
        onTap: () => pushReveal(context, const DebtsPage()),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sp.rCard),
            border: Border.all(
              color: over ? color : context.scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.credit_card, size: 18, color: color),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Text(
                  over
                      ? 'Card bills due: ${Money.format(w.due)}. After paying, you would be ${Money.format(-w.after)} over budget.'
                      : 'Card bills due: ${Money.format(w.due)}. After paying, your budget would be ${Money.format(w.after)} left.',
                  style: context.text.bodySmall?.copyWith(
                    color: color,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/safe_repo.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// "Safe to spend today" at the top of Home. Without a budget it stays out of
/// the way: the budget card below already asks for one.
class SafeTodayCard extends ConsumerWidget {
  const SafeTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(safeToSpendProvider).value;
    if (s == null) return const SizedBox.shrink();
    final over = s.today <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Sp.rCard),
          onTap: () => showSheet(context, (_) => _Sum(s)),
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Safe to spend today'),
                        style: TextStyle(color: context.cash.textMuted),
                      ),
                      MoneyText(
                        over ? 0 : s.today,
                        color: over
                            ? context.cash.spending
                            : context.cash.income,
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (over)
                        Text(
                          tr('Nothing left for today.'),
                          style: context.text.bodySmall?.copyWith(
                            color: context.cash.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.info_outline, color: context.cash.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The calculation, line by line.
class _Sum extends StatelessWidget {
  final SafeToSpend s;
  const _Sum(this.s);

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: Sp.x3),
          Text(
            value,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('How this is worked out'),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sp.x3),
            line(tr('Budget left this morning'), Money.format(s.left)),
            for (final r in s.reserved)
              line(
                '${r.name} (${tr('still due')})',
                '− ${Money.format(r.amount)}',
              ),
            line(tr('Days left, with today'), '${s.daysLeft}'),
            const Divider(),
            line(tr('For each day'), Money.format(s.perDay), strong: true),
            line(tr('Already spent today'), '− ${Money.format(s.spentToday)}'),
            line(
              tr('Safe to spend today'),
              Money.format(s.today < 0 ? 0 : s.today),
              strong: true,
            ),
          ],
        ),
      ),
    );
  }
}

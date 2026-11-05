import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/budget_repo.dart';
import '../data/db.dart';
import '../data/repo.dart' show ValidationException;
import '../domain/budget.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Color budgetColor(BuildContext c, BudgetState s) => switch (s) {
  BudgetState.under => c.cash.income,
  BudgetState.exact => const Color(0xFFF59E0B),
  BudgetState.over => c.cash.spending,
};

List<Color> _heroColors(BudgetState s) => switch (s) {
  BudgetState.under => const [Color(0xFF22B573), Color(0xFF2F6BFF)],
  BudgetState.exact => const [Color(0xFFF59E0B), Color(0xFFFF8A3D)],
  BudgetState.over => const [Color(0xFFEF4444), Color(0xFFEC4899)],
};

// ───────────────────────── card on Home ─────────────────────────
class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetStatusProvider);
    final roast = ref.watch(roastModeProvider).value ?? true;
    if (!async.hasValue) return const SizedBox.shrink();
    final b = async.value;
    void go() => Navigator.of(context).push(softRoute(const BudgetPage()));
    if (b == null) {
      return Pressable(
        onTap: go,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 30)),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set your monthly budget',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Know if you finish under, on or over it.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.cash.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }
    final color = budgetColor(context, b.state);
    return Pressable(
      onTap: go,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(b.state.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Text(
                      'Budget · ${b.state.label}',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: Sp.x3),
              _Bar(fraction: b.fraction, color: color),
              const SizedBox(height: Sp.x2),
              Text(
                '${Money.format(b.spent)} of ${Money.format(b.budget)}',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: moneyFeatures,
                ),
              ),
              Text(
                budgetHeadline(b, roast: roast),
                style: context.text.bodySmall?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  const _Bar({required this.fraction, required this.color, this.height = 12});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: height,
        color: color,
        backgroundColor: color.withValues(alpha: 0.16),
      ),
    ),
  );
}

// ───────────────────────── page ─────────────────────────
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetStatusProvider);
    final roast = ref.watch(roastModeProvider).value ?? true;
    final b = async.value;
    final month = DateFormat('MMMM y').format(ref.read(repoProvider).today);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly budget'),
        actions: [
          IconButton(
            tooltip: b == null ? 'Set budget' : 'Edit budget',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showBudgetSheet(context),
          ),
        ],
      ),
      body: !async.hasValue
          ? const Center(child: CircularProgressIndicator.adaptive())
          : b == null
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: 'No budget yet',
              body: 'Pick one amount for the month. It repeats every month, and you can split it by category.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                icon: const Icon(Icons.add),
                label: const Text('Set my budget'),
                onPressed: () => showBudgetSheet(context),
              ),
            )
          : _body(context, ref, b, roast, month),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    BudgetStatus b,
    bool roast,
    String month,
  ) {
    final c = context.cash;
    final colors = _heroColors(b.state);
    final over = b.state == BudgetState.over;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
      children: [
        Reveal(
          child: Container(
            padding: const EdgeInsets.all(Sp.x5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Sp.rCard + 4),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(b.state.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Text(
                        '$month${b.monthOnly ? ' · this month only' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x2),
                Text(
                  b.state.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  budgetHeadline(b, roast: roast),
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Sp.x4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: b.fraction.clamp(0, 1)),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 14,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x3),
                Row(
                  children: [
                    _hero('Budget', Money.format(b.budget)),
                    _hero('Spent', Money.format(b.spent)),
                    _hero(
                      over ? 'Over by' : 'Left',
                      Money.format(b.remaining.abs()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.x3),
        Reveal(
          index: 1,
          child: Wrap(
            spacing: Sp.x3,
            runSpacing: Sp.x3,
            children: [
              if (!b.complete && b.state != BudgetState.over)
                _fact(
                  context,
                  '📆',
                  'Safe to spend',
                  '${Money.format(b.safePerDay)} a day',
                  '${b.daysLeft} days left',
                  const Color(0xFF2F6BFF),
                ),
              if (!b.complete)
                _fact(
                  context,
                  '🔮',
                  'On pace for',
                  Money.format(b.projected),
                  b.projected > b.budget
                      ? 'would finish over'
                      : 'would finish within',
                  b.projected > b.budget ? c.spending : c.income,
                ),
            ],
          ),
        ),
        if (b.splitsOffButFine) ...[
          const SizedBox(height: Sp.x3),
          Reveal(
            index: 2,
            child: Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: c.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Sp.rCard),
              ),
              child: Text(
                '${b.overSplits.map((s) => s.name).join(', ')} ${b.overSplits.length == 1 ? 'is' : 'are'} over '
                '${b.overSplits.length == 1 ? 'its' : 'their'} split, but you are still ${Money.format(b.remaining.abs())} '
                '${b.state == BudgetState.exact ? 'exactly on' : 'under'} your overall budget. '
                'That is fine: money simply moved between categories.',
              ),
            ),
          ),
        ],
        SectionTitle(
          'Splitups',
          trailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add split'),
            onPressed: () => _addSplit(context, ref, b),
          ),
        ),
        if (b.splits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Text(
              'Optional. Set aside part of the budget for categories like Food or Movies. They are a guide: only the overall budget decides under, on or over.',
              style: TextStyle(color: c.textMuted),
            ),
          ),
        for (var i = 0; i < b.splits.length; i++)
          Reveal(index: i + 3, child: _splitRow(context, ref, b, b.splits[i])),
        if (b.splits.isNotEmpty) ...[
          const SizedBox(height: Sp.x2),
          Text(
            b.overAllocated
                ? '⚠️ Splits add up to ${Money.format(b.allocatedTotal)}, more than your ${Money.format(b.budget)} budget.'
                : 'Not yet split: ${Money.format(b.unallocated)}',
            style: context.text.bodySmall?.copyWith(
              color: b.overAllocated ? c.spending : c.textMuted,
            ),
          ),
        ],
        const SectionTitle('Past months'),
        _History(),
      ],
    );
  }

  Widget _hero(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              fontFeatures: moneyFeatures,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fact(
    BuildContext context,
    String emoji,
    String label,
    String value,
    String sub,
    Color color,
  ) => Container(
    constraints: BoxConstraints(
      minWidth: (MediaQuery.sizeOf(context).width - Sp.x4 * 2 - Sp.x3) / 2,
    ),
    padding: const EdgeInsets.all(Sp.x4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(Sp.rCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$emoji  $label',
          style: context.text.labelMedium?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: moneyFeatures,
          ),
        ),
        Text(
          sub,
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
      ],
    ),
  );

  Widget _splitRow(
    BuildContext context,
    WidgetRef ref,
    BudgetStatus b,
    SplitRow s,
  ) {
    final c = context.cash;
    final color = s.isElse ? c.textMuted : budgetColor(context, s.state);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Pressable(
        onTap: s.isElse ? null : () => _editSplit(context, ref, s),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.isElse ? '🧺' : emojiForCategory(s.name),
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Text(
                        s.name,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!s.isElse)
                      Text(
                        s.state == BudgetState.over
                            ? '${Money.format(s.spent - s.allocated)} over'
                            : s.state == BudgetState.exact
                            ? 'used up'
                            : '${Money.format(s.left)} left',
                        style: context.text.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.x2),
                if (!s.isElse)
                  _Bar(
                    fraction: s.allocated == 0 ? 0 : s.spent / s.allocated,
                    color: color,
                    height: 8,
                  ),
                const SizedBox(height: 4),
                Text(
                  s.isElse
                      ? 'Spent ${Money.format(s.spent)} outside your splits'
                      : 'Spent ${Money.format(s.spent)} of ${Money.format(s.allocated)}',
                  style: context.text.bodySmall?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editSplit(
    BuildContext context,
    WidgetRef ref,
    SplitRow s,
  ) async {
    final ctl = TextEditingController(
      text: (s.allocated / 100).toStringAsFixed(2),
    );
    final v = await showDialog<int?>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${s.name} split'),
        content: AmountField(
          controller: ctl,
          label: 'Set aside',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, -1),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final m = Money.parse(ctl.text);
              if (m != null && m > 0) Navigator.pop(d, m);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(repoProvider).setBudgetSplit(s.id, v < 0 ? null : v);
  }

  Future<void> _addSplit(
    BuildContext context,
    WidgetRef ref,
    BudgetStatus b,
  ) async {
    final cats = (await ref.read(repoProvider).categories(kind: 'debit'))
        .where((c) => c.parentId == null)
        .toList();
    final used = b.splits.map((s) => s.id).toSet();
    final free = cats.where((c) => !used.contains(c.id)).toList();
    if (!context.mounted) return;
    if (free.isEmpty) {
      toast(context, 'Every category already has a split.');
      return;
    }
    final picked = await showSheet<Category>(
      context,
      (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x5),
          children: [
            Text(
              'Split for which category?',
              style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Sp.x3),
            for (final c in free)
              ListTile(
                leading: Text(
                  emojiForCategory(c.name),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(c.name),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _editSplit(
      context,
      ref,
      SplitRow(
        id: picked.id,
        name: picked.name,
        colorValue: picked.colorValue,
        allocated: 0,
        spent: 0,
      ),
    );
  }
}

class _History extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(budgetHistoryProvider).value ?? const [];
    if (h.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Sp.x2),
        child: Text(
          'Each finished month shows up here as under, exactly on, or over.',
          style: TextStyle(color: context.cash.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final m in h)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x2),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.x3,
                vertical: Sp.x3,
              ),
              decoration: BoxDecoration(
                color: budgetColor(context, m.state).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Sp.rChip),
              ),
              child: Row(
                children: [
                  Text(m.state.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM y').format(
                        DateTime(
                          int.parse(m.month.substring(0, 4)),
                          int.parse(m.month.substring(5, 7)),
                        ),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${Money.format(m.spent)} / ${Money.format(m.budget)}',
                    style: TextStyle(
                      color: context.cash.textMuted,
                      fontFeatures: moneyFeatures,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── set / edit the budget ─────────────────────────
Future<void> showBudgetSheet(BuildContext context) =>
    showSheet(context, (_) => const _BudgetSheet());

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet();
  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final amount = TextEditingController();
  bool thisMonthOnly = false;
  String? error;
  bool loaded = false;

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(budgetStatusProvider).value;
    if (!loaded && b != null) {
      amount.text = (b.budget / 100).toStringAsFixed(2);
      thisMonthOnly = b.monthOnly;
      loaded = true;
    }
    final now = ref.read(repoProvider).today;
    final month = DateFormat('MMMM').format(now);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 Monthly budget',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              'The most you want to spend in a month. Investments and money lent are not counted.',
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
            const SizedBox(height: Sp.x4),
            AmountField(controller: amount, label: 'Budget', autofocus: true),
            const SizedBox(height: Sp.x3),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(value: false, label: Text('Every month')),
                ButtonSegment(value: true, label: Text('Only $month')),
              ],
              selected: {thisMonthOnly},
              onSelectionChanged: (v) =>
                  setState(() => thisMonthOnly = v.first),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x2),
                child: Text(
                  error!,
                  style: TextStyle(color: context.cash.spending),
                ),
              ),
            const SizedBox(height: Sp.x4),
            FilledButton(
              onPressed: () async {
                final m = Money.parse(amount.text);
                if (m == null || m <= 0) {
                  setState(() => error = 'Enter an amount above zero');
                  return;
                }
                try {
                  await ref
                      .read(repoProvider)
                      .setBudget(m, month: thisMonthOnly ? now : null);
                  if (context.mounted) Navigator.pop(context);
                } on ValidationException catch (e) {
                  setState(() => error = e.message);
                }
              },
              child: const Text('Save budget'),
            ),
            if (b != null)
              TextButton(
                onPressed: () async {
                  await ref.read(repoProvider).setBudget(null);
                  await ref.read(repoProvider).setBudget(null, month: now);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Remove budget'),
              ),
          ],
        ),
      ),
    );
  }
}

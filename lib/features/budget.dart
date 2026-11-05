import 'package:fl_chart/fl_chart.dart';
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

// ───────────────────────── card on Home ─────────────────────────
class _BudgetRing extends StatelessWidget {
  final double fraction;
  final Color color;
  final double size;
  final Widget center;
  const _BudgetRing({
    required this.fraction,
    required this.color,
    required this.size,
    required this.center,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: fraction.clamp(0, 1)),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.1,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: context.scheme.outlineVariant,
            ),
          ),
        ),
        center,
      ],
    ),
  );
}

class _StatePill extends StatelessWidget {
  final BudgetState state;
  const _StatePill(this.state);
  @override
  Widget build(BuildContext context) {
    final color = budgetColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetStatusProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final b = async.value;
    void go() => Navigator.of(context).push(softRoute(const BudgetPage()));
    if (b == null) {
      return Pressable(
        onTap: go,
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sp.rCard),
            color: context.scheme.primaryContainer,
          ),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: context.scheme.primary),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set a monthly budget',
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
              const Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      );
    }
    final color = budgetColor(context, b.state);
    final over = b.state == BudgetState.over;
    return Pressable(
      onTap: go,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            children: [
              _BudgetRing(
                fraction: b.fraction,
                color: color,
                size: 76,
                center: Text(
                  '${(b.fraction * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: context.scheme.onSurface,
                    fontFeatures: moneyFeatures,
                  ),
                ),
              ),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Eyebrow('Budget')),
                        _StatePill(b.state),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: Money.format(b.remaining.abs()),
                              style: context.text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                letterSpacing: -0.8,
                                color: over ? color : null,
                                fontFeatures: moneyFeatures,
                              ),
                            ),
                            TextSpan(
                              text: over ? '  over' : '  left',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.cash.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.complete
                          ? 'of ${Money.format(b.budget)}'
                          : 'of ${Money.format(b.budget)}  ·  ${b.daysLeft} days left',
                      style: context.text.bodySmall?.copyWith(
                        color: context.cash.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
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
        backgroundColor: color.withValues(alpha: 0.14),
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
    final over = b.state == BudgetState.over;
    final color = budgetColor(context, b.state);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
      children: [
        Reveal(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x5),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Eyebrow(
                      '$month${b.monthOnly ? ' · this month only' : ''}',
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  _BudgetRing(
                    fraction: b.fraction,
                    color: color,
                    size: 190,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Money.format(b.remaining.abs()),
                            style: context.text.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: over ? color : null,
                              fontFeatures: moneyFeatures,
                            ),
                          ),
                        ),
                        Text(
                          over ? 'over budget' : 'left to spend',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  _StatePill(b.state),
                  const SizedBox(height: Sp.x2),
                  Text(
                    budgetHeadline(b, roast: roast),
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  const Divider(),
                  const SizedBox(height: Sp.x3),
                  Row(
                    children: [
                      _hero(context, 'Budget', Money.format(b.budget)),
                      _hero(context, 'Spent', Money.format(b.spent)),
                      if (!b.complete && b.state != BudgetState.over)
                        _hero(context, 'Safe a day', Money.format(b.safePerDay))
                      else
                        _hero(
                          context,
                          b.complete ? 'Result' : 'Over by',
                          over ? Money.format(b.remaining.abs()) : 'On target',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Sp.x3),
        Reveal(index: 1, child: _ChartCard(status: b)),
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

  Widget _hero(BuildContext context, String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: moneyFeatures,
            ),
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

// ───────────────────────── charts ─────────────────────────
class _ChartCard extends ConsumerStatefulWidget {
  final BudgetStatus status;
  const _ChartCard({required this.status});
  @override
  ConsumerState<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends ConsumerState<_ChartCard> {
  bool year = false;
  @override
  Widget build(BuildContext context) {
    final b = widget.status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('Spending vs budget')),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month')),
                    ButtonSegment(value: true, label: Text('Year')),
                  ],
                  selected: {year},
                  onSelectionChanged: (v) => setState(() => year = v.first),
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            SizedBox(
              height: 190,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: year
                    ? _YearChart(key: const ValueKey('y'))
                    : _MonthChart(key: const ValueKey('m'), status: b),
              ),
            ),
            const SizedBox(height: Sp.x2),
            year ? const _YearLegend() : _MonthLegend(status: b),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<(Color, String, bool)> items; // colour, label, dashed
  const _Legend(this.items);
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Sp.x4,
    runSpacing: 4,
    children: [
      for (final i in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: i.$1,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              i.$2,
              style: context.text.labelSmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
          ],
        ),
    ],
  );
}

class _MonthLegend extends StatelessWidget {
  final BudgetStatus status;
  const _MonthLegend({required this.status});
  @override
  Widget build(BuildContext context) => _Legend([
    (budgetColor(context, status.state), 'Spent so far', false),
    (context.cash.textMuted, 'Budget', true),
    if (!status.complete && status.daysElapsed >= 7)
      (context.scheme.primary, 'Pace to month end', true),
  ]);
}

class _YearLegend extends StatelessWidget {
  const _YearLegend();
  @override
  Widget build(BuildContext context) => _Legend([
    (context.cash.income, 'Under', false),
    (const Color(0xFFF59E0B), 'Exactly on', false),
    (context.cash.spending, 'Over', false),
    (context.cash.textMuted.withValues(alpha: 0.5), 'Budget', false),
  ]);
}

/// Short axis labels: 500, 5K, 50K, 1.5L (lakh), 1.2Cr.
String _k(double v) {
  String t(double x) =>
      x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
  if (v >= 10000000) return '₹${t(v / 10000000)}Cr';
  if (v >= 100000) return '₹${t(v / 100000)}L';
  if (v >= 1000) return '₹${t(v / 1000)}K';
  return '₹${v.round()}';
}

class _MonthChart extends ConsumerWidget {
  final BudgetStatus status;
  const _MonthChart({super.key, required this.status});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(budgetDailyProvider).value ?? const <int>[];
    final b = status;
    final color = budgetColor(context, b.state);
    final muted = context.cash.textMuted;
    final spots = [
      FlSpot(0, 0),
      for (var i = 0; i < daily.length; i++) FlSpot(i + 1.0, daily[i] / 100),
    ];
    final today = daily.length;
    final maxV =
        [
          b.budget / 100,
          b.projected / 100,
          (daily.isEmpty ? 0 : daily.last) / 100,
        ].reduce((a, c) => a > c ? a : c) *
        1.12;
    // the first week is too little to project from
    final pace = !b.complete && today >= 7
        ? [
            FlSpot(today.toDouble(), daily.last / 100),
            FlSpot(b.daysInMonth.toDouble(), b.projected / 100),
          ]
        : <FlSpot>[];
    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: b.daysInMonth.toDouble(),
          minY: 0,
          maxY: maxV <= 0 ? 1 : maxV,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.scheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : Text(_k(v), style: TextStyle(fontSize: 10, color: muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${v.round()}',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: b.budget / 100,
                color: muted,
                strokeWidth: 1.4,
                dashArray: [6, 5],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    'Day ${s.x.round()}  ${Money.format((s.y * 100).round())}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (pace.length == 2)
              LineChartBarData(
                spots: pace,
                color: context.scheme.primary,
                barWidth: 2,
                dashArray: [5, 5],
                dotData: FlDotData(
                  getDotPainter: (s, _, _, i) => FlDotCirclePainter(
                    radius: i == 1 ? 3.5 : 0,
                    color: context.scheme.primary,
                    strokeWidth: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YearChart extends ConsumerWidget {
  const _YearChart({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(budgetYearProvider).value;
    if (months == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final muted = context.cash.textMuted;
    var maxV = 1.0;
    for (final m in months) {
      maxV = [
        maxV,
        m.spent / 100,
        (m.budget ?? 0) / 100,
      ].reduce((a, c) => a > c ? a : c);
    }
    Color barColor(BudgetYearMonth m) => switch (m.state) {
      BudgetState.under => context.cash.income,
      BudgetState.exact => const Color(0xFFF59E0B),
      BudgetState.over => context.cash.spending,
      null => muted.withValues(alpha: 0.45),
    };
    const initials = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
    ];
    return ExcludeSemantics(
      child: BarChart(
        BarChartData(
          maxY: maxV * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.scheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : Text(_k(v), style: TextStyle(fontSize: 10, color: muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    initials[v.round().clamp(0, 11)],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: months[v.round().clamp(0, 11)].current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: months[v.round().clamp(0, 11)].current
                          ? context.scheme.onSurface
                          : muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) {
                final m = months[group.x];
                final name = DateFormat('MMM').format(DateTime(2000, m.month));
                return BarTooltipItem(
                  m.future
                      ? name
                      : '$name\n${Money.format(m.spent)}${m.budget != null ? ' of ${Money.format(m.budget!)}' : ''}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: months[i].future ? 0 : months[i].spent / 100,
                    width: 13,
                    borderRadius: BorderRadius.circular(5),
                    color: barColor(months[i]),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: months[i].budget != null,
                      toY: (months[i].budget ?? 0) / 100,
                      color: muted.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/category_insight.dart';
import '../data/repo.dart' show CatSlice;
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Tap a category (or sub-category) in "Where your money went" to land here.
class CategoryInsightPage extends ConsumerWidget {
  final String categoryId;
  final DateRange range;
  const CategoryInsightPage({
    super.key,
    required this.categoryId,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    return FutureBuilder<CategoryInsight>(
      future: repo.categoryInsight(categoryId, range),
      builder: (context, snap) {
        final x = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              x == null
                  ? ''
                  : '${emojiForCategory(x.name, x.parentName)}  ${x.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: x == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _Body(x: x, range: range),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final CategoryInsight x;
  final DateRange range;
  const _Body({required this.x, required this.range});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.cash;
    final change = x.changePct;
    final up = (change ?? 0) >= 0;
    // spending going down is good
    final good = !up;
    final lightMode = !dark;
    final goodC = lightMode ? const Color(0xFF066B49) : c.income;
    final badC = lightMode ? const Color(0xFFB0123A) : c.spending;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x8),
      children: [
        Reveal(
          child: Container(
            padding: const EdgeInsets.all(Sp.x5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Sp.rCard + 4),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF4A32C8), Color(0xFF6046D8)]
                    : const [Color(0xFF5232E0), Color(0xFF6A4AE0)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU SPENT',
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Sp.x2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(x.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x3),
                Wrap(
                  spacing: Sp.x2,
                  runSpacing: Sp.x2,
                  children: [
                    _pill(
                      '${x.sharePct.toStringAsFixed(x.sharePct < 10 ? 1 : 0)}% of all spending',
                    ),
                    if (change != null)
                      _pill(
                        '${up ? '▲' : '▼'} ${change.abs().round()}% vs last period',
                      ),
                    _pill('${x.count} ${x.count == 1 ? 'entry' : 'entries'}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.x3),
        Reveal(
          index: 1,
          child: Row(
            children: [
              Expanded(child: _stat(context, 0, '📅', 'Per day', x.perDay)),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: _stat(context, 1, '🗓️', 'Per month', x.perMonth),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: _stat(context, 2, '🧾', 'Each time', x.avgPerEntry),
              ),
            ],
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: Sp.x3),
          Reveal(
            index: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: Row(
                  children: [
                    Text(
                      good ? '👍' : '👀',
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Text(
                        good
                            ? 'You spent ${Money.format((x.prevTotal - x.total).abs())} less on ${x.name} than the last period. Nice!'
                            : 'You spent ${Money.format((x.total - x.prevTotal).abs())} more on ${x.name} than the last period.',
                        style: context.text.bodyMedium?.copyWith(
                          color: good ? goodC : badC,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SectionTitle('Last 6 months'),
        Reveal(index: 3, child: _MonthsChart(x: x)),
        if (x.subs.length > 1) ...[
          const SectionTitle('Inside this category'),
          Reveal(
            index: 4,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: Column(
                  children: [
                    for (final (i, s) in x.subs.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : Sp.x3),
                        child: _SubRow(slice: s, total: x.total, index: i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (x.top.isNotEmpty) ...[
          const SectionTitle('Biggest expenses'),
          Reveal(
            index: 5,
            child: Card(
              child: Column(
                children: [
                  for (final (i, t) in x.top.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: context.scheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: context.scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        t.title.isEmpty ? x.name : t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        DateFormat('d MMM y').format(Dates.parse(t.date)),
                      ),
                      trailing: MoneyText(
                        t.minor,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _stat(
    BuildContext context,
    int tile,
    String emoji,
    String label,
    int minor,
  ) => Container(
    padding: const EdgeInsets.all(Sp.x3),
    decoration: BoxDecoration(
      color: CashColors.tile(tile, Theme.of(context).brightness),
      borderRadius: BorderRadius.circular(Sp.rCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUp(
            value: minor,
            builder: (v) => Text(
              Money.compact(v),
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SubRow extends StatelessWidget {
  final CatSlice slice;
  final int total, index;
  const _SubRow({
    required this.slice,
    required this.total,
    required this.index,
  });
  @override
  Widget build(BuildContext context) {
    final color = Color(slice.colorValue);
    final pct = total == 0 ? 0.0 : slice.totalMinor / total;
    return Row(
      children: [
        Text(
          emojiForCategory(slice.name, slice.parentName),
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slice.name,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${(pct * 100).round()}%',
                    style: context.text.labelMedium?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                  const SizedBox(width: Sp.x2),
                  MoneyText(
                    slice.totalMinor,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: pct),
                  duration: Duration(milliseconds: 700 + index * 80),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthsChart extends StatelessWidget {
  final CategoryInsight x;
  const _MonthsChart({required this.x});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFFA793FF) : const Color(0xFF7C5CF0);
    final maxV = x.monthly.fold<int>(0, (a, m) => m.minor > a ? m.minor : a);
    final avg = x.monthly.isEmpty
        ? 0
        : x.monthly.fold<int>(0, (a, m) => a + m.minor) ~/ x.monthly.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average ${Money.format(avg)} a month',
              style: context.text.labelLarge?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
            const SizedBox(height: Sp.x3),
            SizedBox(
              height: 150,
              child: maxV == 0
                  ? Center(
                      child: Text(
                        'No history yet',
                        style: TextStyle(color: context.cash.textMuted),
                      ),
                    )
                  : BarChart(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      BarChartData(
                        maxY: maxV / Money.unit * 1.2,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  x.monthly[v.toInt()].label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.cash.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (final (i, m) in x.monthly.indexed)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: m.minor / Money.unit,
                                  width: 22,
                                  color: i == x.monthly.length - 1
                                      ? base
                                      : base.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

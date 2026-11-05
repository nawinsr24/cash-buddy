import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/grade.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String _monthName(String key) => DateFormat('MMM').format(
  DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(5, 7))),
);

Color scoreColor(BuildContext c, int score, {bool building = false}) {
  if (building) return c.cash.textMuted;
  if (score >= 70) return c.cash.income;
  if (score >= 50) return c.cash.debtIn;
  return c.cash.spending;
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color track, a, b;
  final double stroke;
  _RingPainter(this.fraction, this.track, this.a, this.b, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    if (fraction <= 0) return;
    final arc = base
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [a, b],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(r);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.fraction != fraction || o.a != a;
}

/// The Money Health ring: gradient arc with the number in the middle.
class GradeRing extends StatelessWidget {
  final MoneyGrade grade;
  final double size;
  const GradeRing({super.key, required this.grade, this.size = 84});
  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, grade.score, building: grade.building);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: grade.building ? 0 : grade.score / 100),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(
            v,
            context.scheme.outlineVariant,
            color.withValues(alpha: 0.55),
            color,
            size * 0.1,
          ),
          child: Center(
            child: grade.building
                ? Text(
                    '—',
                    style: TextStyle(
                      fontSize: size * 0.3,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(v * 100).round()}',
                        style: TextStyle(
                          fontSize: size * 0.34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                          color: context.scheme.onSurface,
                          fontFeatures: moneyFeatures,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact Money Health row for Home.
class PlusScoreCard extends ConsumerWidget {
  const PlusScoreCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plusScoreProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    if (async == null) return const SizedBox.shrink();
    final g = async.grade;
    final c = context.cash;
    final delta = async.prevScore == null ? null : g.score - async.prevScore!;
    return Pressable(
      onTap: () => pushReveal(context, const PlusScoreDetailPage()),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            children: [
              GradeRing(grade: g, size: 76),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Money Health'),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            g.building ? 'Building…' : g.level,
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scoreColor(
                                context,
                                g.score,
                                building: g.building,
                              ),
                            ),
                          ),
                        ),
                        if (delta != null && !g.building && delta != 0) ...[
                          const SizedBox(width: Sp.x2),
                          Icon(
                            delta > 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: delta > 0 ? c.income : c.spending,
                          ),
                          Text(
                            '${delta.abs()} vs ${_monthName(async.prevMonth!)}',
                            style: context.text.labelMedium?.copyWith(
                              color: delta > 0 ? c.income : c.spending,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.building
                          ? 'Add 10 entries to see your score.'
                          : nextStep(async.stats, roast: roast),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
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

class PlusScoreDetailPage extends ConsumerWidget {
  const PlusScoreDetailPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plusScoreProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Money Health')),
      body: async == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _body(
              context,
              ref,
              async.stats,
              async.grade,
              async.prevScore,
              async.prevMonth,
              roast,
            ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    MonthStats s,
    MoneyGrade g,
    int? prevScore,
    String? prevMonth,
    bool roast,
  ) {
    final c = context.cash;
    final color = scoreColor(context, g.score, building: g.building);
    final gap = g.biggestGap;
    final delta = prevScore == null ? null : g.score - prevScore;
    final history = ref.watch(scoreHistoryProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
      children: [
        Center(child: GradeRing(grade: g, size: 168)),
        const SizedBox(height: Sp.x3),
        Center(
          child: Text(
            g.building ? 'Not enough entries yet' : g.level,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Center(
          child: Text(
            g.building
                ? 'Add 10 entries this month'
                : '${g.score} out of 100${delta != null && delta != 0 ? '  ·  ${delta > 0 ? '▲' : '▼'} ${delta.abs()} vs ${_monthName(prevMonth!)}' : ''}',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          ),
        ),
        if (history.length >= 2) ...[
          const SectionTitle('Last 12 months'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x3, Sp.x4, Sp.x4, Sp.x2),
              child: SizedBox(
                height: 140,
                child: _TrendChart(history: history, color: color),
              ),
            ),
          ),
        ],
        const SectionTitle('What makes it up'),
        for (var i = 0; i < g.parts.length; i++)
          Reveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: _PartRow(
                part: g.parts[i],
                isGap: gap == g.parts[i] && !g.building,
              ),
            ),
          ),
        const SizedBox(height: Sp.x2),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Next move'),
                const SizedBox(height: Sp.x2),
                Text(nextStep(s, roast: roast), style: context.text.bodyLarge),
              ],
            ),
          ),
        ),
        if (healthNote(s, seed: 'now') != null) ...[
          const SizedBox(height: Sp.x3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(healthNote(s, seed: 'now')!),
            ),
          ),
        ],
        const SectionTitle('How it is calculated'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in _howItWorks(s))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x2),
                    child: Text(
                      line,
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                Text(
                  'A guide to your habits, not financial advice. Covers this month so far.',
                  style: context.text.bodySmall?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _howItWorks(MonthStats s) => [
    'Tap the ⓘ next to any item to see what it means.',
    'Saving power: full marks when you keep 30% of your income.',
    if (s.budgetMinor != null)
      'Budget discipline: full marks while you stay inside your budget.',
    'Spending discipline: full marks when you spend less than your usual.',
    'Debt freedom: full marks when nothing is overdue.',
    'Wealth growth: full marks when you invest 15% of your income.',
    'Money awareness: full marks when you add entries on 20 days.',
    if (s.budgetMinor == null) 'No budget set, so the budget part is left out and the others count a little more.',
  ];
}

class _PartRow extends StatelessWidget {
  final GradePart part;
  final bool isGap;
  const _PartRow({required this.part, required this.isGap});
  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final color = scoreColor(context, (part.fraction * 100).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      part.label,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showPartInfo(context, part.label),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: c.textMuted,
                        semanticLabel: 'What is ${part.label}?',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isGap)
              Container(
                margin: const EdgeInsets.only(right: Sp.x2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.debtIn.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'biggest gain',
                  style: TextStyle(
                    color: c.debtIn,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              '${part.score.round()} / ${part.max.round()}',
              style: context.text.labelLarge?.copyWith(
                color: c.textMuted,
                fontFeatures: moneyFeatures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: part.fraction),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: context.scheme.outlineVariant,
            ),
          ),
        ),
        if (isGap && part.hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              part.hint,
              style: context.text.bodySmall?.copyWith(color: c.textMuted),
            ),
          ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<({String month, int score})> history;
  final Color color;
  const _TrendChart({required this.history, required this.color});
  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].score.toDouble()),
    ];
    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
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
                reservedSize: 28,
                interval: 25,
                getTitlesWidget: (v, _) => Text(
                  '${v.round()}',
                  style: TextStyle(fontSize: 10, color: context.cash.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= history.length || v != i.toDouble()) {
                    return const SizedBox.shrink();
                  }
                  if (history.length > 6 && i % 2 == 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthName(history[i].month),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.cash.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${_monthName(history[s.x.round()].month)}  ${s.y.round()}',
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
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (s, _, _, i) => FlDotCirclePainter(
                  radius: i == history.length - 1 ? 4.5 : 2.5,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: context.cash.surfaceRaised,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0),
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

/// "This month so far: 🍔 Foodie Bankrupt" chip on Home. Provisional until the
/// month ends; shows what it was before it last changed.
class LiveTitleChip extends ConsumerWidget {
  const LiveTitleChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(liveTitleProvider).value;
    if (t == null) return const SizedBox.shrink();
    final c = context.cash;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Pressable(
        onTap: () => _sheet(context, ref, t.id, t.previous),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.id.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'This month so far  ',
                        style: TextStyle(color: c.textMuted, fontSize: 12.5),
                      ),
                      TextSpan(
                        text: t.id.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t.previous != null && t.previous != t.id) ...[
                const SizedBox(width: 6),
                Icon(
                  t.id.positive && !t.previous!.positive
                      ? Icons.arrow_upward
                      : (!t.id.positive && t.previous!.positive
                            ? Icons.arrow_downward
                            : Icons.swap_vert),
                  size: 14,
                  color: c.textMuted,
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _sheet(BuildContext context, WidgetRef ref, TitleId id, TitleId? prev) {
    final s = ref.read(plusScoreProvider).value?.stats;
    final roast = ref.read(roastModeProvider).value ?? true;
    showSheet(
      context,
      (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Your title so far this month'),
              const SizedBox(height: Sp.x3),
              Row(
                children: [
                  Text(id.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      id.title,
                      style: ctx.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),
              if (s != null)
                Text(
                  titleLines(id, s, roast: roast).first,
                  style: ctx.text.bodyLarge,
                ),
              const SizedBox(height: Sp.x3),
              Text(
                'Why: ${id.rule}',
                style: ctx.text.bodyMedium?.copyWith(color: ctx.cash.textMuted),
              ),
              if (prev != null && prev != id)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.x2),
                  child: Text(
                    'Before this you held ${prev.title}.',
                    style: ctx.text.bodyMedium?.copyWith(
                      color: ctx.cash.textMuted,
                    ),
                  ),
                ),
              const SizedBox(height: Sp.x3),
              Text(
                'It can change day by day. It is final on the last day of the month, and you will get a celebration when the new month starts.',
                style: ctx.text.bodySmall?.copyWith(color: ctx.cash.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _partInfo = <String, (String, String)>{
  'Saving power': (
    'How much of your income you keep.',
    'Example: you earn ₹30,000 and keep ₹9,000. That is 30% and gives full marks. Spending everything gives zero.',
  ),
  'Budget discipline': (
    'Did you stay inside the budget you set?',
    'Full marks while your spending is within your budget. Marks drop as you go over, and reach zero when you are 25% over.',
  ),
  'Spending discipline': (
    'Are you spending less than your usual?',
    'We compare this month with your average of the last 3 months. Spending the same or less gives full marks.',
  ),
  'Debt freedom': (
    'Are your loans and dues under control?',
    'You lose marks for overdue payments and for owing a lot. Paying on time keeps this full.',
  ),
  'Wealth growth': (
    'Are you putting money into investments?',
    'Investing 15% of your income gives full marks. Even a small SIP helps.',
  ),
  'Money awareness': (
    'Do you note your spending regularly?',
    'Adding entries on 20 days of the month gives full marks. What you track, you can control.',
  ),
};

void _showPartInfo(BuildContext context, String label) {
  final info = _partInfo[label];
  if (info == null) return;
  showSheet(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            info.$1,
            style: ctx.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Sp.x2),
          Text(info.$2, style: ctx.text.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: Sp.x4),
        ],
      ),
    ),
  );
}

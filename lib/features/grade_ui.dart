import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/insights_repo.dart';
import '../domain/grade.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String monthName(String key, {bool year = false}) {
  final d = DateTime(
    int.parse(key.substring(0, 4)),
    int.parse(key.substring(5, 7)),
  );
  return DateFormat(year ? 'MMMM y' : 'MMMM').format(d);
}

/// Colours for a title card: warm for good months, a hot red-orange for bad ones.
List<Color> titleColors(TitleId t) => t.positive
    ? const [Color(0xFF22B573), Color(0xFF2F6BFF)]
    : switch (t) {
        TitleId.freshVictim ||
        TitleId.balancedSpender => const [Color(0xFF64748B), Color(0xFF8B5CF6)],
        _ => const [Color(0xFFFF6B3D), Color(0xFFEC4899)],
      };

String _line(TitleId t, MonthStats s, String seed, bool roast) {
  final lines = titleLines(t, s, roast: roast);
  final i = seed.codeUnits.fold<int>(0, (a, b) => a + b) % lines.length;
  return lines[i];
}

// ───────────────────────── banner on top of Home ─────────────────────────
class TitleBanner extends ConsumerWidget {
  const TitleBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(bannerTitleProvider).value;
    if (b == null) return const SizedBox.shrink();
    final colors = titleColors(b.id);
    return TweenAnimationBuilder<double>(
      key: ValueKey(b.month),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -40),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Sp.x3),
        child: Pressable(
          onTap: () =>
              Navigator.of(context).push(softRoute(TitleRevealPage(title: b))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x2, Sp.x3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Sp.rCard),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(b.id.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${monthName(b.month)} title is ready',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        b.id.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () =>
                      ref.read(repoProvider).dismissTitleBanner(b.month),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── the reveal ─────────────────────────
class TitleRevealPage extends ConsumerWidget {
  final MonthTitle title;
  const TitleRevealPage({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final roast = ref.watch(roastModeProvider).value ?? true;
    final colors = titleColors(title.id);
    return Scaffold(
      backgroundColor: colors.first,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<MonthStats>(
            future: repo.monthStats(title.year, title.monthNo),
            builder: (context, snap) {
              final s = snap.data;
              final note = s == null ? null : healthNote(s, seed: title.month);
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.x6,
                        0,
                        Sp.x6,
                        Sp.x6,
                      ),
                      child: Column(
                        children: [
                          Reveal(
                            child: Text(
                              monthName(title.month, year: true).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: Sp.x5),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.elasticOut,
                            builder: (_, t, c) => Transform.scale(
                              scale: t.clamp(0, 1.2),
                              child: c,
                            ),
                            child: Text(
                              title.id.emoji,
                              style: const TextStyle(fontSize: 96),
                            ),
                          ),
                          const SizedBox(height: Sp.x4),
                          Reveal(
                            index: 2,
                            child: Text(
                              title.id.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: Sp.x4),
                          if (s != null)
                            Reveal(
                              index: 3,
                              child: Text(
                                _line(title.id, s, title.month, roast),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: Sp.x5),
                          if (s != null) ...[
                            Reveal(index: 4, child: _proof(context, s)),
                            const SizedBox(height: Sp.x4),
                            Reveal(
                              index: 5,
                              child: _box(
                                '👉  Next move',
                                nextStep(s, roast: roast),
                              ),
                            ),
                          ],
                          if (note != null) ...[
                            const SizedBox(height: Sp.x4),
                            Reveal(
                              index: 6,
                              child: _box(
                                '💚  Take care of yourself',
                                note,
                                foot: 'General encouragement, not medical advice.',
                              ),
                            ),
                          ],
                          const SizedBox(height: Sp.x5),
                          Reveal(
                            index: 7,
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: colors.first,
                                      minimumSize: const Size.fromHeight(52),
                                    ),
                                    icon: const Icon(Icons.ios_share),
                                    label: const Text('Copy to share'),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text:
                                              '${title.id.emoji} My ${monthName(title.month)} title on Cash++: ${title.id.title}',
                                        ),
                                      );
                                      if (context.mounted) {
                                        toast(
                                          context,
                                          'Copied. Paste it anywhere (no amounts included).',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _box(String head, String body, {String? foot}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Sp.x4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(Sp.rCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          head,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: Sp.x2),
        Text(body, style: const TextStyle(color: Colors.white, height: 1.35)),
        if (foot != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x2),
            child: Text(
              foot,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
      ],
    ),
  );

  Widget _proof(BuildContext context, MonthStats s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Sp.x4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(Sp.rCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why you got it',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(title.id.rule, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: Sp.x3),
        Wrap(
          spacing: Sp.x4,
          runSpacing: Sp.x2,
          children: [
            _stat('Income', Money.format(s.income)),
            _stat('Spent', Money.format(s.spending)),
            if (s.income > 0) _stat('Saved', '${(s.saveRate * 100).round()}%'),
            if (s.invested > 0) _stat('Invested', Money.format(s.invested)),
            if (s.healthSpending > 0)
              _stat('Health', Money.format(s.healthSpending)),
          ],
        ),
      ],
    ),
  );

  Widget _stat(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(
        v,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontFeatures: moneyFeatures,
        ),
      ),
    ],
  );
}

// ───────────────────────── Money Grade ─────────────────────────
class _RingPainter extends CustomPainter {
  final double fraction;
  final Color track, color;
  _RingPainter(this.fraction, this.track, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.fraction != fraction || o.color != color;
}

Color gradeColor(int score) => score >= 75
    ? const Color(0xFF22B573)
    : score >= 55
    ? const Color(0xFFF59E0B)
    : const Color(0xFFEF4444);

class GradeRing extends StatelessWidget {
  final MoneyGrade grade;
  final double size;
  const GradeRing({super.key, required this.grade, this.size = 96});
  @override
  Widget build(BuildContext context) {
    final color = grade.building
        ? context.cash.textMuted
        : gradeColor(grade.score);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: grade.building ? 0 : grade.score / 100),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(v, color.withValues(alpha: 0.18), color),
          child: Center(
            child: Text(
              grade.building ? '…' : grade.letter,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradeCard extends ConsumerWidget {
  const GradeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(monthStatsProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    if (s == null) return const SizedBox.shrink();
    final g = computeGrade(s);
    final c = context.cash;
    return Pressable(
      onTap: () =>
          Navigator.of(context).push(softRoute(const GradeDetailPage())),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            children: [
              GradeRing(grade: g),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Grade',
                      style: context.text.labelLarge?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                    Text(
                      g.building
                          ? 'Building your grade…'
                          : '${g.score}/100 this month',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.building
                          ? 'Log 10 entries and I will start judging you.'
                          : nextStep(s, roast: roast),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradeDetailPage extends ConsumerWidget {
  const GradeDetailPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(monthStatsProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Money Grade')),
      body: s == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _body(context, s, roast),
    );
  }

  Widget _body(BuildContext context, MonthStats s, bool roast) {
    final g = computeGrade(s);
    final c = context.cash;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
      children: [
        Center(child: GradeRing(grade: g, size: 150)),
        const SizedBox(height: Sp.x3),
        Center(
          child: Text(
            g.building ? 'Not enough entries yet' : '${g.score} out of 100',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: Sp.x5),
        for (var i = 0; i < g.parts.length; i++)
          Reveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.parts[i].label,
                          style: context.text.titleSmall,
                        ),
                      ),
                      Text(
                        '${g.parts[i].score.round()}/${g.parts[i].max.round()}',
                        style: context.text.labelLarge?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: g.parts[i].fraction),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        color: gradeColor((v * 100).round()),
                        backgroundColor: c.textMuted.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
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
                Text(
                  '👉  Next move',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Sp.x2),
                Text(nextStep(s, roast: roast)),
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
        const SizedBox(height: Sp.x3),
        Text(
          'A guide to your habits, not financial advice. Covers this month so far.',
          style: context.text.bodySmall?.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

// ───────────────────────── trophy shelf ─────────────────────────
class TrophyShelfPage extends ConsumerWidget {
  const TrophyShelfPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(titleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trophy shelf')),
      body: list.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No titles yet',
              body: 'Your first title arrives after your first full month of entries.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x8),
            children: [
              for (var i = 0; i < items.length; i++)
                Reveal(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x3),
                    child: Pressable(
                      onTap: () => Navigator.of(context)
                          .push(softRoute(TitleRevealPage(title: items[i]))),
                      child: Container(
                        padding: const EdgeInsets.all(Sp.x4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Sp.rCard),
                          gradient: LinearGradient(
                            colors: [
                              titleColors(items[i].id).first
                                  .withValues(alpha: 0.25),
                              titleColors(items[i].id).last
                                  .withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              items[i].id.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: Sp.x3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    items[i].id.title,
                                    style: context.text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    monthName(items[i].month, year: true),
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── insights strip ─────────────────────────
class InsightsStrip extends ConsumerWidget {
  const InsightsStrip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = ref.watch(insightsProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    if (x == null) return const SizedBox.shrink();
    final c = context.cash;
    final vs = x.vsLastMonthPct;
    final cards = <_Insight>[
      _Insight(
        '🔮',
        'On pace to spend',
        Money.format(x.projected),
        '${x.daysLeft} days left this month',
        const Color(0xFF8B5CF6),
      ),
      _Insight(
        '📆',
        'Daily average',
        Money.format(x.dailyAvg),
        'so far this month',
        const Color(0xFF2F6BFF),
      ),
      if (vs != null)
        _Insight(
          vs > 0 ? '📈' : '📉',
          'Vs last month',
          '${vs > 0 ? '+' : ''}$vs%',
          vs > 0
              ? (roast ? 'Spending more. Brave.' : 'Spending is up')
              : (roast ? 'Spending less. Who are you?' : 'Spending is down'),
          vs > 0 ? c.spending : c.income,
        ),
      if (x.topCategory != null)
        _Insight(
          '🏷️',
          'Top spend',
          x.topCategory!,
          Money.format(x.topCategoryMinor),
          const Color(0xFFFF8A3D),
        ),
      _Insight(
        '🏦',
        'Net worth',
        Money.format(x.netWorth),
        'balance + investments + debts',
        const Color(0xFF22B573),
      ),
      for (final b in x.bills)
        _Insight(
          '🔁',
          b.merchant,
          Money.format(b.amountMinor),
          'next ${DateFormat('d MMM').format(b.next)}',
          const Color(0xFFEC4899),
        ),
    ];
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: Sp.x3),
        itemBuilder: (_, i) => Reveal(index: i, child: _InsightCard(cards[i])),
      ),
    );
  }
}

class _Insight {
  final String emoji, label, value, sub;
  final Color color;
  const _Insight(this.emoji, this.label, this.value, this.sub, this.color);
}

class _InsightCard extends StatelessWidget {
  final _Insight i;
  const _InsightCard(this.i);
  @override
  Widget build(BuildContext context) => Container(
    width: 158,
    padding: const EdgeInsets.all(Sp.x3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Sp.rCard),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          i.color.withValues(alpha: 0.22),
          i.color.withValues(alpha: 0.08),
        ],
      ),
      border: Border.all(color: i.color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(i.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                i.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium,
              ),
            ),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            i.value,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: i.color,
              fontFeatures: moneyFeatures,
            ),
          ),
        ),
        Text(
          i.sub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
      ],
    ),
  );
}

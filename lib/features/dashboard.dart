import '../l10n/l10n.dart';
import '../ui/brand.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/invest_repo.dart';
import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/emoji.dart';
import '../domain/budget.dart' show SplitRow;
import 'budget_rings.dart';
import 'home_share.dart';
import 'partner_balance.dart';
import 'card_warning.dart';
import 'category_insight_page.dart';
import 'performance_sheet.dart';
import 'grade_ui.dart';
import 'score_ui.dart';
import 'invest.dart';
import '../ui/widgets.dart';
import 'transactions.dart';

enum Pillar { spending, income, incoming, liabilities }

class DashboardPage extends ConsumerWidget {
  final VoidCallback onOpenInbox;
  final VoidCallback? onOpenInvest;
  const DashboardPage({
    super.key,
    required this.onOpenInbox,
    this.onOpenInvest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider).value;
    final pending = ref.watch(pendingSmsProvider).value?.length ?? 0;
    final invest = ref.watch(investSummariesProvider).value ?? const [];
    final homePeriod = ref.watch(homePeriodProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: BrandLogo(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Sp.x3),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.1,
              child: Pressable(
                onTap: () {
                  haptic();
                  showPerformanceSheet(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E0D0B), Color(0xFF2A2822)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✨ Performance',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Add')),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      ),
      body: data.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 96),
          children: [
            const PeriodBar(),
            const SizedBox(height: Sp.x3),
            if ((settings?.smsEnabled ?? false) && pending > 0)
              _SmsBanner(count: pending, onTap: onOpenInbox),
            BalanceRow(
              mine: _BalanceCard(
                total: d.totalBalance,
                split: settings?.split ?? false,
                trend: _trend(d),
              ),
            ),
            const SizedBox(height: Sp.x3),
            const HomeInviteCard(),
            const BudgetRings(),
            const CardWarningLine(),
            const SectionTitle('Where your money went'),
            // while sharing, one chart for both of us
            MoneyWent(
              main: homePeriod?.main ?? d.spendingByCategory,
              subs: homePeriod?.subs ?? d.spendingBySub,
              total: homePeriod?.total ?? d.spending,
              range: d.range,
              emptyText: 'No spending in this period',
              tappable: homePeriod == null,
            ),
            const SizedBox(height: Sp.x4),
            const TitleBanner(),
            const LiveTitleChip(),
            const PlusScoreCard(),
            const SizedBox(height: Sp.x3),
            _PillarGrid(data: d),
            if (invest.isNotEmpty) ...[
              const SizedBox(height: Sp.x3),
              InvestHero(
                totals: ref.read(repoProvider).investTotals(invest),
                onTap: onOpenInvest,
              ),
            ],
            const SectionTitle('Insights'),
            const InsightsStrip(),
          ],
        ),
      ),
    );
  }
}

class _SmsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _SmsBanner({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.x3),
    child: Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        decoration: BoxDecoration(
          color: context.scheme.primaryContainer,
          borderRadius: BorderRadius.circular(Sp.rCard),
        ),
        child: Row(
          children: [
            Icon(Icons.sms_outlined, size: 20, color: context.scheme.primary),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Text(
                '$count detected transaction${count == 1 ? '' : 's'} to review',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );
}

class PeriodBar extends ConsumerWidget {
  const PeriodBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(periodProvider);
    final range = sel.resolve(ref.watch(repoProvider).now());
    final f = DateFormat('d MMM');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in PeriodPreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.x2),
                  child: ChoiceChip(
                    label: Text(PeriodSel.label(p)),
                    selected: sel.preset == p,
                    onSelected: (_) async {
                      haptic();
                      if (p == PeriodPreset.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: DateTimeRange(
                            start: range.start,
                            end: range.end,
                          ),
                        );
                        if (picked != null) {
                          ref
                              .read(periodProvider.notifier)
                              .custom(
                                DateRange(
                                  Dates.fromLocal(picked.start),
                                  Dates.fromLocal(picked.end),
                                ),
                              );
                        }
                      } else {
                        ref.read(periodProvider.notifier).select(p);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: Sp.x1, top: Sp.x1),
          child: Text(
            '${f.format(range.start)} – ${f.format(range.end)} ${range.end.year}',
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  final int total;
  final bool split;
  final List<double> trend;
  const _BalanceCard({
    required this.total,
    required this.split,
    this.trend = const [],
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final bal = ref.watch(balancesProvider).value ?? const {};
    final dark = Theme.of(context).brightness == Brightness.dark;
    const fg = Colors.white;
    final fgMuted = Colors.white.withValues(alpha: 0.88);
    final banks = accounts.where((a) => a.kind == 'bank').toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Sp.rCard + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B0A08), Color(0xFF22211C)]
              : const [Color(0xFF0E0D0B), Color(0xFF2A2822)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 18,
            top: 14,
            child: SizedBox(
              width: 100,
              height: 34,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, t, _) =>
                    CustomPaint(painter: _SparkPainter(trend, t)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x4, Sp.x5, Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL BALANCE',
                  style: context.text.labelSmall?.copyWith(
                    color: fgMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Sp.x2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(total),
                    style: context.text.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                      letterSpacing: -1.4,
                      color: fg,
                      fontFeatures: moneyFeatures,
                    ),
                  ),
                ),
                if (split && accounts.isNotEmpty) ...[
                  const SizedBox(height: Sp.x3),
                  Wrap(
                    spacing: Sp.x2,
                    runSpacing: Sp.x2,
                    children: [
                      if (banks.length > 1)
                        _chip(
                          'Online  ${Money.format(banks.fold<int>(0, (t, a) => t + (bal[a.id] ?? 0)))}',
                          strong: true,
                          dark: true,
                        ),
                      for (final a in accounts)
                        _chip(
                          '${a.name}  ${Money.format(bal[a.id] ?? 0)}',
                          dark: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _chip(String text, {bool strong = false, bool dark = true}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  decoration: BoxDecoration(
    color: (dark ? Colors.white : const Color(0xFF3B4BD8)).withValues(
      alpha: strong ? 0.2 : 0.1,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: dark ? Colors.white : const Color(0xFF14172B),
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
    ),
  ),
);

class PillarCard extends StatelessWidget {
  final Pillar pillar;
  final DashboardData data;
  const PillarCard({super.key, required this.pillar, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final (title, amount, color, icon, prev) = switch (pillar) {
      Pillar.spending => (
        tr('Total Spending'),
        data.spending,
        c.spending,
        Icons.south_east,
        data.prevSpending,
      ),
      Pillar.income => (
        tr('Total Income'),
        data.income,
        c.income,
        Icons.north_east,
        data.prevIncome,
      ),
      Pillar.incoming => (
        'Money to receive',
        data.incomingDebts,
        c.debtIn,
        Icons.call_received,
        null,
      ),
      Pillar.liabilities => (
        tr('Liabilities'),
        data.liabilities,
        c.liability,
        Icons.call_made,
        null,
      ),
    };
    final series = switch (pillar) {
      Pillar.spending => data.dailySpending,
      Pillar.income => data.dailyIncome,
      _ => const <String, int>{},
    };
    final lightMode = Theme.of(context).brightness == Brightness.light;
    final goodC = lightMode ? const Color(0xFF066B49) : c.income;
    final badC = lightMode ? const Color(0xFFB0123A) : c.spending;
    String? delta;
    var good = true;
    var up = true;
    if (prev != null && prev > 0) {
      final pct = ((amount - prev) / prev * 100).round();
      delta = '${pct >= 0 ? '+' : '−'}${pct.abs()}% vs prev';
      up = pct >= 0;
      good = pillar == Pillar.spending ? pct <= 0 : pct >= 0;
    } else if (prev != null && amount > 0) {
      delta = 'new this period';
    }
    return Semantics(
      button: true,
      label:
          '$title ${Money.format(amount)}${delta != null ? ', $delta' : ''}. Tap for details.',
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.rCard),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(Sp.rCard),
          onTap: () {
            haptic();
            pushReveal(context, PillarDetailPage(pillar: pillar));
          },
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.labelLarge?.copyWith(
                          color: c.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    amount,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                if (delta != null)
                  Row(
                    children: [
                      if (delta != 'new this period')
                        Icon(
                          up ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: good ? goodC : badC,
                        ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          delta,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: good ? goodC : badC,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (pillar == Pillar.incoming ||
                    pillar == Pillar.liabilities)
                  Text(
                    'Interest ${Money.compact(pillar == Pillar.incoming ? data.incomingInterest : data.liabilityInterest)}',
                    style: context.text.labelSmall?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                const SizedBox(height: Sp.x2),
                SizedBox(
                  height: 28,
                  child: Sparkline(
                    values: series,
                    color: color,
                    range: data.range,
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

class Sparkline extends StatelessWidget {
  final Map<String, int> values;
  final Color color;
  final DateRange range;
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    required this.range,
  });
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Container(
        alignment: Alignment.bottomLeft,
        child: Container(height: 2, color: color.withValues(alpha: 0.2)),
      );
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < range.days; i++) {
      final d = Dates.str(range.start.add(Duration(days: i)));
      spots.add(FlSpot(i.toDouble(), (values[d] ?? 0) / Money.unit));
    }
    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Shown = ({String name, int minor, Color color, CatSlice? slice});

class CategoryDonut extends StatelessWidget {
  final List<CatSlice> slices;
  final int total;
  final String emptyText;

  /// Tapping a row opens that category's page (null = rows are not tappable).
  final void Function(CatSlice slice)? onTapSlice;

  /// Category budgets (by category id or name). A row with one shows its
  /// progress against that budget instead of its share of the total.
  final Map<String, int> limits;
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.total,
    required this.emptyText,
    this.onTapSlice,
    this.limits = const {},
  });

  int? _limitOf(_Shown s) {
    final sl = s.slice;
    if (sl == null) return null;
    final l = limits[sl.categoryId] ?? limits[sl.name];
    return l == null || l <= 0 ? null : l;
  }

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty || total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x6),
          child: Center(
            child: Text(
              emptyText,
              style: TextStyle(color: context.cash.textMuted),
            ),
          ),
        ),
      );
    }
    // top slices get their own colour; the long tail is grouped as "Others"
    final top = slices.take(ChartColors.count).toList();
    final rest = slices
        .skip(ChartColors.count)
        .fold<int>(0, (a, s) => a + s.totalMinor);
    final brightness = Theme.of(context).brightness;
    final shown = <_Shown>[
      for (var i = 0; i < top.length; i++)
        (
          name: top[i].name,
          minor: top[i].totalMinor,
          color: ChartColors.at(i, brightness),
          slice: top[i],
        ),
      if (rest > 0)
        (
          name: 'Others',
          minor: rest,
          color: ChartColors.at(0, brightness, others: true),
          slice: null,
        ),
    ];
    final summary = shown
        .take(5)
        .map((s) => '${s.name} ${Money.format(s.minor)}')
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x4),
        child: Column(
          children: [
            Semantics(
              label: 'Breakdown by category: $summary',
              child: SizedBox(
                height: 200,
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 64,
                          startDegreeOffset: -90,
                          sections: [
                            for (final s in shown)
                              PieChartSectionData(
                                value: s.minor.toDouble(),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [ChartColors.soft(s.color), s.color],
                                ),
                                radius: 30,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: context.text.labelMedium?.copyWith(
                              color: context.cash.textMuted,
                            ),
                          ),
                          MoneyText(
                            total,
                            compact: true,
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            for (final (i, s) in shown.indexed)
              Reveal(
                index: i,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      s.slice == null ||
                          onTapSlice == null ||
                          s.slice!.categoryId == '_none'
                      ? null
                      : () {
                          haptic();
                          onTapSlice!(s.slice!);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Sp.x2,
                      horizontal: 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                s.color.withValues(alpha: 0.28),
                                s.color.withValues(alpha: 0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: s.color.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            s.slice == null
                                ? '🧺'
                                : (s.slice!.categoryId == '_none'
                                      ? '🏷️'
                                      : emojiForCategory(
                                          s.slice!.name,
                                          s.slice!.parentName,
                                        )),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (s.slice?.parentName != null)
                                Text(
                                  s.slice!.parentName!,
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.cash.textMuted,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    end: _limitOf(s) == null
                                        ? s.minor / total
                                        : (s.minor / _limitOf(s)!)
                                              .clamp(0, 1)
                                              .toDouble(),
                                  ),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, _) => LinearProgressIndicator(
                                    value: v,
                                    minHeight: 5,
                                    color:
                                        _limitOf(s) != null &&
                                            s.minor > _limitOf(s)!
                                        ? context.cash.spending
                                        : s.color,
                                    backgroundColor: s.color.withValues(
                                      alpha: 0.14,
                                    ),
                                  ),
                                ),
                              ),
                              if (_limitOf(s) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    s.minor > _limitOf(s)!
                                        ? '${Money.format(s.minor - _limitOf(s)!)} ${tr('over budget')}'
                                        : '${(s.minor * 100 / _limitOf(s)!).round()}% ${tr('of')} ${Money.format(_limitOf(s)!)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelSmall?.copyWith(
                                      color: s.minor > _limitOf(s)!
                                          ? context.cash.spending
                                          : context.cash.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Sp.x3),
                        // big amounts and large text shrink instead of
                        // pushing the row off the screen
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                MoneyText(
                                  s.minor,
                                  style: context.text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${(s.minor * 100 / total).round()}%',
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.cash.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (s.slice != null &&
                            onTapSlice != null &&
                            s.slice!.categoryId != '_none')
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.cash.textMuted,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DailyBars extends StatelessWidget {
  final Map<String, int> values;
  final DateRange range;
  final Color color;
  const DailyBars({
    super.key,
    required this.values,
    required this.range,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    // Group into at most ~16 bars (days, or weeks for long ranges).
    final step = (range.days / 16).ceil().clamp(1, 366);
    final groups = <BarChartGroupData>[];
    var maxV = 1;
    for (var g = 0, i = 0; i < range.days; g++, i += step) {
      var sum = 0;
      for (var k = i; k < i + step && k < range.days; k++) {
        sum += values[Dates.str(range.start.add(Duration(days: k)))] ?? 0;
      }
      if (sum > maxV) maxV = sum;
      groups.add(
        BarChartGroupData(
          x: g,
          barRods: [
            BarChartRodData(
              toY: sum / Money.unit,
              color: color,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    final total = values.values.fold<int>(0, (a, b) => a + b);
    return Semantics(
      label:
          'Trend chart. Total ${Money.format(total)} over ${range.days} days. Peak ${Money.format(maxV)} in one ${step == 1 ? 'day' : '$step-day group'}.',
      child: SizedBox(
        height: 160,
        child: ExcludeSemantics(
          child: BarChart(
            BarChartData(
              barGroups: groups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    Money.format(Money.fromMajor(rod.toY)),
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PillarDetailPage extends ConsumerWidget {
  final Pillar pillar;
  const PillarDetailPage({super.key, required this.pillar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dashboardProvider);
    final title = switch (pillar) {
      Pillar.spending => tr('Total Spending'),
      Pillar.income => tr('Total Income'),
      Pillar.incoming => 'Money to receive',
      Pillar.liabilities => tr('Liabilities'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: d.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (x) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
          children: [
            const PeriodBar(),
            const SizedBox(height: Sp.x4),
            ...switch (pillar) {
              Pillar.spending => _flow(context, x, spending: true),
              Pillar.income => _flow(context, x, spending: false),
              Pillar.incoming => _debt(context, x, incoming: true),
              Pillar.liabilities => _debt(context, x, incoming: false),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _flow(
    BuildContext context,
    DashboardData x, {
    required bool spending,
  }) {
    final color = spending ? context.cash.spending : context.cash.income;
    final total = spending ? x.spending : x.income;
    final slices = spending ? x.spendingByCategory : x.incomeByCategory;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyText(
                total,
                color: color,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${x.range.days} days · previous period ${Money.format(spending ? x.prevSpending : x.prevIncome)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
              const SizedBox(height: Sp.x4),
              DailyBars(
                values: spending ? x.dailySpending : x.dailyIncome,
                range: x.range,
                color: color,
              ),
            ],
          ),
        ),
      ),
      SectionTitle(spending ? 'By category' : 'By source'),
      if (spending)
        MoneyWent(
          main: slices,
          subs: x.spendingBySub,
          total: total,
          range: x.range,
          emptyText: 'Nothing recorded in this period',
        )
      else
        CategoryDonut(
          slices: slices,
          total: total,
          emptyText: 'Nothing recorded in this period',
        ),
      if (spending) ...[
        if (x.cashSpending + x.onlineSpending > 0) ...[
          const SectionTitle('Cash vs online'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: _SplitBar(
                parts: [
                  ('Cash', x.cashSpending, context.cash.income),
                  ('Online', x.onlineSpending, context.scheme.primary),
                ],
              ),
            ),
          ),
        ],
        if (x.spendingByAccount.length > 1) ...[
          const SectionTitle('By account'),
          Card(
            child: Column(
              children: [
                for (final e in x.spendingByAccount)
                  ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: TrailingMoney(
                      e.value,
                      style: context.text.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
      SectionTitle(
        'Transactions',
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
            softRoute(
              TransactionsPage(
                standalone: true,
                initial: TxnFilter(
                  type: spending ? 'debit' : 'credit',
                  range: x.range,
                ),
              ),
            ),
          ),
          child: Text(tr('View all')),
        ),
      ),
    ];
  }

  List<Widget> _debt(
    BuildContext context,
    DashboardData x, {
    required bool incoming,
  }) {
    final color = incoming ? context.cash.debtIn : context.cash.liability;
    final total = incoming ? x.incomingDebts : x.liabilities;
    final principal = incoming ? x.incomingPrincipal : x.liabilityPrincipal;
    final interest = incoming ? x.incomingInterest : x.liabilityInterest;
    final list = incoming ? x.receivables : x.liabilityList;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyText(
                total,
                color: color,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Outstanding as of ${DateFormat('d MMM y').format(x.range.end.isAfter(Dates.today()) ? Dates.today() : x.range.end)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
              const SizedBox(height: Sp.x4),
              _SplitBar(
                parts: [
                  ('Principal', principal, color),
                  ('Interest', interest, color.withValues(alpha: 0.45)),
                ],
              ),
            ],
          ),
        ),
      ),
      SectionTitle(incoming ? 'Who owes you' : 'Who you owe'),
      if (list.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x6),
            child: Center(
              child: Text(
                'Nothing outstanding',
                style: TextStyle(color: context.cash.textMuted),
              ),
            ),
          ),
        )
      else
        Card(
          child: Column(
            children: [
              for (final s in list)
                ListTile(
                  title: Text(s.debt.counterparty),
                  subtitle: LinearProgressIndicator(
                    value: s.debt.principalMinor == 0
                        ? 0
                        : (s.state.totalPaid /
                                  (s.debt.principalMinor +
                                      s.state.totalAccrued))
                              .clamp(0, 1)
                              .toDouble(),
                    color: color,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  trailing: TrailingMoney(
                    s.state.outstanding,
                    style: context.text.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}

class _SplitBar extends StatelessWidget {
  final List<(String, int, Color)> parts;
  const _SplitBar({required this.parts});
  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return Column(
      children: [
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final p in parts)
                    if (p.$2 > 0)
                      Expanded(
                        flex: p.$2,
                        child: Container(color: p.$3),
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Sp.x3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final p in parts)
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: p.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Sp.x2),
                  Text('${p.$1} '),
                  MoneyText(p.$2, style: context.text.bodyMedium),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Running net (income minus spending) over the period, for the hero sparkline.
List<double> _trend(DashboardData d) {
  final days = {...d.dailyIncome.keys, ...d.dailySpending.keys}.toList()
    ..sort();
  var run = 0.0;
  final out = <double>[];
  for (final k in days) {
    run += (d.dailyIncome[k] ?? 0) - (d.dailySpending[k] ?? 0);
    out.add(run);
  }
  return out;
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final double t;
  _SparkPainter(this.v, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final pts = v.length >= 2 ? v : const [0.0, 0.3, 0.2, 0.6, 0.5, 1.0];
    final lo = pts.reduce((a, b) => a < b ? a : b);
    final hi = pts.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height - ((pts[i] - lo) / span) * size.height * 0.85 - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = size.width * (i - 1) / (pts.length - 1);
        final py =
            size.height - ((pts[i - 1] - lo) / span) * size.height * 0.85 - 4;
        path.cubicTo((px + x) / 2, py, (px + x) / 2, y, x, y);
      }
    }
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.t != t || o.v != v;
}

/// Spending and Income always show; Incoming Debts and Liabilities only when
/// there is something in them. An odd last tile takes the full width.
class _PillarGrid extends StatelessWidget {
  final DashboardData data;
  const _PillarGrid({required this.data});
  @override
  Widget build(BuildContext context) {
    final pillars = [
      Pillar.spending,
      Pillar.income,
      if (data.incomingDebts > 0) Pillar.incoming,
      if (data.liabilities > 0) Pillar.liabilities,
    ];
    final h =
        68 + 92 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);
    final rows = <Widget>[];
    for (var i = 0; i < pillars.length; i += 2) {
      final pair = pillars.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : Sp.x3),
          child: SizedBox(
            height: h,
            child: Row(
              children: [
                for (var k = 0; k < pair.length; k++) ...[
                  if (k > 0) const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Reveal(
                      index: i + k + 1,
                      child: PillarCard(pillar: pair[k], data: data),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(children: rows),
    );
  }
}

/// "Where your money went": main categories or sub-categories, tap any row
/// for that category's full analysis.
class MoneyWent extends ConsumerStatefulWidget {
  final List<CatSlice> main, subs;
  final int total;
  final DateRange range;
  final String emptyText;

  /// Whether a slice opens its detail page (only my own entries have one).
  final bool tappable;
  const MoneyWent({
    super.key,
    this.tappable = true,
    required this.main,
    required this.subs,
    required this.total,
    required this.range,
    required this.emptyText,
  });
  @override
  ConsumerState<MoneyWent> createState() => _MoneyWentState();
}

class _MoneyWentState extends ConsumerState<MoneyWent> {
  bool _sub = false;
  @override
  Widget build(BuildContext context) {
    // category budgets, shown as progress on each row (this month only)
    final b = ref.watch(budgetStatusProvider).value;
    final limits = <String, int>{
      for (final r in b?.splits ?? const <SplitRow>[])
        if (!r.isElse && r.allocated > 0) ...{
          r.id: r.allocated,
          r.name: r.allocated,
        },
    };
    final hasSubs = widget.subs.any((s) => s.parentName != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSubs && widget.total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(tr('Main categories'))),
                ButtonSegment(value: true, label: Text(tr('Sub-categories'))),
              ],
              selected: {_sub},
              onSelectionChanged: (v) {
                haptic();
                setState(() => _sub = v.first);
              },
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: CategoryDonut(
            key: ValueKey(_sub),
            slices: _sub ? widget.subs : widget.main,
            total: widget.total,
            emptyText: widget.emptyText,
            limits: _sub ? const {} : limits,
            onTapSlice: (s) {
              if (!widget.tappable) return;
              pushReveal(
                context,
                CategoryInsightPage(
                  categoryId: s.categoryId,
                  range: widget.range,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

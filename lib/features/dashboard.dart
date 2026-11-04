import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'transactions.dart';

enum Pillar { spending, income, incoming, liabilities }

class DashboardPage extends ConsumerWidget {
  final VoidCallback onOpenInbox;
  const DashboardPage({super.key, required this.onOpenInbox});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider).value;
    final pending = ref.watch(pendingSmsProvider).value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Buddy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: data.when(
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
            _BalanceCard(
              total: d.totalBalance,
              split: settings?.split ?? false,
            ),
            const SizedBox(height: Sp.x3),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Sp.x3,
                crossAxisSpacing: Sp.x3,
                // Height grows with the user's text size so nothing clips.
                mainAxisExtent:
                    78 +
                    96 *
                        MediaQuery.textScalerOf(context)
                            .scale(1)
                            .clamp(1.0, 2.2),
              ),
              children: [
                PillarCard(pillar: Pillar.spending, data: d),
                PillarCard(pillar: Pillar.income, data: d),
                PillarCard(pillar: Pillar.incoming, data: d),
                PillarCard(pillar: Pillar.liabilities, data: d),
              ],
            ),
            const SectionTitle('Where your money went'),
            CategoryDonut(
              slices: d.spendingByCategory,
              total: d.spending,
              emptyText: 'No spending in this period',
            ),
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
    child: Card(
      color: context.scheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.sms_outlined),
        title: Text(
          '$count detected transaction${count == 1 ? '' : 's'} to review',
        ),
        subtitle: const Text('Confirm or discard with one tap'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
  const _BalanceCard({required this.total, required this.split});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final bal = ref.watch(balancesProvider).value ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total balance',
              style: context.text.labelLarge?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
            const SizedBox(height: Sp.x1),
            TweenAnimationBuilder<double>(
              tween: Tween(end: total.toDouble()),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => MoneyText(
                v.round(),
                style: context.text.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (split && accounts.isNotEmpty) ...[
              const SizedBox(height: Sp.x3),
              Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  for (final a in accounts)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: colorOf(a.colorValue),
                        radius: 6,
                      ),
                      label: Text('${a.name}  ${Money.format(bal[a.id] ?? 0)}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PillarCard extends StatelessWidget {
  final Pillar pillar;
  final DashboardData data;
  const PillarCard({super.key, required this.pillar, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final (title, amount, color, icon, prev) = switch (pillar) {
      Pillar.spending => (
        'Total Spending',
        data.spending,
        c.spending,
        Icons.south_east,
        data.prevSpending,
      ),
      Pillar.income => (
        'Total Income',
        data.income,
        c.income,
        Icons.north_east,
        data.prevIncome,
      ),
      Pillar.incoming => (
        'Incoming Debts',
        data.incomingDebts,
        c.debtIn,
        Icons.call_received,
        null,
      ),
      Pillar.liabilities => (
        'Liabilities',
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
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Sp.rCard),
          onTap: () {
            haptic();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PillarDetailPage(pillar: pillar),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withValues(alpha: 0.14),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.labelLarge,
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
                    color: color,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (delta != null)
                  Row(
                    children: [
                      if (delta != 'new this period')
                        Icon(
                          up ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: good ? c.income : c.spending,
                        ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          delta,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: good ? c.income : c.spending,
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
      spots.add(FlSpot(i.toDouble(), (values[d] ?? 0) / 100));
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

class CategoryDonut extends StatelessWidget {
  final List<CatSlice> slices;
  final int total;
  final String emptyText;
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.total,
    required this.emptyText,
  });

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
    final summary = slices
        .take(5)
        .map((s) => '${s.name} ${Money.format(s.totalMinor)}')
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x4),
        child: Column(
          children: [
            Semantics(
              label: 'Breakdown by category: $summary',
              child: SizedBox(
                height: 180,
                child: ExcludeSemantics(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 56,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.totalMinor.toDouble(),
                            color: colorOf(s.colorValue),
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            for (final s in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x1 + 1),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorOf(s.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${(s.totalMinor * 100 / total).round()}%',
                      style: TextStyle(color: context.cash.textMuted),
                    ),
                    const SizedBox(width: Sp.x3),
                    MoneyText(s.totalMinor, style: context.text.bodyMedium),
                  ],
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
              toY: sum / 100,
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
                    Money.format((rod.toY * 100).round()),
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
      Pillar.spending => 'Total Spending',
      Pillar.income => 'Total Income',
      Pillar.incoming => 'Incoming Debts',
      Pillar.liabilities => 'Liabilities',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: d.when(
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
      CategoryDonut(
        slices: slices,
        total: total,
        emptyText: 'Nothing recorded in this period',
      ),
      if (spending) ...[
        if (x.cashSpending + x.cardSpending > 0) ...[
          const SectionTitle('Cash vs card'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: _SplitBar(
                parts: [
                  ('Cash', x.cashSpending, context.cash.income),
                  ('Card', x.cardSpending, context.scheme.primary),
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
            MaterialPageRoute(
              builder: (_) => TransactionsPage(
                standalone: true,
                initial: TxnFilter(
                  type: spending ? 'debit' : 'credit',
                  range: x.range,
                ),
              ),
            ),
          ),
          child: const Text('View all'),
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

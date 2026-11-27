import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repo.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'budget.dart';
import 'group.dart';

/// "This month": what was mine, what I put into the home, and both budgets.
class HomeMonthCard extends ConsumerWidget {
  final HomeSummary s;
  const HomeMonthCard(this.s, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetStatusProvider).value;
    final muted = TextStyle(color: context.cash.textMuted);
    Widget line(String label, int value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(tr(label))),
          const SizedBox(width: Sp.x3),
          MoneyText(
            value,
            style: context.text.titleMedium?.copyWith(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    Widget limit(String label, int spent, int? of, VoidCallback onTap) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: of == null || of == 0
                ? Text(
                    '${tr('Set')} ${tr(label).toLowerCase()} ›',
                    style: muted,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${tr(label)} ${Money.format(of)} · '
                        '${Money.format((of - spent).abs())} '
                        '${tr(spent <= of ? 'left' : 'over')}',
                        style: muted,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (spent / of).clamp(0, 1).toDouble(),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: spent <= of
                            ? context.cash.income
                            : context.cash.spending,
                      ),
                    ],
                  ),
          ),
        );
    final people = [
      for (final p in s.byPerson.entries)
        '${p.key == s.me ? tr('You') : s.names[p.key] ?? tr('Partner')} '
            '${Money.format(p.value)}',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('This month'), style: muted),
            line('My own spending', s.mine, strong: true),
            limit(
              'My budget',
              budget?.spent ?? 0,
              budget?.budget,
              () => pushReveal(context, const BudgetPage()),
            ),
            const Divider(),
            line('I paid for home', s.iPaidHome),
            line('I paid in total', s.iPaidInTotal),
            const Divider(),
            line('Total home spending', s.homeTotal, strong: true),
            Text(people, style: muted),
            limit(
              'Home budget',
              s.homeTotal,
              s.homeBudget,
              () => _setHomeBudget(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setHomeBudget(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(
      text: s.homeBudget == null ? '' : Money.edit(s.homeBudget!),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Home budget for each month')),
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

/// The one small invitation, until it is closed or home sharing is set up.
class HomeInviteCard extends ConsumerWidget {
  const HomeInviteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(groupServiceProvider) == null) return const SizedBox.shrink();
    ref.watch(changesProvider);
    final repo = ref.watch(repoProvider);
    return FutureBuilder<bool>(
      future: () async {
        return await repo.homeMember() == null &&
            await repo.getSetting('homeCardClosed') != '1';
      }(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.x3),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Run a home together?'),
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Close'),
                        icon: const Icon(Icons.close),
                        onPressed: () => repo.setSetting('homeCardClosed', '1'),
                      ),
                    ],
                  ),
                  Text(
                    tr(
                      'Track house spending with your partner. Your own money stays private.',
                    ),
                  ),
                  const SizedBox(height: Sp.x3),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GroupPage()),
                    ),
                    child: Text(tr('Set it up')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

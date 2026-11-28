import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/budget_repo.dart';
import '../data/db.dart';
import '../data/home_repo.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/theme.dart';
import 'group.dart';

/// The family budget: one amount for the month, and optionally an amount per
/// category. Both partners see and change the same figures.
class HomeBudgetPage extends ConsumerStatefulWidget {
  /// Shown inside the Home / Personal tabs, which have their own top bar.
  final bool embedded;
  const HomeBudgetPage({super.key, this.embedded = false});
  @override
  ConsumerState<HomeBudgetPage> createState() => _HomeBudgetPageState();
}

class _HomeBudgetPageState extends ConsumerState<HomeBudgetPage> {
  final _total = TextEditingController();
  final _amounts = <String, TextEditingController>{};
  List<Category>? _categories;
  Map<String, int> _spent = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final home = await repo.homeSummary(DateRange.thisMonth(repo.now()));
    final cats = [
      for (final c in await repo.categories(kind: 'debit'))
        if (c.parentId == null) c,
    ];
    var splits = home?.splits ?? const <String, int>{};
    var total = home?.budget;
    // Nothing set yet: start from my own budget.
    if (total == null && splits.isEmpty) {
      final mine = await repo.budgetStatus(repo.today.year, repo.today.month);
      total = mine?.budget;
      final byId = await repo.budgetSplits();
      splits = {
        for (final c in cats)
          if (byId[c.id] != null) c.name: byId[c.id]!,
      };
    }
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _spent = {for (final s in home?.main ?? const []) s.name: s.totalMinor};
      _total.text = total == null || total == 0 ? '' : Money.edit(total);
      for (final c in cats) {
        _amounts[c.name] = TextEditingController(
          text: splits[c.name] == null ? '' : Money.edit(splits[c.name]!),
        );
      }
    });
  }

  Map<String, int> get _splits => {
    for (final e in _amounts.entries)
      if ((Money.parse(e.value.text) ?? 0) > 0)
        e.key: Money.parse(e.value.text)!,
  };

  Future<void> _save() async {
    final splits = _splits;
    final typed = Money.parse(_total.text) ?? 0;
    // Only category amounts: the month's budget is their sum.
    final total = typed > 0
        ? typed
        : splits.values.fold<int>(0, (a, b) => a + b);
    await ref
        .read(groupServiceProvider)
        ?.change(
          (g) => g.put('budget', {
            'kind': 'budget',
            'limitMinor': total,
            'splits': splits,
          }),
        );
    ref.invalidate(homeMonthProvider);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label, {Key? key}) => TextField(
    key: key,
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(Money.inputPattern)],
    decoration: InputDecoration(
      labelText: label,
      prefixText: '${Money.symbol} ',
      isDense: true,
    ),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    final planned = _splits.values.fold<int>(0, (a, b) => a + b);
    final total = Money.parse(_total.text) ?? 0;
    final muted = TextStyle(color: context.cash.textMuted);
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(tr('Family budget'))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: FilledButton(
            onPressed: cats == null ? null : _save,
            child: Text(tr('Save')),
          ),
        ),
      ),
      body: cats == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(Sp.x4),
              children: [
                _field(
                  _total,
                  tr('For the whole month'),
                  key: const ValueKey('family-total'),
                ),
                if (planned > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.x2),
                    child: Text(
                      '${tr('Set aside in categories')}: ${Money.format(planned)}'
                      '${total > 0 && planned > total ? ' · ${tr('more than the month')}' : ''}',
                      style: total > 0 && planned > total
                          ? TextStyle(color: context.cash.spending)
                          : muted,
                    ),
                  ),
                const SizedBox(height: Sp.x4),
                for (final c in cats) _category(context, c),
              ],
            ),
    );
  }

  Widget _category(BuildContext context, Category c) {
    final spent = _spent[c.name] ?? 0;
    final limit = Money.parse(_amounts[c.name]!.text) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Sp.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    emojiForCategory(c.name, null),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: context.text.titleSmall),
                        if (spent > 0)
                          Text(
                            '${tr('Spent')} ${Money.format(spent)}',
                            style: context.text.bodySmall?.copyWith(
                              color: context.cash.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: _field(
                      _amounts[c.name]!,
                      tr('Budget'),
                      key: ValueKey('family-${c.name}'),
                    ),
                  ),
                ],
              ),
              if (limit > 0) ...[
                const SizedBox(height: Sp.x2),
                LinearProgressIndicator(
                  value: (spent / limit).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: spent > limit
                      ? context.cash.spending
                      : context.cash.income,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

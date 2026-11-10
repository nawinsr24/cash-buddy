import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../data/budget_repo.dart';
import '../data/insights_repo.dart';
import '../data/db.dart' show Category;
import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<void> showBudgetSheet(BuildContext context) => showSheet(
  context,
  (_) => BudgetEditor(onSaved: () => Navigator.pop(context)),
);

/// Set the monthly budget as one amount, or split by category (the total adds
/// up by itself). Used from the Budget screen and from first-run setup.
class BudgetEditor extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback? onSkip;
  const BudgetEditor({super.key, required this.onSaved, this.onSkip});
  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  final overall = TextEditingController();
  final Map<String, TextEditingController> rows = {};
  List<Category> cats = [];
  String mode = 'overall';
  bool monthOnly = false, loaded = false, hasExisting = false;
  int income = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    overall.dispose();
    for (final c in rows.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final now = repo.today;
    final key = monthKey(now.year, now.month);
    final all = await repo.categories(kind: 'debit');
    cats = all.where((c) => c.parentId == null).toList();
    for (final c in cats) {
      rows[c.id] = TextEditingController();
    }
    mode = await repo.budgetMode();
    final st = await repo.budgetStatus(now.year, now.month);
    hasExisting = st != null;
    if (st != null) {
      monthOnly = st.monthOnly;
      overall.text = Money.edit(st.budget, trimZeros: true);
    }
    final splits = await repo.budgetSplits(month: key);
    splits.forEach((id, v) {
      rows[id]?.text = Money.edit(v, trimZeros: true);
    });
    final prev = Dates.addMonths(Dates.day(now.year, now.month, 1), -1);
    final last = await repo.monthStats(prev.year, prev.month);
    final cur = await repo.monthStats(now.year, now.month);
    income = last.income > 0 ? last.income : cur.income;
    if (income <= 0) {
      income = int.tryParse(await repo.getSetting('expectedIncome') ?? '') ?? 0;
    }
    if (mounted) setState(() => loaded = true);
  }

  int get _sum => rows.values.fold<int>(
    0,
    (a, c) => a + (Money.parse(c.text.trim().isEmpty ? '0' : c.text) ?? 0),
  );

  int get _total =>
      mode == 'category' ? _sum : (Money.parse(overall.text) ?? 0);

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    final now = repo.today;
    try {
      if (mode == 'category') {
        final map = {
          for (final e in rows.entries)
            e.key:
                Money.parse(e.value.text.trim().isEmpty ? '0' : e.value.text) ??
                0,
        };
        await repo.saveCategoryBudget(map, month: monthOnly ? now : null);
      } else {
        final m = Money.parse(overall.text);
        if (m == null || m <= 0) {
          setState(() => error = 'Enter an amount above zero');
          return;
        }
        await repo.setBudgetMode('overall');
        await repo.setBudget(m, month: monthOnly ? now : null);
      }
      widget.onSaved();
    } on ValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final c = context.cash;
    final month = DateFormat('MMMM').format(ref.read(repoProvider).today);
    final total = _total;
    final free = income - total;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Monthly budget'), style: context.text.titleMedium),
            const SizedBox(height: Sp.x2),
            Text(
              Money.format(total),
              style: context.text.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                fontFeatures: moneyFeatures,
              ),
            ),
            Text(tr('per month'), style: TextStyle(color: c.textMuted)),
            const SizedBox(height: Sp.x4),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'overall', label: Text(tr('Overall'))),
                ButtonSegment(
                  value: 'category',
                  label: Text(tr('By category')),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (v) => setState(() {
                mode = v.first;
                error = null;
              }),
            ),
            const SizedBox(height: Sp.x4),
            if (mode == 'overall')
              TextField(
                controller: overall,
                autofocus: !hasExisting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(Money.inputPattern),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: tr('Total for the month'),
                  prefixText: '${Money.symbol} ',
                ),
              )
            else ...[
              for (final cat in cats) _row(cat),
            ],
            if (income > 0 && total > 0 && free > 0)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x2),
                child: Text(
                  '${Money.format(free)} of your income is not budgeted.',
                  style: context.text.bodySmall?.copyWith(color: c.textMuted),
                ),
              ),
            const SizedBox(height: Sp.x4),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(tr('Every month'))),
                ButtonSegment(value: true, label: Text('Only $month')),
              ],
              selected: {monthOnly},
              onSelectionChanged: (v) => setState(() => monthOnly = v.first),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x2),
                child: Text(error!, style: TextStyle(color: c.spending)),
              ),
            const SizedBox(height: Sp.x4),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _save,
              child: Text(tr('Save budget')),
            ),
            if (widget.onSkip != null)
              TextButton(
                onPressed: widget.onSkip,
                child: Text(tr('Skip for now')),
              )
            else if (hasExisting)
              TextButton(
                onPressed: () async {
                  final repo = ref.read(repoProvider);
                  await repo.setBudget(null);
                  await repo.setBudget(null, month: repo.today);
                  for (final id in (await repo.budgetSplits()).keys) {
                    await repo.setBudgetSplit(id, null);
                  }
                  widget.onSaved();
                },
                child: Text(tr('Remove budget')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(Category cat) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(emojiForCategory(cat.name), style: const TextStyle(fontSize: 20)),
        const SizedBox(width: Sp.x3),
        Expanded(child: Text(cat.name, overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 120,
          child: TextField(
            controller: rows[cat.id],
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(Money.inputPattern),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '${Money.symbol} ',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '0',
            ),
          ),
        ),
      ],
    ),
  );
}

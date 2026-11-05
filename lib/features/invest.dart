import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/invest_repo.dart';
import '../data/repo.dart' show ValidationException;
import '../domain/schedule.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/art.dart';
import '../ui/emoji.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Color kindColor(String kind) => switch (kind) {
  'mutual_fund' => const Color(0xFF8B5CF6),
  'stock' => const Color(0xFF22B573),
  'custom' => const Color(0xFFFF8A3D),
  _ => const Color(0xFF2F6BFF),
};

String _pct(double v) =>
    '${v >= 0 ? '+' : '−'}${(v.abs() * 100).toStringAsFixed(1)}%';

/// Gradient summary used on the Invest tab and the dashboard.
class InvestHero extends StatelessWidget {
  final InvestTotals totals;
  final VoidCallback? onTap;
  const InvestHero({super.key, required this.totals, this.onTap});
  @override
  Widget build(BuildContext context) {
    final up = totals.gain >= 0;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.x5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Sp.rCard + 4),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF191B22)
              : const Color(0xFF0F1115),
          border: Theme.of(context).brightness == Brightness.dark
              ? Border.all(color: const Color(0xFF2A2D36))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📈', style: TextStyle(fontSize: 18)),
                const SizedBox(width: Sp.x2),
                Text(
                  'Investments',
                  style: context.text.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUp(
                value: totals.currentValue,
                builder: (v) => MoneyText(
                  v,
                  color: Colors.white,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                _pill('Put in ${Money.format(totals.contributed)}'),
                _pill(
                  '${up ? '▲' : '▼'} ${Money.format(totals.gain.abs())}'
                  '${totals.pct != null ? ' (${_pct(totals.pct!)})' : ''}',
                  strong: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String t, {bool strong = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: strong ? 0.26 : 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
  );
}

class InvestPage extends ConsumerWidget {
  const InvestPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(investSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Invest')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pickInvestmentKind(context),
        icon: const Icon(Icons.add),
        label: const Text('Add investment'),
      ),
      body: list.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              art: Art.growth,
              icon: Icons.trending_up,
              title: 'Grow your money',
              body: 'Track mutual funds, stocks and anything else you put money into, once or on a schedule. Every field except the name is optional.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
                icon: const Icon(Icons.add),
                label: const Text('Add your first investment'),
                onPressed: () => pickInvestmentKind(context),
              ),
            );
          }
          final totals = ref.read(repoProvider).investTotals(items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, 110),
            children: [
              Reveal(child: InvestHero(totals: totals)),
              const SizedBox(height: Sp.x4),
              for (var i = 0; i < items.length; i++)
                Reveal(
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x3),
                    child: _InvestTile(items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InvestTile extends StatelessWidget {
  final InvestSummary s;
  const _InvestTile(this.s);
  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final color = kindColor(s.inv.kind);
    final up = s.gain >= 0;
    final pct = s.gainPct;
    return Pressable(
      onTap: () =>
          Navigator.of(context).push(softRoute(InvestDetailPage(id: s.inv.id))),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  emojiForInvestment(s.inv.kind),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.inv.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${investKindLabel(s.inv.kind)} · put in ${Money.format(s.contributed)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TrailingMoney(
                    s.currentValue,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (pct != null && !s.valueIsEstimate)
                    Text(
                      '${up ? '▲' : '▼'} ${_pct(pct)}',
                      style: context.text.labelSmall?.copyWith(
                        color: up ? c.income : c.spending,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First step of adding: pick what kind of investment.
Future<void> pickInvestmentKind(BuildContext context) => showSheet(context, (
  ctx,
) {
  Widget tile(String kind, String blurb) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.x3),
    child: Pressable(
      onTap: () {
        Navigator.pop(ctx);
        showInvestmentForm(context, kind: kind);
      },
      child: Container(
        padding: const EdgeInsets.all(Sp.x4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Sp.rCard),
          gradient: LinearGradient(
            colors: [
              kindColor(kind).withValues(alpha: 0.22),
              kindColor(kind).withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Row(
          children: [
            Text(
              emojiForInvestment(kind),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: Sp.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investKindLabel(kind),
                    style: ctx.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    blurb,
                    style: ctx.text.bodySmall?.copyWith(
                      color: ctx.cash.textMuted,
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
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you investing in?',
            style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Sp.x4),
          tile('mutual_fund', 'SIP or lump sum in a fund'),
          tile('stock', 'Shares you buy and hold'),
          tile('custom', 'Gold, chit, PPF, deposits: one time or recurring'),
        ],
      ),
    ),
  );
});

Future<void> showInvestmentForm(
  BuildContext context, {
  required String kind,
  Investment? edit,
}) => showSheet(context, (_) => _InvestForm(kind: kind, edit: edit));

class _InvestForm extends ConsumerStatefulWidget {
  final String kind;
  final Investment? edit;
  const _InvestForm({required this.kind, this.edit});
  @override
  ConsumerState<_InvestForm> createState() => _InvestFormState();
}

class _InvestFormState extends ConsumerState<_InvestForm> {
  Investment? get e => widget.edit;
  String get kind => widget.kind;
  bool get isCustom => kind == 'custom';

  String _m(int? v) => v == null ? '' : (v / 100).toStringAsFixed(2);
  late final name = TextEditingController(text: e?.name ?? '');
  late final growth = TextEditingController(
    text: e?.expectedGrowthBps == null
        ? ''
        : (e!.expectedGrowthBps! / 100).toString(),
  );
  late final value = TextEditingController(text: _m(e?.currentValueMinor));
  late final amount = TextEditingController(text: _m(e?.sipMinor));
  late final units = TextEditingController(text: e?.units?.toString() ?? '');
  late final buy = TextEditingController(text: _m(e?.buyPriceMinor));
  late final note = TextEditingController(text: e?.note ?? '');
  late final every = TextEditingController(text: '${e?.everyN ?? 1}');
  late final count = TextEditingController(
    text: e?.installments?.toString() ?? '',
  );

  late bool recurring = e?.recurring ?? false;
  late String cycle = e?.cycle ?? 'monthly';
  late DateTime? start = e?.startDate == null
      ? (isCustom ? Dates.today() : null)
      : Dates.parse(e!.startDate!);
  late int? weekday = e?.weekday;
  late int? monthDay = e?.monthDay;
  late String? timeOfDay = e?.timeOfDay;
  late String ends = e?.installments != null
      ? 'count'
      : (e?.endDate != null ? 'date' : 'never');
  late DateTime? endDate = e?.endDate == null ? null : Dates.parse(e!.endDate!);
  DateTime oneTimeDate = Dates.today();
  late String? accountId = e?.accountId;
  String? error;

  int? _money(TextEditingController c) =>
      c.text.trim().isEmpty ? null : Money.parse(c.text);
  double? _num(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  /// One-time custom investments keep the date they were created with.
  DateTime? get _keptStart => isCustom
      ? (e!.startDate == null ? null : Dates.parse(e!.startDate!))
      : start;

  /// The schedule as currently filled in (for the live preview and saving).
  Schedule? _schedule() {
    if (!(isCustom && recurring) || start == null) return null;
    return Schedule(
      cycle: cycle,
      every: int.tryParse(every.text.trim()) ?? 0,
      start: start!,
      weekday: cycle == 'weekly' ? (weekday ?? start!.weekday) : null,
      monthDay: cycle == 'monthly' ? (monthDay ?? start!.day) : null,
      count: ends == 'count' ? int.tryParse(count.text.trim()) ?? 0 : null,
      until: ends == 'date' ? endDate : null,
      timeOfDay: cycle == 'daily' ? timeOfDay : null,
    );
  }

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    final g = _num(growth);
    final bad = <String>[
      if (value.text.trim().isNotEmpty && _money(value) == null)
        'current value',
      if (amount.text.trim().isNotEmpty && _money(amount) == null) 'amount',
      if (buy.text.trim().isNotEmpty && _money(buy) == null) 'buy price',
      if (growth.text.trim().isNotEmpty && g == null) 'growth %',
      if (units.text.trim().isNotEmpty && _num(units) == null) 'units',
    ];
    if (bad.isNotEmpty) {
      setState(() => error = 'Check: ${bad.join(', ')}');
      return;
    }
    final sch = _schedule();
    if (isCustom && recurring) {
      if (ends == 'count' && (int.tryParse(count.text.trim()) ?? 0) < 1) {
        setState(() => error = 'Enter how many instalments');
        return;
      }
      if (ends == 'date' && endDate == null) {
        setState(() => error = 'Pick an end date');
        return;
      }
      final v = sch?.validate();
      if (v != null) {
        setState(() => error = v);
        return;
      }
    }
    final rec = isCustom && recurring;
    try {
      if (e == null) {
        final id = await repo.createInvestment(
          kind: kind,
          name: name.text,
          accountId: accountId,
          startDate: rec ? start : (isCustom ? oneTimeDate : start),
          expectedGrowthBps: g == null ? null : (g * 100).round(),
          currentValueMinor: _money(value),
          units: _num(units),
          buyPriceMinor: _money(buy),
          sipMinor: _money(amount),
          recurring: rec,
          cycle: rec ? cycle : null,
          everyN: rec ? sch!.every : 1,
          weekday: rec ? sch!.weekday : null,
          monthDay: rec ? sch!.monthDay : null,
          timeOfDay: rec ? timeOfDay : null,
          installments: rec ? sch!.count : null,
          endDate: rec ? sch!.until : null,
          note: note.text.trim(),
        );
        // A one-time custom investment with an amount is recorded right away.
        if (isCustom && !recurring && _money(amount) != null) {
          await repo.addInvestmentEntry(
            id,
            type: 'contribute',
            amountMinor: _money(amount)!,
            date: oneTimeDate,
          );
        }
      } else {
        await repo.updateInvestment(
          e!.id,
          name: name.text,
          accountId: accountId,
          startDate: rec ? start : _keptStart,
          expectedGrowthBps: g == null ? null : (g * 100).round(),
          currentValueMinor: _money(value),
          units: _num(units),
          buyPriceMinor: _money(buy),
          sipMinor: _money(amount),
          recurring: rec,
          cycle: rec ? cycle : null,
          everyN: rec ? sch!.every : 1,
          weekday: rec ? sch!.weekday : null,
          monthDay: rec ? sch!.monthDay : null,
          timeOfDay: rec ? timeOfDay : null,
          installments: rec ? sch!.count : null,
          endDate: rec ? sch!.until : null,
          note: note.text.trim(),
        );
      }
      haptic();
      if (mounted) Navigator.pop(context);
    } on ValidationException catch (x) {
      setState(() => error = x.message);
    }
  }

  Widget _money_(TextEditingController c, String label, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Sp.x3),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '$label (optional)',
            prefixText: '₹ ',
            helperText: hint,
          ),
        ),
      );

  Widget _plain(
    TextEditingController c,
    String label, {
    bool number = false,
    String? suffix,
    String? hint,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.x3),
    child: TextField(
      controller: c,
      onChanged: onChanged,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: number
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: hint,
      ),
    ),
  );

  Future<DateTime?> _pickDate(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return d == null ? null : Dates.fromLocal(d);
  }

  Widget _dateButton(String label, DateTime? d, ValueChanged<DateTime> set) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Sp.x3),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.event),
          label: Text(
            d == null
                ? label
                : '$label: ${DateFormat('EEE, d MMM y').format(d)}',
          ),
          onPressed: () async {
            final p = await _pickDate(d ?? Dates.today());
            if (p != null) setState(() => set(p));
          },
        ),
      );

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _scheduleFields(BuildContext context) {
    final unit = switch (cycle) {
      'daily' => 'day(s)',
      'weekly' => 'week(s)',
      'monthly' => 'month(s)',
      _ => 'year(s)',
    };
    final sch = _schedule();
    final problem = sch?.validate();
    final next = problem == null ? sch?.upcoming(limit: 3) : null;
    final total = problem == null ? sch?.total : null;
    final c = context.cash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateButton('Starts', start, (d) => start = d),
        Text('Repeats', style: context.text.labelLarge),
        const SizedBox(height: Sp.x2),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'daily', label: Text('Daily')),
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ButtonSegment(value: 'yearly', label: Text('Yearly')),
          ],
          selected: {cycle},
          onSelectionChanged: (v) => setState(() => cycle = v.first),
        ),
        const SizedBox(height: Sp.x3),
        _plain(
          every,
          'Every',
          number: true,
          suffix: unit,
          onChanged: (_) => setState(() {}),
        ),
        if (cycle == 'weekly') ...[
          Text('On', style: context.text.labelLarge),
          const SizedBox(height: Sp.x2),
          Wrap(
            spacing: Sp.x2,
            children: [
              for (var i = 1; i <= 7; i++)
                ChoiceChip(
                  label: Text(_weekdays[i - 1]),
                  selected: (weekday ?? start?.weekday) == i,
                  onSelected: (_) => setState(() => weekday = i),
                ),
            ],
          ),
          const SizedBox(height: Sp.x3),
        ],
        if (cycle == 'monthly')
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: DropdownButtonFormField<int>(
              initialValue: monthDay ?? start?.day ?? 1,
              decoration: const InputDecoration(
                labelText: 'Day of the month',
                helperText: 'Short months use their last day (31 → 28/30)',
              ),
              items: [
                for (var i = 1; i <= 31; i++)
                  DropdownMenuItem(value: i, child: Text('$i')),
              ],
              onChanged: (v) => setState(() => monthDay = v),
            ),
          ),
        if (cycle == 'yearly' && start != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: Text(
              'Repeats on ${DateFormat('d MMMM').format(start!)} each year.',
              style: TextStyle(color: c.textMuted),
            ),
          ),
        if (cycle == 'daily')
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      timeOfDay == null
                          ? 'Time of day (optional)'
                          : 'Time: $timeOfDay',
                    ),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (t != null) {
                        setState(
                          () => timeOfDay =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  ),
                ),
                if (timeOfDay != null)
                  IconButton(
                    tooltip: 'Clear time',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => timeOfDay = null),
                  ),
              ],
            ),
          ),
        Text('Ends', style: context.text.labelLarge),
        const SizedBox(height: Sp.x2),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'never', label: Text('Never')),
            ButtonSegment(value: 'count', label: Text('After N')),
            ButtonSegment(value: 'date', label: Text('On a date')),
          ],
          selected: {ends},
          onSelectionChanged: (v) => setState(() => ends = v.first),
        ),
        const SizedBox(height: Sp.x3),
        if (ends == 'count')
          _plain(
            count,
            'Number of instalments',
            number: true,
            onChanged: (_) => setState(() {}),
          ),
        if (ends == 'date') _dateButton('Ends', endDate, (d) => endDate = d),
        // Live preview so the rule can be checked before saving.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: Sp.x3),
          padding: const EdgeInsets.all(Sp.x3),
          decoration: BoxDecoration(
            color: kindColor('custom').withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Sp.rChip),
          ),
          child: problem != null
              ? Text(problem, style: TextStyle(color: c.spending))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sch!.describe(),
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (next != null && next.isNotEmpty)
                          'Next: ${next.map((d) => DateFormat('d MMM y').format(d)).join(', ')}',
                        total == null
                            ? 'No end'
                            : '$total instalment${total == 1 ? '' : 's'}',
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? [];
    final color = kindColor(kind);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    emojiForInvestment(kind),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Text(
                    '${e == null ? 'New' : 'Edit'} ${investKindLabel(kind).toLowerCase()}',
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            _plain(
              name,
              kind == 'stock'
                  ? 'Stock name or symbol'
                  : isCustom
                  ? 'What is it? (e.g. Gold, Chit, PPF)'
                  : 'Fund name',
            ),
            if (isCustom) ...[
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('One time')),
                  ButtonSegment(value: true, label: Text('Recurring')),
                ],
                selected: {recurring},
                onSelectionChanged: (v) => setState(() => recurring = v.first),
              ),
              const SizedBox(height: Sp.x4),
              _money_(
                amount,
                recurring ? 'Amount each time' : 'Amount invested',
              ),
              if (recurring)
                _scheduleFields(context)
              else if (e == null)
                _dateButton('Date', oneTimeDate, (d) => oneTimeDate = d),
            ],
            if (kind == 'mutual_fund') _money_(amount, 'SIP amount per month'),
            if (kind == 'stock') ...[
              _plain(units, 'Units held (optional)', number: true),
              _money_(buy, 'Average buy price per unit'),
            ],
            _money_(
              value,
              'Current value',
              hint: 'Update it any time; leave blank if unknown',
            ),
            _plain(
              growth,
              'Expected growth per year (optional)',
              number: true,
              suffix: '%',
              hint: 'Only used for an estimate, never your balance',
            ),
            if (!isCustom)
              _dateButton('Start date (optional)', start, (d) => start = d),
            if ((settings?.split ?? false) && accounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x3),
                child: DropdownButtonFormField<String?>(
                  initialValue: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pay from (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Default account'),
                    ),
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => accountId = v),
                ),
              ),
            _plain(note, 'Note (optional)'),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x3),
                child: Text(
                  error!,
                  style: TextStyle(color: context.cash.spending),
                ),
              ),
            FilledButton(
              onPressed: _save,
              child: Text(e == null ? 'Add' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── detail ─────────────────────────
class InvestDetailPage extends ConsumerWidget {
  final String id;
  const InvestDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(investSummariesProvider);
    final s = all.value?.where((x) => x.inv.id == id).firstOrNull;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : const EmptyState(
                icon: Icons.search_off,
                title: 'Investment not found',
              ),
      );
    }
    final inv = s.inv;
    final color = kindColor(inv.kind);
    final c = context.cash;
    final up = s.gain >= 0;
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(inv.name, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                showInvestmentForm(context, kind: inv.kind, edit: inv);
              } else {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text('Delete ${inv.name}?'),
                    content: const Text(
                      'Its entries are removed and any balance changes they made are undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await repo.deleteInvestment(inv.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
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
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        emojiForInvestment(inv.kind),
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: Sp.x2),
                      Text(
                        s.valueIsEstimate ? 'Still invested' : 'Worth now',
                        style: context.text.labelLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.x2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUp(
                      value: s.currentValue,
                      builder: (v) => MoneyText(
                        v,
                        color: Colors.white,
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (!s.valueIsEstimate && s.gainPct != null) ...[
                    const SizedBox(height: Sp.x2),
                    Text(
                      '${up ? '▲' : '▼'} ${Money.format(s.gain.abs())} (${_pct(s.gainPct!)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (inv.valueUpdatedOn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.x1),
                      child: Text(
                        'Value updated ${DateFormat('d MMM').format(Dates.parse(inv.valueUpdatedOn!))}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
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
                _stat(
                  context,
                  'Put in',
                  Money.format(s.contributed),
                  c.spending,
                ),
                _stat(
                  context,
                  'Received back',
                  Money.format(s.withdrawn + s.dividends),
                  c.income,
                ),
                if (s.xirrRate != null)
                  _stat(
                    context,
                    'Yearly return',
                    _pct(s.xirrRate!),
                    s.xirrRate! >= 0 ? c.income : c.spending,
                  ),
                if (s.projected != null)
                  _stat(
                    context,
                    'Estimate at ${(inv.expectedGrowthBps! / 100).toStringAsFixed(1)}%/yr',
                    Money.format(s.projected!),
                    color,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x4),
          Reveal(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: color,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add money'),
                    onPressed: () => showEntrySheet(
                      context,
                      inv,
                      type: 'contribute',
                      suggest: inv.sipMinor,
                    ),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.call_received),
                    label: const Text('Withdraw'),
                    onPressed: () =>
                        showEntrySheet(context, inv, type: 'withdraw'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Sp.x2),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Update current value'),
                    onPressed: () => _updateValue(context, repo, inv),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.redeem),
                    label: const Text('Dividend'),
                    onPressed: () =>
                        showEntrySheet(context, inv, type: 'dividend'),
                  ),
                ),
              ],
            ),
          ),
          if (inv.recurring) ScheduleSection(s: s),
          const SectionTitle('History'),
          if (s.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'Nothing recorded yet.',
                style: TextStyle(color: c.textMuted),
              ),
            ),
          for (final en in s.entries.reversed) _EntryRow(en: en, inv: inv),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) =>
      Container(
        constraints: BoxConstraints(
          minWidth: (MediaQuery.sizeOf(context).width - Sp.x4 * 2 - Sp.x3) / 2,
          maxWidth: MediaQuery.sizeOf(context).width - Sp.x4 * 2,
        ),
        padding: const EdgeInsets.all(Sp.x4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Sp.rCard),
        ),
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
            Text(
              value,
              style: context.text.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: moneyFeatures,
              ),
            ),
          ],
        ),
      );

  Future<void> _updateValue(
    BuildContext context,
    dynamic repo,
    Investment inv,
  ) async {
    final c = TextEditingController(
      text: inv.currentValueMinor == null
          ? ''
          : (inv.currentValueMinor! / 100).toStringAsFixed(2),
    );
    final v = await showDialog<int?>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Current value'),
        content: AmountField(
          controller: c,
          label: 'Worth today',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final m = Money.parse(c.text);
              if (m != null && m >= 0) Navigator.pop(d, m);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) await repo.setCurrentValue(inv.id, v);
  }
}

class _EntryRow extends ConsumerWidget {
  final InvestmentEntry en;
  final Investment inv;
  const _EntryRow({required this.en, required this.inv});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cash;
    final inflow = en.type != 'contribute';
    final label = switch (en.type) {
      'contribute' =>
        en.periodKey != null
            ? 'Instalment ${en.periodKey! + 1}'
            : 'Added money',
      'withdraw' => 'Withdrawn',
      'dividend' =>
        en.periodKey != null
            ? 'Dividend, month ${en.periodKey! + 1}'
            : 'Dividend',
      _ => 'Payout',
    };
    return Dismissible(
      key: ValueKey(en.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Sp.x6),
        color: c.spending.withValues(alpha: 0.9),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(repoProvider).deleteInvestmentEntry(en.id),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x2),
        leading: CircleAvatar(
          backgroundColor: (inflow ? c.income : c.spending).withValues(
            alpha: 0.14,
          ),
          child: Icon(
            inflow ? Icons.south_west : Icons.north_east,
            color: inflow ? c.income : c.spending,
            size: 20,
          ),
        ),
        title: Text(label),
        subtitle: Text(
          [
            DateFormat('d MMM y').format(Dates.parse(en.date)),
            if (!en.postToBalance) 'balance unchanged',
            if (en.note.isNotEmpty) en.note,
          ].join(' · '),
        ),
        trailing: TrailingMoney(
          en.amountMinor,
          color: inflow ? c.income : c.spending,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Add a contribution / withdrawal / dividend / payout.
Future<void> showEntrySheet(
  BuildContext context,
  Investment inv, {
  required String type,
  int? suggest,
  int? periodKey,
  DateTime? date,
}) => showSheet(
  context,
  (_) => _EntrySheet(
    inv: inv,
    type: type,
    suggest: suggest,
    periodKey: periodKey,
    date: date,
  ),
);

class _EntrySheet extends ConsumerStatefulWidget {
  final Investment inv;
  final String type;
  final int? suggest, periodKey;
  final DateTime? date;
  const _EntrySheet({
    required this.inv,
    required this.type,
    this.suggest,
    this.periodKey,
    this.date,
  });
  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final amount = TextEditingController(
    text: widget.suggest == null
        ? ''
        : (widget.suggest! / 100).toStringAsFixed(2),
  );
  final note = TextEditingController();
  late DateTime date = widget.date ?? Dates.today();
  bool post = true;
  String? error;

  String get title => switch (widget.type) {
    'contribute' =>
      widget.periodKey != null
          ? 'Pay instalment ${widget.periodKey! + 1}'
          : 'Add money',
    'withdraw' => 'Withdraw',
    'dividend' => 'Record dividend',
    _ => 'Record payout',
  };

  Future<void> _save() async {
    final amt = Money.parse(amount.text);
    if (amt == null || amt <= 0) {
      setState(() => error = 'Enter a valid amount');
      return;
    }
    try {
      await ref
          .read(repoProvider)
          .addInvestmentEntry(
            widget.inv.id,
            type: widget.type,
            amountMinor: amt,
            date: date,
            periodKey: widget.periodKey,
            postToBalance: post,
            note: note.text.trim(),
          );
      haptic();
      if (mounted) Navigator.pop(context);
    } on ValidationException catch (x) {
      setState(() => error = x.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalOn = ref.watch(
      settingsProvider.select((s) => s.value?.investReducesBalance ?? true),
    );
    final out = widget.type == 'contribute';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x4),
            AmountField(controller: amount, autofocus: true),
            const SizedBox(height: Sp.x3),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.event),
              label: Text(DateFormat('EEE, d MMM y').format(date)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => date = Dates.fromLocal(d));
              },
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: globalOn && post,
              onChanged: globalOn ? (v) => setState(() => post = v) : null,
              title: Text(out ? 'Reduce my balance' : 'Add to my balance'),
              subtitle: Text(
                globalOn
                    ? 'Turn off for money that never passed through your accounts here.'
                    : 'Off in Settings → Balance rules, so your balance will not change.',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x2),
                child: Text(
                  error!,
                  style: TextStyle(color: context.cash.spending),
                ),
              ),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── recurring schedule ─────────────────────────
class ScheduleSection extends ConsumerWidget {
  final InvestSummary s;
  const ScheduleSection({super.key, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = s.inv;
    final sch = inv.schedule;
    final c = context.cash;
    if (sch == null) return const SizedBox.shrink();
    final color = kindColor('custom');
    final today = ref.read(repoProvider).today;
    final paid = {
      for (final e in s.entries)
        if (e.type == 'contribute' && e.periodKey != null) e.periodKey!: e,
    };
    final total = sch.total;
    final dueN = sch.dueCount(today);
    final overdue = [
      for (var k = 0; k < dueN; k++)
        if (!paid.containsKey(k)) k,
    ];
    // next instalment that is not yet due
    final upcoming = sch.upcoming(from: dueN, limit: 3);
    final paidCount = paid.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Schedule'),
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sch.describe(),
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (inv.sipMinor != null) Money.format(inv.sipMinor!),
                      'from ${DateFormat('d MMM y').format(sch.start)}',
                      if (sch.until != null)
                        'until ${DateFormat('d MMM y').format(sch.until!)}',
                    ].join(' · '),
                    style: context.text.bodySmall?.copyWith(color: c.textMuted),
                  ),
                  if (total != null && total > 0) ...[
                    const SizedBox(height: Sp.x3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (paidCount / total).clamp(0, 1)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.x2),
                    Text(
                      '$paidCount of $total instalments paid'
                      '${total - paidCount > 0 ? ' · ${total - paidCount} to go' : ' · complete 🎉'}',
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.x2),
                      child: Text('$paidCount paid so far · no end date'),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (overdue.isNotEmpty) ...[
          SectionTitle(
            'Due now',
            trailing: Text(
              '${overdue.length} unpaid',
              style: TextStyle(color: c.spending, fontWeight: FontWeight.w700),
            ),
          ),
          for (final k in overdue.reversed.take(10))
            _InstalmentRow(
              k: k,
              date: sch.at(k)!,
              inv: inv,
              paid: null,
              today: today,
            ),
          if (overdue.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x1),
              child: Text(
                '+ ${overdue.length - 10} older unpaid instalments',
                style: TextStyle(color: c.textMuted),
              ),
            ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SectionTitle('Coming up'),
          for (var i = 0; i < upcoming.length; i++)
            _InstalmentRow(
              k: dueN + i,
              date: upcoming[i],
              inv: inv,
              paid: paid[dueN + i],
              today: today,
            ),
        ],
      ],
    );
  }
}

class _InstalmentRow extends ConsumerWidget {
  final int k;
  final DateTime date, today;
  final Investment inv;
  final InvestmentEntry? paid;
  const _InstalmentRow({
    required this.k,
    required this.date,
    required this.inv,
    required this.paid,
    required this.today,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cash;
    final done = paid != null;
    final late = !done && date.isBefore(today);
    final time = inv.cycle == 'daily' && inv.timeOfDay != null
        ? ' · ${inv.timeOfDay}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        decoration: BoxDecoration(
          color: done
              ? c.income.withValues(alpha: 0.08)
              : late
              ? c.spending.withValues(alpha: 0.07)
              : c.surfaceRaised,
          borderRadius: BorderRadius.circular(Sp.rChip),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? c.income : (late ? c.spending : c.textMuted),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instalment ${k + 1} · ${DateFormat('EEE, d MMM y').format(date)}$time',
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    done
                        ? 'Paid ${Money.format(paid!.amountMinor)}'
                        : late
                        ? 'Overdue'
                        : 'Upcoming',
                    style: context.text.bodySmall?.copyWith(
                      color: late ? c.spending : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!done)
              TextButton(
                onPressed: () => showEntrySheet(
                  context,
                  inv,
                  type: 'contribute',
                  suggest: inv.sipMinor,
                  periodKey: k,
                  date: date.isAfter(today) ? today : date,
                ),
                child: const Text('Pay'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/invest_repo.dart';
import '../data/repo.dart' show ValidationException;
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
  'chit' => const Color(0xFFFF8A3D),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFF2F6BFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
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
              body: 'Track mutual funds, stocks and chit funds in one place. Every field except the name is optional.',
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
          tile('chit', 'Monthly chit with tenure and payout'),
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

  String _m(int? v) => v == null ? '' : (v / 100).toStringAsFixed(2);
  late final name = TextEditingController(text: e?.name ?? '');
  late final growth = TextEditingController(
    text: e?.expectedGrowthBps == null
        ? ''
        : (e!.expectedGrowthBps! / 100).toString(),
  );
  late final value = TextEditingController(text: _m(e?.currentValueMinor));
  late final sip = TextEditingController(text: _m(e?.sipMinor));
  late final units = TextEditingController(text: e?.units?.toString() ?? '');
  late final buy = TextEditingController(text: _m(e?.buyPriceMinor));
  late final chitValue = TextEditingController(text: _m(e?.chitValueMinor));
  late final tenure = TextEditingController(
    text: e?.tenureMonths?.toString() ?? '',
  );
  late final members = TextEditingController(
    text: e?.members?.toString() ?? '',
  );
  late final monthly = TextEditingController(text: _m(e?.monthlyMinor));
  late final commission = TextEditingController(
    text: e?.commissionBps == null ? '' : (e!.commissionBps! / 100).toString(),
  );
  late final organiser = TextEditingController(text: e?.organiser ?? '');
  late final note = TextEditingController(text: e?.note ?? '');
  late DateTime? start = e?.startDate == null
      ? null
      : Dates.parse(e!.startDate!);
  late String? accountId = e?.accountId;
  String? error;

  int? _money(TextEditingController c) =>
      c.text.trim().isEmpty ? null : Money.parse(c.text);
  double? _num(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    final g = _num(growth);
    final bad = <String>[
      if (value.text.trim().isNotEmpty && _money(value) == null)
        'current value',
      if (sip.text.trim().isNotEmpty && _money(sip) == null) 'SIP amount',
      if (buy.text.trim().isNotEmpty && _money(buy) == null) 'buy price',
      if (chitValue.text.trim().isNotEmpty && _money(chitValue) == null)
        'chit value',
      if (monthly.text.trim().isNotEmpty && _money(monthly) == null)
        'instalment',
      if (growth.text.trim().isNotEmpty && g == null) 'growth %',
      if (units.text.trim().isNotEmpty && _num(units) == null) 'units',
    ];
    if (bad.isNotEmpty) {
      setState(() => error = 'Check: ${bad.join(', ')}');
      return;
    }
    final isChit = kind == 'chit';
    try {
      if (e == null) {
        await repo.createInvestment(
          kind: kind,
          name: name.text,
          accountId: accountId,
          startDate: start,
          expectedGrowthBps: g == null ? null : (g * 100).round(),
          currentValueMinor: _money(value),
          units: _num(units),
          buyPriceMinor: _money(buy),
          sipMinor: _money(sip),
          chitValueMinor: isChit ? _money(chitValue) : null,
          tenureMonths: isChit ? int.tryParse(tenure.text.trim()) : null,
          members: isChit ? int.tryParse(members.text.trim()) : null,
          monthlyMinor: isChit ? _money(monthly) : null,
          commissionBps: isChit && _num(commission) != null
              ? (_num(commission)! * 100).round()
              : null,
          organiser: organiser.text.trim().isEmpty
              ? null
              : organiser.text.trim(),
          note: note.text.trim(),
        );
      } else {
        await repo.updateInvestment(
          e!.id,
          name: name.text,
          accountId: accountId,
          startDate: start,
          expectedGrowthBps: g == null ? null : (g * 100).round(),
          currentValueMinor: _money(value),
          units: _num(units),
          buyPriceMinor: _money(buy),
          sipMinor: _money(sip),
          chitValueMinor: isChit ? _money(chitValue) : null,
          tenureMonths: isChit ? int.tryParse(tenure.text.trim()) : null,
          members: isChit ? int.tryParse(members.text.trim()) : null,
          monthlyMinor: isChit ? _money(monthly) : null,
          commissionBps: isChit && _num(commission) != null
              ? (_num(commission)! * 100).round()
              : null,
          organiser: organiser.text.trim().isEmpty
              ? null
              : organiser.text.trim(),
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.x3),
    child: TextField(
      controller: c,
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
                  : kind == 'chit'
                  ? 'Chit name'
                  : 'Fund name',
            ),
            if (kind == 'mutual_fund') _money_(sip, 'SIP amount per month'),
            if (kind == 'stock') ...[
              _plain(units, 'Units held (optional)', number: true),
              _money_(buy, 'Average buy price per unit'),
            ],
            if (kind == 'chit') ...[
              _money_(chitValue, 'Chit value'),
              Row(
                children: [
                  Expanded(
                    child: _plain(
                      tenure,
                      'Tenure',
                      number: true,
                      suffix: 'months',
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(child: _plain(members, 'Members', number: true)),
                ],
              ),
              _money_(monthly, 'Monthly instalment'),
              _plain(
                commission,
                'Foreman commission',
                number: true,
                suffix: '%',
              ),
              _plain(organiser, 'Organiser / foreman'),
            ],
            if (kind != 'chit')
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
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.event),
                label: Text(
                  start == null
                      ? 'Start date (optional)'
                      : 'Started ${DateFormat('d MMM y').format(start!)}',
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: start ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => start = Dates.fromLocal(d));
                },
              ),
            ),
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
          if (inv.kind != 'chit')
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
          if (inv.kind == 'chit') ChitSection(s: s),
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
      _ => 'Chit payout',
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
    _ => 'Record chit payout',
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

// ───────────────────────── chit fund ─────────────────────────
class ChitSection extends ConsumerWidget {
  final InvestSummary s;
  const ChitSection({super.key, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = s.inv;
    final c = context.cash;
    final months = inv.tenureMonths ?? 0;
    final start = inv.startDate == null ? null : Dates.parse(inv.startDate!);
    final paid = {
      for (final e in s.entries)
        if (e.type == 'contribute' && e.periodKey != null) e.periodKey!: e,
    };
    final divs = {
      for (final e in s.entries)
        if (e.type == 'dividend' && e.periodKey != null) e.periodKey!: e,
    };
    final payouts = s.entries.where((e) => e.type == 'payout').toList();
    final monthly = inv.monthlyMinor;
    final remaining = months == 0 ? null : months - paid.length;
    final owed = payouts.isNotEmpty && monthly != null && remaining != null
        ? remaining * monthly
        : null;
    final color = kindColor('chit');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Chit schedule',
          trailing: TextButton.icon(
            icon: const Icon(Icons.emoji_events_outlined, size: 18),
            label: const Text('Record payout'),
            onPressed: () => showEntrySheet(
              context,
              inv,
              type: 'payout',
              suggest: inv.chitValueMinor,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (months > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: paid.length / months),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v.clamp(0, 1),
                        minHeight: 10,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    '${paid.length} of $months instalments paid'
                    '${remaining != null && remaining > 0 ? ' · $remaining to go' : ''}',
                    style: context.text.bodyMedium,
                  ),
                ] else
                  Text(
                    'Add a tenure (in Edit) to see the month-by-month schedule.',
                    style: TextStyle(color: c.textMuted),
                  ),
                if (inv.chitValueMinor != null ||
                    inv.members != null ||
                    inv.organiser != null ||
                    inv.commissionBps != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.x2),
                    child: Text(
                      [
                        if (inv.chitValueMinor != null)
                          'Chit ${Money.format(inv.chitValueMinor!)}',
                        if (inv.members != null) '${inv.members} members',
                        if (inv.commissionBps != null)
                          '${(inv.commissionBps! / 100).toStringAsFixed(1)}% commission',
                        if (inv.organiser != null) inv.organiser!,
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ),
                if (payouts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.x3),
                    child: Container(
                      padding: const EdgeInsets.all(Sp.x3),
                      decoration: BoxDecoration(
                        color: c.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Sp.rChip),
                      ),
                      child: Text(
                        '🎉 Payout ${Money.format(payouts.first.amountMinor)} received on '
                        '${DateFormat('d MMM y').format(Dates.parse(payouts.first.date))}.'
                        '${owed != null && owed > 0 ? ' About ${Money.format(owed)} of instalments still to pay.' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (months > 0 && start != null) ...[
          const SizedBox(height: Sp.x3),
          for (var k = 0; k < months; k++)
            _MonthRow(
              k: k,
              date: Dates.addMonths(start, k),
              inv: inv,
              paid: paid[k],
              dividend: divs[k],
            ),
        ] else if (months > 0)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: Text(
              'Set a start date (in Edit) to date each month.',
              style: TextStyle(color: c.textMuted),
            ),
          ),
      ],
    );
  }
}

class _MonthRow extends ConsumerWidget {
  final int k;
  final DateTime date;
  final Investment inv;
  final InvestmentEntry? paid, dividend;
  const _MonthRow({
    required this.k,
    required this.date,
    required this.inv,
    required this.paid,
    required this.dividend,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cash;
    final done = paid != null;
    final late = !done && date.isBefore(ref.read(repoProvider).today);
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(done),
                color: done ? c.income : (late ? c.spending : c.textMuted),
              ),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Month ${k + 1} · ${DateFormat('d MMM y').format(date)}',
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (done || dividend != null)
                    Text(
                      [
                        if (done) 'Paid ${Money.format(paid!.amountMinor)}',
                        if (dividend != null)
                          'dividend ${Money.format(dividend!.amountMinor)}',
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    )
                  else if (late)
                    Text(
                      'Overdue',
                      style: context.text.bodySmall?.copyWith(
                        color: c.spending,
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
                  suggest: inv.monthlyMinor,
                  periodKey: k,
                  date: date.isAfter(ref.read(repoProvider).today)
                      ? ref.read(repoProvider).today
                      : date,
                ),
                child: const Text('Pay'),
              )
            else if (dividend == null)
              TextButton(
                onPressed: () => showEntrySheet(
                  context,
                  inv,
                  type: 'dividend',
                  periodKey: k,
                  date: date,
                ),
                child: const Text('+ Dividend'),
              ),
          ],
        ),
      ),
    );
  }
}

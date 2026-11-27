import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/loan_repo.dart';
import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/loan.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../platform/reminders.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

final _day = DateFormat('d MMM y');

/// "8.5" -> 8500 thousandths of a percent, or "2.5" -> 250 with scale 100.
int? _percent(String s, [int scale = 1000]) {
  final v = double.tryParse(s.trim());
  return v == null || v < 0 ? null : (v * scale).round();
}

String _percentText(int milli) =>
    (milli / 1000).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

Widget _number(
  String label,
  TextEditingController c, {
  String? helper,
  VoidCallback? onChanged,
}) => Padding(
  padding: const EdgeInsets.only(top: Sp.x3),
  child: TextField(
    key: ValueKey(label),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(Money.inputPattern)],
    decoration: InputDecoration(labelText: tr(label), helperText: helper),
    onChanged: onChanged == null ? null : (_) => onChanged(),
  ),
);

Widget _line(
  BuildContext context,
  String label,
  String value, {
  bool strong = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Expanded(
        child: Text(tr(label), style: TextStyle(color: context.cash.textMuted)),
      ),
      const SizedBox(width: Sp.x3),
      Text(
        value,
        style: context.text.bodyMedium?.copyWith(
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  ),
);

/// A bottom sheet with a title, fields, an error line and one button.
class _Form extends StatelessWidget {
  final String title, action;
  final String? error;
  final List<Widget> children;
  final VoidCallback onSave;
  const _Form({
    required this.title,
    required this.action,
    required this.error,
    required this.children,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(title),
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          ...children,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x3),
              child: Text(
                error!,
                style: TextStyle(color: context.cash.spending),
              ),
            ),
          const SizedBox(height: Sp.x4),
          FilledButton(onPressed: onSave, child: Text(tr(action))),
        ],
      ),
    ),
  );
}

/// Runs [work], closing the sheet when it succeeds; returns the error if not.
Future<String?> _attempt(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(Repo repo) work,
) async {
  final repo = ref.read(repoProvider);
  try {
    await work(repo);
  } on ValidationException catch (e) {
    return e.message;
  } on OverpaymentException {
    return tr('That is more than you owe.');
  }
  await refreshCardReminders(repo);
  if (context.mounted) Navigator.pop(context);
  return null;
}

class AddLoanSheet extends ConsumerStatefulWidget {
  const AddLoanSheet({super.key});
  @override
  ConsumerState<AddLoanSheet> createState() => _AddLoanState();
}

class _AddLoanState extends ConsumerState<AddLoanSheet> {
  var kind = 'personal';
  final lender = TextEditingController();
  final owed = TextEditingController();
  final rate = TextEditingController();
  final months = TextEditingController();
  final day = TextEditingController();
  final emi = TextEditingController();
  String? accountId, error;
  var inBudget = true;

  int get _calculated => emiFor(
    Money.parse(owed.text) ?? 0,
    _percent(rate.text) ?? 0,
    int.tryParse(months.text) ?? 0,
  );

  Future<void> _save() async {
    final amount = Money.parse(owed.text);
    final milli = _percent(rate.text);
    final n = int.tryParse(months.text);
    final on = int.tryParse(day.text);
    if (lender.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        milli == null ||
        n == null ||
        on == null) {
      setState(() => error = tr('Fill in every field.'));
      return;
    }
    final message = await _attempt(
      context,
      ref,
      (repo) => repo.addLoan(
        kind: kind,
        lender: lender.text.trim(),
        owed: amount,
        annualMilli: milli,
        months: n,
        emiDay: on,
        emi: Money.parse(emi.text),
        accountId: accountId,
        emiInBudget: inBudget,
      ),
    );
    if (mounted && message != null) setState(() => error = message);
  }

  @override
  Widget build(BuildContext context) {
    final split = ref.watch(settingsProvider).value?.split ?? false;
    final accounts = ref.watch(accountsProvider).value ?? [];
    void redraw() => setState(() {});
    return _Form(
      title: 'Add EMI loan',
      action: 'Save',
      error: error,
      onSave: _save,
      children: [
        const SizedBox(height: Sp.x3),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'personal', label: Text(tr('Personal'))),
            ButtonSegment(value: 'car', label: Text(tr('Car'))),
            ButtonSegment(value: 'home', label: Text(tr('Home loan'))),
          ],
          selected: {kind},
          onSelectionChanged: (s) => setState(() => kind = s.first),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Sp.x3),
          child: TextField(
            key: const ValueKey('Lender'),
            controller: lender,
            decoration: InputDecoration(labelText: tr('Lender')),
          ),
        ),
        _number('Amount still outstanding', owed, onChanged: redraw),
        _number('Yearly interest rate %', rate, onChanged: redraw),
        _number('Months left', months, onChanged: redraw),
        _number('EMI day of month', day),
        _number(
          'EMI (leave blank to calculate)',
          emi,
          helper: _calculated > 0
              ? '${tr('Calculated')}: ${Money.format(_calculated)}'
              : null,
        ),
        if (split)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: DropdownButtonFormField<String>(
              initialValue:
                  accountId ?? (accounts.isNotEmpty ? accounts.first.id : null),
              decoration: InputDecoration(labelText: tr('Paid from')),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => accountId = v,
            ),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Count the full EMI in my budget')),
          subtitle: Text(tr('Off: only the interest counts.')),
          value: inBudget,
          onChanged: (v) => setState(() => inBudget = v),
        ),
      ],
    );
  }
}

/// EMI paid: the split is worked out, and can be matched to the statement.
class _EmiSheet extends ConsumerStatefulWidget {
  final LoanStatus loan;
  const _EmiSheet(this.loan);
  @override
  ConsumerState<_EmiSheet> createState() => _EmiState();
}

class _EmiState extends ConsumerState<_EmiSheet> {
  late final interest = TextEditingController(
    text: Money.edit(widget.loan.nextInterest),
  );
  late final principal = TextEditingController(
    text: Money.edit(widget.loan.nextPrincipal),
  );
  String? error;

  Future<void> _save() async {
    final i = Money.parse(interest.text) ?? 0;
    final p = Money.parse(principal.text) ?? 0;
    final message = await _attempt(
      context,
      ref,
      (r) => r.payEmi(widget.loan.debt.id, interest: i, principal: p),
    );
    if (mounted && message != null) setState(() => error = message);
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'EMI paid',
    action: 'Record payment',
    error: error,
    onSave: _save,
    children: [
      _number('Interest', interest, onChanged: () => setState(() {})),
      _number('Principal', principal, onChanged: () => setState(() {})),
      const SizedBox(height: Sp.x3),
      _line(
        context,
        'Total',
        Money.format(
          (Money.parse(interest.text) ?? 0) +
              (Money.parse(principal.text) ?? 0),
        ),
        strong: true,
      ),
    ],
  );
}

class _PartSheet extends ConsumerStatefulWidget {
  final LoanStatus loan;
  const _PartSheet(this.loan);
  @override
  ConsumerState<_PartSheet> createState() => _PartState();
}

class _PartState extends ConsumerState<_PartSheet> {
  final amount = TextEditingController();
  var shorter = true;
  String? error;

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final extra = Money.parse(amount.text) ?? 0;
    final owed = l.owed - extra;
    String? preview;
    if (extra > 0 && owed > 0) {
      preview = shorter
          ? '${scheduleFor(owed, l.annualMilli, l.emi)?.length ?? '-'} ${tr('months left')}'
          : '${tr('New EMI')} ${Money.format(emiFor(owed, l.annualMilli, l.monthsLeft))}';
    }
    return _Form(
      title: 'Part payment',
      action: 'Record payment',
      error: error,
      onSave: () async {
        final message = await _attempt(
          context,
          ref,
          (r) => r.partPay(l.debt.id, extra, shorterTerm: shorter),
        );
        if (mounted && message != null) setState(() => error = message);
      },
      children: [
        _number('Extra amount', amount, onChanged: () => setState(() {})),
        const SizedBox(height: Sp.x3),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: true, label: Text(tr('Finish sooner'))),
            ButtonSegment(value: false, label: Text(tr('Lower EMI'))),
          ],
          selected: {shorter},
          onSelectionChanged: (s) => setState(() => shorter = s.first),
        ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: Text(preview, style: context.text.titleMedium),
          ),
      ],
    );
  }
}

class _RateSheet extends ConsumerStatefulWidget {
  final LoanStatus loan;
  const _RateSheet(this.loan);
  @override
  ConsumerState<_RateSheet> createState() => _RateState();
}

class _RateState extends ConsumerState<_RateSheet> {
  late final rate = TextEditingController(
    text: _percentText(widget.loan.annualMilli),
  );
  var keepEmi = true;
  var from = Dates.today();
  String? error;

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Rate change',
    action: 'Save',
    error: error,
    onSave: () async {
      final milli = _percent(rate.text);
      if (milli == null) return;
      final message = await _attempt(
        context,
        ref,
        (r) => r.changeLoanRate(
          widget.loan.debt.id,
          milli,
          from: from,
          keepEmi: keepEmi,
        ),
      );
      if (mounted && message != null) setState(() => error = message);
    },
    children: [
      _number('Yearly interest rate %', rate),
      const SizedBox(height: Sp.x3),
      OutlinedButton.icon(
        icon: const Icon(Icons.event),
        label: Text('${tr('From')} ${_day.format(from)}'),
        onPressed: () async {
          final p = await showDatePicker(
            context: context,
            initialDate: from,
            firstDate: Dates.parse(widget.loan.debt.issuedOn),
            lastDate: DateTime(2100),
          );
          if (p != null) setState(() => from = Dates.fromLocal(p));
        },
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(tr('Keep the same EMI')),
        subtitle: Text(tr('Off: the term stays and the EMI changes.')),
        value: keepEmi,
        onChanged: (v) => setState(() => keepEmi = v),
      ),
    ],
  );
}

class _PrecloseSheet extends ConsumerStatefulWidget {
  final LoanStatus loan;
  const _PrecloseSheet(this.loan);
  @override
  ConsumerState<_PrecloseSheet> createState() => _PrecloseState();
}

class _PrecloseState extends ConsumerState<_PrecloseSheet> {
  final penalty = TextEditingController(text: '0');
  final tax = TextEditingController(text: '18');
  String? error;

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final p = preclosureFor(
      owed: l.owed,
      annualMilli: l.annualMilli,
      emi: l.emi,
      days: Dates.today().difference(l.lastPaid).inDays,
      penaltyBps: _percent(penalty.text, 100) ?? 0,
      taxBps: _percent(tax.text, 100) ?? 0,
    );
    void redraw() => setState(() {});
    return _Form(
      title: 'Preclose loan',
      action: 'I have paid this',
      error: error,
      onSave: () async {
        final message = await _attempt(
          context,
          ref,
          (r) => r.precloseLoan(
            l.debt.id,
            interest: p.interest,
            charges: p.penalty + p.tax,
          ),
        );
        if (mounted && message != null) setState(() => error = message);
      },
      children: [
        _number(
          'Penalty % (from your sanction letter)',
          penalty,
          onChanged: redraw,
        ),
        _number('GST on penalty %', tax, onChanged: redraw),
        const SizedBox(height: Sp.x3),
        _line(context, 'Principal', Money.format(p.principal)),
        _line(context, 'Interest to date', Money.format(p.interest)),
        _line(context, 'Penalty', Money.format(p.penalty)),
        _line(context, 'GST', Money.format(p.tax)),
        _line(context, 'Total to pay', Money.format(p.total), strong: true),
        _line(context, 'You save', Money.format(p.saving), strong: true),
        const SizedBox(height: Sp.x2),
        Text(
          tr('An estimate. Ask your lender for the exact closing amount.'),
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
      ],
    );
  }
}

class LoanPage extends ConsumerWidget {
  final String debtId;
  const LoanPage({super.key, required this.debtId});

  static const _events = {
    'repayment': 'Payment',
    'interest_paid': 'Interest',
    'fee': 'Charges',
    'terms': 'Rate or EMI changed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds whenever the debts change.
    ref.watch(debtSummariesProvider('liability'));
    final repo = ref.watch(repoProvider);
    return FutureBuilder<LoanStatus>(
      future: repo.loanStatus(debtId),
      builder: (context, snap) {
        final l = snap.data;
        if (l == null) return Scaffold(appBar: AppBar());
        return _page(context, ref, l);
      },
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, LoanStatus l) {
    final repo = ref.read(repoProvider);
    final open = l.owed > 0;
    final due = l.nextDue(repo.today);
    Widget action(String label, IconData icon, Widget sheet) =>
        OutlinedButton.icon(
          icon: Icon(icon),
          label: Text(tr(label)),
          onPressed: () => showSheet(context, (_) => sheet),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.debt.counterparty),
        actions: [
          IconButton(
            tooltip: tr('Delete loan'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('Delete this loan?')),
                  content: Text(
                    tr('Its payments are removed and balances are restored.'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(tr('Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(tr('Delete')),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await repo.deleteDebt(debtId);
              await refreshCardReminders(repo);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Sp.x4),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(open ? 'Outstanding' : 'Closed'),
                    style: TextStyle(color: context.cash.textMuted),
                  ),
                  MoneyText(
                    l.owed,
                    color: context.cash.liability,
                    style: context.text.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Sp.x3),
                  if (open) ...[
                    _line(context, 'EMI', Money.format(l.emi), strong: true),
                    _line(context, 'Next EMI', _day.format(due)),
                    _line(context, 'Rate', '${_percentText(l.annualMilli)}%'),
                    _line(context, 'Months left', '${l.monthsLeft}'),
                    _line(
                      context,
                      'Interest still to pay',
                      Money.format(l.interestLeft),
                    ),
                  ],
                  _line(context, 'Interest paid', Money.format(l.interestPaid)),
                ],
              ),
            ),
          ),
          if (open) ...[
            const SizedBox(height: Sp.x3),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(tr('EMI paid')),
              onPressed: () => showSheet(context, (_) => _EmiSheet(l)),
            ),
            const SizedBox(height: Sp.x2),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                action('Part payment', Icons.savings_outlined, _PartSheet(l)),
                action('Rate change', Icons.percent, _RateSheet(l)),
                action('Preclose', Icons.flag_outlined, _PrecloseSheet(l)),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Count the full EMI in my budget')),
              value: l.debt.emiInBudget ?? true,
              onChanged: (v) => repo.setEmiInBudget(debtId, v),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(tr('Schedule')),
              children: [
                for (final (i, s)
                    in (l.schedule ?? const <Instalment>[]).indexed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      DateFormat('MMM y').format(Dates.addMonths(due, i)),
                    ),
                    subtitle: Text(
                      '${tr('Interest')} ${Money.format(s.interest)} · '
                      '${tr('Principal')} ${Money.format(s.principal)}',
                    ),
                    trailing: Text(Money.format(s.balance)),
                  ),
              ],
            ),
          ],
          const SectionTitle('History'),
          for (final e in l.history)
            if (_events.containsKey(e.type))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(_events[e.type]!)),
                subtitle: Text(_day.format(Dates.parse(e.date))),
                trailing: Text(
                  e.type == 'terms'
                      ? '${_percentText(e.amountMinor)}% · ${Money.format(e.principalPart)}'
                      : Money.format(e.amountMinor),
                ),
                // Removing the principal payment removes the whole payment.
                onLongPress: e.type != 'repayment' && e.type != 'terms'
                    ? null
                    : () async {
                        await repo.deleteDebtEvent(e.id);
                        if (context.mounted) toast(context, 'Removed');
                      },
              ),
          if (l.history.any((e) => e.type == 'repayment'))
            Text(
              tr('Press and hold a payment to remove it.'),
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/interest.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/art.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});
  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Receivables'),
            Tab(text: 'Liabilities'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSheet(
          context,
          (_) => AddDebtSheet(
            direction: _tabs.index == 0 ? 'receivable' : 'liability',
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'I lent' : 'I borrowed'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _DebtList(direction: 'receivable'),
          _DebtList(direction: 'liability'),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }
}

class _DebtList extends ConsumerWidget {
  final String direction;
  const _DebtList({required this.direction});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(debtSummariesProvider(direction));
    final rec = direction == 'receivable';
    final color = rec ? context.cash.debtIn : context.cash.liability;
    return list.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => ErrorState(e),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            art: Art.handshake,
            icon: rec ? Icons.call_received : Icons.call_made,
            title: rec ? 'Nobody owes you money' : 'You owe nobody',
            body: rec
                ? 'Track money you lent, with or without interest.'
                : 'Track money you borrowed and what you still owe.',
          );
        }
        final open = items.where((s) => !s.settled).toList();
        final settled = items.where((s) => s.settled).toList();
        final total = open.fold<int>(0, (a, s) => a + s.state.outstanding);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec ? 'Total to collect' : 'Total you owe',
                      style: context.text.labelLarge?.copyWith(
                        color: context.cash.textMuted,
                      ),
                    ),
                    MoneyText(
                      total,
                      color: color,
                      style: context.text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            for (final (i, s) in open.indexed)
              Reveal(index: i + 1, child: _DebtTile(s, color)),
            if (settled.isNotEmpty) ...[
              const SectionTitle('Settled'),
              for (final s in settled) _DebtTile(s, context.cash.textMuted),
            ],
          ],
        );
      },
    );
  }
}

class _DebtTile extends StatelessWidget {
  final DebtSummary s;
  final Color color;
  const _DebtTile(this.s, this.color);
  @override
  Widget build(BuildContext context) {
    final d = s.debt;
    final total = d.principalMinor + s.state.totalAccrued;
    final progress = total == 0
        ? 0.0
        : (s.state.totalPaid / total).clamp(0, 1).toDouble();
    final due = d.dueOn == null ? null : Dates.parse(d.dueOn!);
    final overdue = due != null && !s.settled && due.isBefore(Dates.today());
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Sp.rCard),
          onTap: () =>
              Navigator.of(context)
                  .push(softRoute(DebtDetailPage(debtId: d.id))),
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.counterparty,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    MoneyText(
                      s.state.outstanding,
                      color: color,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x2),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: Sp.x2),
                Wrap(
                  spacing: Sp.x3,
                  children: [
                    Text(
                      '${(progress * 100).round()}% repaid',
                      style: context.text.bodySmall?.copyWith(
                        color: context.cash.textMuted,
                      ),
                    ),
                    if (d.interestEnabled)
                      Text(
                        '${(d.rateBps / 100).toStringAsFixed(2)}% ${d.ratePeriod} · ${d.interestType}',
                        style: context.text.bodySmall?.copyWith(
                          color: context.cash.textMuted,
                        ),
                      ),
                    if (due != null)
                      Text(
                        overdue
                            ? 'Overdue · ${DateFormat('d MMM').format(due)}'
                            : 'Due ${DateFormat('d MMM y').format(due)}',
                        style: context.text.bodySmall?.copyWith(
                          color: overdue
                              ? context.cash.spending
                              : context.cash.textMuted,
                          fontWeight: overdue ? FontWeight.w700 : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddDebtSheet extends ConsumerStatefulWidget {
  final String direction;
  const AddDebtSheet({super.key, required this.direction});
  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _who = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _note = TextEditingController();
  bool interest = false;
  String type = 'simple';
  String period = 'monthly';
  DateTime issued = Dates.today();
  DateTime? due;
  String? accountId;
  bool affects = true;
  String? error;
  bool saving = false;

  Future<void> _save() async {
    final amt = Money.parse(_amount.text);
    final rate = interest ? double.tryParse(_rate.text.trim()) : 0;
    if (_who.text.trim().isEmpty) return setState(() => error = 'Enter a name');
    if (amt == null || amt <= 0) {
      return setState(() => error = 'Enter a valid amount');
    }
    if (interest && (rate == null || rate <= 0 || rate > 1000)) {
      return setState(() => error = 'Enter a valid interest rate (%)');
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(repoProvider)
          .createDebt(
            direction: widget.direction,
            counterparty: _who.text,
            principalMinor: amt,
            issuedOn: issued,
            dueOn: due,
            interestEnabled: interest,
            interestType: type,
            rateBps: interest ? (rate! * 100).round() : 0,
            ratePeriod: period,
            accountId: accountId,
            note: _note.text.trim(),
            affectsBalance: affects,
          );
      if (mounted) Navigator.pop(context);
    } on ValidationException catch (e) {
      setState(() {
        error = e.message;
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.direction == 'receivable';
    final split = ref.watch(settingsProvider).value?.split ?? false;
    final accounts = ref.watch(accountsProvider).value ?? [];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rec ? 'Money you lent' : 'Money you borrowed',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              rec
                  ? 'The amount leaves your account now.'
                  : 'The amount is added to your account now.',
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
            const SizedBox(height: Sp.x4),
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: rec ? 'Lent to' : 'Borrowed from',
              ),
            ),
            const SizedBox(height: Sp.x3),
            AmountField(controller: _amount, label: 'Principal'),
            const SizedBox(height: Sp.x3),
            if (split)
              DropdownButtonFormField<String>(
                initialValue:
                    accountId ??
                    (accounts.isNotEmpty ? accounts.first.id : null),
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => accountId = v,
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Charge interest'),
              value: interest,
              onChanged: (v) => setState(() => interest = v),
            ),
            if (interest) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        suffixText: '%',
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: period,
                      decoration: const InputDecoration(labelText: 'per'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('day')),
                        DropdownMenuItem(value: 'weekly', child: Text('week')),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('month'),
                        ),
                        DropdownMenuItem(value: 'yearly', child: Text('year')),
                      ],
                      onChanged: (v) => setState(() => period = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'simple', label: Text('Simple')),
                  ButtonSegment(value: 'compound', label: Text('Compound')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
            ],
            const SizedBox(height: Sp.x3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(DateFormat('d MMM y').format(issued)),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: issued,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) {
                        setState(() => issued = Dates.fromLocal(p));
                      }
                    },
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alarm),
                    label: Text(
                      due == null
                          ? 'Due date'
                          : DateFormat('d MMM y').format(due!),
                    ),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: due ?? issued,
                        firstDate: issued,
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setState(() => due = Dates.fromLocal(p));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: affects,
              onChanged: (v) => setState(() => affects = v),
              title: Text(
                rec ? 'Take this from my balance' : 'Add this to my balance',
              ),
              subtitle: Text(
                affects
                    ? (rec
                          ? 'Your balance goes down by the amount you lent.'
                          : 'Your balance goes up by the amount you borrowed.')
                    : 'Your balance will not change (money that did not pass through your accounts).',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x3),
                child: Text(
                  error!,
                  style: TextStyle(color: context.cash.spending),
                ),
              ),
            const SizedBox(height: Sp.x5),
            FilledButton(
              onPressed: saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class DebtDetailPage extends ConsumerWidget {
  final String debtId;
  const DebtDetailPage({super.key, required this.debtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(changesProvider);
    final repo = ref.watch(repoProvider);
    return FutureBuilder(
      future: Future.wait([
        repo.debts().then((l) => l.where((d) => d.id == debtId).firstOrNull),
        repo
            .debtState(debtId)
            .then<DebtState?>((v) => v)
            .catchError((_) => null),
        repo.debtTimeline(debtId),
      ]),
      builder: (context, snap) {
        final debt = snap.data?[0] as Debt?;
        final st = snap.data?[1] as DebtState?;
        final tl = (snap.data?[2] as List<DebtEvent>?) ?? [];
        if (snap.connectionState != ConnectionState.done && debt == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (debt == null || st == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Debt not found',
            ),
          );
        }
        final rec = debt.direction == 'receivable';
        final color = rec ? context.cash.debtIn : context.cash.liability;
        return Scaffold(
          appBar: AppBar(
            title: Text(debt.counterparty),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete this debt?'),
                        content: const Text(
                          'Its repayments and linked ledger entries are removed and balances are restored.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await repo.deleteDebt(debtId);
                      if (context.mounted) Navigator.pop(context);
                    }
                  } else if (v == 'combined') {
                    if (context.mounted) {
                      await showSheet(
                        context,
                        (_) => _RepaymentSheet(
                          debtId: debtId,
                          max: st.outstanding,
                          rec: rec,
                        ),
                      );
                    }
                  } else if (v == 'writeoff') {
                    if (context.mounted) {
                      await showSheet(
                        context,
                        (_) => _RepaymentSheet(
                          debtId: debtId,
                          writeOff: true,
                          max: st.outstanding,
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'combined',
                    child: Text('One payment: interest first, then principal'),
                  ),
                  PopupMenuItem(
                    value: 'writeoff',
                    child: Text('Write off an amount'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete debt')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: st.outstanding > 0
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.x4),
                    child: Row(
                      children: [
                        if (debt.interestEnabled) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                              ),
                              icon: const Icon(Icons.percent),
                              label: Text(
                                rec ? 'Interest received' : 'Interest paid',
                              ),
                              onPressed: () => showSheet(
                                context,
                                (_) => _RepaymentSheet(
                                  debtId: debtId,
                                  max: st.interestOutstanding,
                                  target: 'interest',
                                  rec: rec,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Sp.x3),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.account_balance_wallet),
                            label: Text(
                              rec ? 'Principal received' : 'Principal paid',
                            ),
                            onPressed: () => showSheet(
                              context,
                              (_) => _RepaymentSheet(
                                debtId: debtId,
                                max: st.principalOutstanding,
                                target: 'principal',
                                rec: rec,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
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
                        st.outstanding == 0 ? 'Settled' : 'Outstanding',
                        style: context.text.labelLarge?.copyWith(
                          color: context.cash.textMuted,
                        ),
                      ),
                      MoneyText(
                        st.outstanding,
                        color: color,
                        style: context.text.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Sp.x4),
                      _Row('Principal lent/borrowed', debt.principalMinor),
                      _Row('Interest accrued', st.totalAccrued),
                      _Row('Repaid so far', st.totalPaid),
                      const Divider(height: Sp.x6),
                      _Row('Principal outstanding', st.principalOutstanding),
                      _Row('Interest outstanding', st.interestOutstanding),
                      if (debt.interestEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: Sp.x2),
                          child: Text(
                            _rateWords(debt),
                            style: context.text.bodySmall?.copyWith(
                              color: context.cash.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                        FutureBuilder<NextInterest?>(
                          future: repo.nextInterest(debtId),
                          builder: (context, snap) {
                            final n = snap.data;
                            if (n == null) return const SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: Sp.x3),
                              padding: const EdgeInsets.all(Sp.x3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(Sp.rChip),
                              ),
                              child: Text(
                                'Next interest: ${Money.format(n.amountMinor)} on ${DateFormat('d MMM y').format(n.date)}',
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SectionTitle('History'),
              Card(
                child: Column(
                  children: [for (final e in tl) _EventTile(e, rec: rec)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "2% every month on the money still owed" in plain words.
String _rateWords(Debt d) {
  final pct = (d.rateBps / 100).toStringAsFixed(d.rateBps % 100 == 0 ? 0 : 2);
  final every = switch (d.ratePeriod) {
    'daily' => 'every day',
    'weekly' => 'every week',
    'yearly' => 'every year',
    _ => 'every month',
  };
  final on = d.interestType == 'compound'
      ? 'on the principal plus the interest not yet paid'
      : 'on the principal still owed';
  return '$pct% $every $on. Interest is added once each period is complete.';
}

class _Row extends StatelessWidget {
  final String label;
  final int minor;
  const _Row(this.label, this.minor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.cash.textMuted)),
        ),
        MoneyText(minor, style: context.text.bodyMedium),
      ],
    ),
  );
}

class _EventTile extends ConsumerWidget {
  final DebtEvent e;
  final bool rec;
  const _EventTile(this.e, {required this.rec});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, label) = switch (e.type) {
      'issue' => (
        rec ? Icons.north_east : Icons.south_west,
        rec ? 'Lent' : 'Borrowed',
      ),
      'accrual' => (Icons.percent, 'Interest accrued'),
      'repayment' => (
        e.target == 'interest' ? Icons.percent : Icons.payments_outlined,
        e.target == 'interest'
            ? (rec ? 'Interest received' : 'Interest paid')
            : e.target == 'principal'
            ? (rec ? 'Principal received' : 'Principal paid')
            : (rec ? 'Payment received' : 'Repayment made'),
      ),
      'writeoff' => (Icons.remove_circle_outline, 'Written off'),
      _ => (Icons.circle, e.type),
    };
    final detail = e.type == 'repayment' && (e.interestPart > 0)
        ? 'Interest ${Money.format(e.interestPart)} · Principal ${Money.format(e.principalPart)}'
        : DateFormat('d MMM y').format(Dates.parse(e.date));
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        e.type == 'repayment' && e.interestPart > 0
            ? '${DateFormat('d MMM y').format(Dates.parse(e.date))} · $detail'
            : detail,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrailingMoney(e.amountMinor, style: context.text.bodyMedium),
          if (e.type == 'repayment' || e.type == 'writeoff')
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(repoProvider).deleteDebtEvent(e.id),
            ),
        ],
      ),
    );
  }
}

class _RepaymentSheet extends ConsumerStatefulWidget {
  final String debtId;
  final bool writeOff;
  final int max;

  /// null = interest first then principal, or 'interest' / 'principal'.
  final String? target;
  final bool rec;
  const _RepaymentSheet({
    required this.debtId,
    this.writeOff = false,
    required this.max,
    this.target,
    this.rec = true,
  });
  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  late final _amount = TextEditingController();
  DateTime date = Dates.today();
  String? error;

  Future<void> _save() async {
    final amt = Money.parse(_amount.text);
    if (amt == null || amt <= 0) {
      return setState(() => error = 'Enter a valid amount');
    }
    try {
      await ref
          .read(repoProvider)
          .addRepayment(
            widget.debtId,
            amt,
            date: date,
            writeOff: widget.writeOff,
            target: widget.target,
          );
      if (mounted) Navigator.pop(context);
    } on OverpaymentException catch (e) {
      setState(
        () => error =
            'That is ${Money.format(e.excessMinor)} more than is outstanding.',
      );
    } on ValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.writeOff
                ? 'Write off'
                : widget.target == 'interest'
                ? (widget.rec ? 'Interest received' : 'Interest paid')
                : widget.target == 'principal'
                ? (widget.rec ? 'Principal received' : 'Principal paid')
                : 'Record payment',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.target == 'interest'
                ? (widget.max > 0
                      ? 'Interest due now: ${Money.format(widget.max)}. This does not reduce the principal.'
                      : 'No interest is due yet. It is added at the end of each period; see "Next interest" on the debt screen.')
                : widget.target == 'principal'
                ? 'Principal left: ${Money.format(widget.max)}. This does not touch the interest owed, and it lowers the interest from the next period.'
                : 'Applied to interest first, then principal. Outstanding: ${Money.format(widget.max)}',
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Sp.x4),
          AmountField(controller: _amount, autofocus: true),
          const SizedBox(height: Sp.x3),
          Wrap(
            spacing: Sp.x2,
            children: [
              ActionChip(
                label: const Text('Full amount'),
                onPressed: () =>
                    _amount.text = (widget.max / 100).toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(DateFormat('d MMM y').format(date)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (p != null) setState(() => date = Dates.fromLocal(p));
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x3),
              child: Text(
                error!,
                style: TextStyle(color: context.cash.spending),
              ),
            ),
          const SizedBox(height: Sp.x4),
          FilledButton(
            onPressed: widget.target == 'interest' && widget.max <= 0
                ? null
                : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

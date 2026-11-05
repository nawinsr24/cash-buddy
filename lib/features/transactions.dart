import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  /// When pushed from elsewhere (e.g. a dashboard drill-down) it shows a back
  /// button and applies [initial] locally instead of the shared tab filter.
  final bool standalone;
  final TxnFilter? initial;
  const TransactionsPage({super.key, this.standalone = false, this.initial});
  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(txnFilterProvider.notifier).set(widget.initial!),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(txnFilterProvider);
    final txns = ref.watch(transactionsProvider);
    final cats = {
      for (final c in ref.watch(categoriesProvider).value ?? <Category>[])
        c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? <Account>[]) a.id: a,
    };
    final settings = ref.watch(settingsProvider).value;
    final active = !filter.isEmpty;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // A drill-down must not leave its filter on the Transactions tab.
        if (didPop && widget.standalone) {
          ref.read(txnFilterProvider.notifier).set(const TxnFilter());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transactions'),
          actions: [
            IconButton(
              tooltip: 'Filters',
              icon: Badge(
                isLabelVisible: active,
                smallSize: 8,
                child: const Icon(Icons.tune),
              ),
              onPressed: () => showSheet(context, (_) => const _FilterSheet()),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x3),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search notes and merchants',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _setQuery('');
                          },
                        ),
                ),
                onChanged: _setQuery,
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add transaction',
          onPressed: () => showTransactionSheet(context),
          child: const Icon(Icons.add),
        ),
        body: txns.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => ErrorState(e),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: active
                    ? 'No matching transactions'
                    : 'No transactions yet',
                body: active
                    ? 'Try clearing filters.'
                    : 'Tap + to add your first one.',
                action: active
                    ? OutlinedButton(
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(txnFilterProvider.notifier)
                              .set(const TxnFilter());
                        },
                        child: const Text('Clear filters'),
                      )
                    : null,
              );
            }
            // flatten into day headers + rows
            final items = <Object>[];
            String? last;
            for (final t in list) {
              if (t.date != last) {
                items.add(t.date);
                last = t.date;
              }
              items.add(t);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 96),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                if (it is String) {
                  return _DayHeader(
                    it,
                    list.where((t) => t.date == it).toList(),
                  );
                }
                final t = it as Transaction;
                return _TxnTile(
                  txn: t,
                  category: cats[t.categoryId],
                  parent: cats[cats[t.categoryId]?.parentId],
                  account: accounts[t.accountId],
                  toAccount: accounts[t.toAccountId],
                  showAccount: settings?.split ?? false,
                  showMethod: settings?.cashCard ?? false,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _setQuery(String q) {
    setState(() {});
    final f = ref.read(txnFilterProvider);
    ref
        .read(txnFilterProvider.notifier)
        .set(
          TxnFilter(
            query: q.isEmpty ? null : q,
            type: f.type,
            categoryId: f.categoryId,
            accountId: f.accountId,
            paymentMethod: f.paymentMethod,
            source: f.source,
            range: f.range,
            minMinor: f.minMinor,
            maxMinor: f.maxMinor,
          ),
        );
  }
}

class _DayHeader extends StatelessWidget {
  final String date;
  final List<Transaction> txns;
  const _DayHeader(this.date, this.txns);
  @override
  Widget build(BuildContext context) {
    final d = Dates.parse(date);
    final today = Dates.today();
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('EEE, d MMM y').format(d);
    var net = 0;
    for (final t in txns) {
      if (t.source == 'debt') continue;
      if (t.type == 'credit') net += t.amountMinor;
      if (t.type == 'debit') net -= t.amountMinor;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x5, Sp.x1, Sp.x2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
          ),
          TrailingMoney(
            net,
            signed: true,
            style: context.text.labelLarge?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends ConsumerWidget {
  final Transaction txn;
  final Category? category;
  final Category? parent;
  final Account? account;
  final Account? toAccount;
  final bool showAccount;
  final bool showMethod;
  const _TxnTile({
    required this.txn,
    this.category,
    this.parent,
    this.account,
    this.toAccount,
    required this.showAccount,
    required this.showMethod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cash;
    final isCredit = txn.type == 'credit';
    final isTransfer = txn.type == 'transfer';
    final managed = txn.source == 'debt' || txn.source == 'interest';
    final color = isTransfer
        ? context.scheme.primary
        : (isCredit ? c.income : c.spending);
    final catName = isTransfer
        ? 'Transfer'
        : category == null
        ? (txn.source == 'debt' ? 'Debt' : 'Uncategorised')
        : (parent != null
              ? '${parent!.name} › ${category!.name}'
              : category!.name);
    final subtitle = [
      catName,
      if (txn.merchant != null && txn.merchant!.isNotEmpty) txn.merchant!,
      if (isTransfer && account != null && toAccount != null)
        '${account!.name} → ${toAccount!.name}'
      else if (showAccount && account != null)
        account!.name,
      if (showMethod && txn.paymentMethod != null) txn.paymentMethod!,
      if (txn.source == 'sms') 'SMS',
    ].join(' · ');
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x2),
      leading: CircleAvatar(
        backgroundColor:
            (category != null ? colorOf(category!.colorValue) : color)
                .withValues(alpha: 0.16),
        child: Icon(
          isTransfer
              ? Icons.swap_horiz
              : (managed
                    ? Icons.handshake_outlined
                    : (isCredit ? Icons.south_west : Icons.north_east)),
          color: category != null ? colorOf(category!.colorValue) : color,
          size: 20,
        ),
      ),
      title: Text(
        txn.note.isNotEmpty ? txn.note : catName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: TrailingMoney(
        txn.amountMinor,
        color: isTransfer ? null : color,
        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: managed
          ? () =>
                toast(context, 'Managed by a debt — edit it from the Debts tab')
          : () => showTransactionSheet(context, edit: txn),
    );
    if (managed) return tile;
    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Sp.x6),
        color: c.spending.withValues(alpha: 0.9),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        final repo = ref.read(repoProvider);
        await repo.deleteTransaction(txn.id);
        if (context.mounted) {
          toast(
            context,
            'Transaction deleted',
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.restoreTransaction(txn.id),
            ),
          );
        }
      },
      child: tile,
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TxnFilter f = ref.read(txnFilterProvider);
  late final _min = TextEditingController(
    text: f.minMinor == null ? '' : (f.minMinor! / 100).toString(),
  );
  late final _max = TextEditingController(
    text: f.maxMinor == null ? '' : (f.maxMinor! / 100).toString(),
  );

  TxnFilter _copy({
    String? type,
    String? cat,
    String? acc,
    String? pm,
    String? src,
    DateRange? range,
    bool clearType = false,
    bool clearCat = false,
    bool clearAcc = false,
    bool clearPm = false,
    bool clearSrc = false,
    bool clearRange = false,
  }) => TxnFilter(
    query: f.query,
    type: clearType ? null : (type ?? f.type),
    categoryId: clearCat ? null : (cat ?? f.categoryId),
    accountId: clearAcc ? null : (acc ?? f.accountId),
    paymentMethod: clearPm ? null : (pm ?? f.paymentMethod),
    source: clearSrc ? null : (src ?? f.source),
    range: clearRange ? null : (range ?? f.range),
    minMinor: f.minMinor,
    maxMinor: f.maxMinor,
  );

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final settings = ref.watch(settingsProvider).value;
    final mains = cats.where((c) => c.parentId == null).toList();
    Widget chips<T>(
      String title,
      List<(String, String?)> opts,
      String? current,
      ValueChanged<String?> on,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.x4, bottom: Sp.x2),
          child: Text(title, style: context.text.labelLarge),
        ),
        Wrap(
          spacing: Sp.x2,
          children: [
            for (final o in opts)
              ChoiceChip(
                label: Text(o.$1),
                selected: current == o.$2,
                onSelected: (_) => on(o.$2),
              ),
          ],
        ),
      ],
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            chips(
              'Type',
              [
                ('All', null),
                ('Spending', 'debit'),
                ('Income', 'credit'),
                ('Transfers', 'transfer'),
              ],
              f.type,
              (v) => setState(() => f = _copy(type: v, clearType: v == null)),
            ),
            chips(
              'Category',
              [('All', null), for (final c in mains) (c.name, c.id)],
              f.categoryId,
              (v) => setState(() => f = _copy(cat: v, clearCat: v == null)),
            ),
            if ((settings?.split ?? false) && accounts.length > 1)
              chips(
                'Account',
                [('All', null), for (final a in accounts) (a.name, a.id)],
                f.accountId,
                (v) => setState(() => f = _copy(acc: v, clearAcc: v == null)),
              ),
            if (settings?.cashCard ?? false)
              chips(
                'Payment method',
                [('All', null), ('Cash', 'cash'), ('Card', 'card')],
                f.paymentMethod,
                (v) => setState(() => f = _copy(pm: v, clearPm: v == null)),
              ),
            chips(
              'Source',
              [
                ('All', null),
                ('Manual', 'manual'),
                ('SMS', 'sms'),
                ('Debt', 'debt'),
                ('Interest', 'interest'),
              ],
              f.source,
              (v) => setState(() => f = _copy(src: v, clearSrc: v == null)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Sp.x4, bottom: Sp.x2),
              child: Text('Date range', style: context.text.labelLarge),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                f.range == null
                    ? 'Any date'
                    : '${f.range!.startStr} → ${f.range!.endStr}',
              ),
              onPressed: () async {
                final p = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (p != null) {
                  setState(
                    () => f = _copy(
                      range: DateRange(
                        Dates.fromLocal(p.start),
                        Dates.fromLocal(p.end),
                      ),
                    ),
                  );
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: Sp.x4, bottom: Sp.x2),
              child: Text('Amount', style: context.text.labelLarge),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Min'),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Max'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () {
                      ref
                          .read(txnFilterProvider.notifier)
                          .set(const TxnFilter());
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(txnFilterProvider.notifier)
                          .set(
                            TxnFilter(
                              query: f.query,
                              type: f.type,
                              categoryId: f.categoryId,
                              accountId: f.accountId,
                              paymentMethod: f.paymentMethod,
                              source: f.source,
                              range: f.range,
                              minMinor: Money.parse(_min.text),
                              maxMinor: Money.parse(_max.text),
                            ),
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit sheet. Keypad-first: the amount field is focused immediately.
Future<void> showTransactionSheet(
  BuildContext context, {
  Transaction? edit,
  String? initialType,
  SmsInboxData? sms,
}) => showSheet(
  context,
  (_) => _TxnForm(edit: edit, initialType: initialType, sms: sms),
);

class _TxnForm extends ConsumerStatefulWidget {
  final Transaction? edit;
  final String? initialType;

  /// A detected bank message. The form opens pre-filled from it, and saving
  /// marks the message as handled. Nothing is added until the user saves.
  final SmsInboxData? sms;
  const _TxnForm({this.edit, this.initialType, this.sms});
  @override
  ConsumerState<_TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends ConsumerState<_TxnForm> {
  late String type =
      widget.edit?.type ??
      widget.sms?.direction ??
      widget.initialType ??
      'debit';
  late final _amount = TextEditingController(
    text: widget.edit != null
        ? (widget.edit!.amountMinor / 100).toStringAsFixed(2)
        : widget.sms != null
        ? (widget.sms!.amountMinor / 100).toStringAsFixed(2)
        : '',
  );
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  late final _merchant = TextEditingController(
    text: widget.edit?.merchant ?? widget.sms?.merchant ?? '',
  );
  late String? categoryId = widget.edit?.categoryId;
  late String? accountId = widget.edit?.accountId;
  late String? toAccountId = widget.edit?.toAccountId;
  late String? method = widget.edit?.paymentMethod;
  late DateTime date = widget.edit != null
      ? Dates.parse(widget.edit!.date)
      : widget.sms != null
      ? Dates.parse(widget.sms!.date)
      : Dates.today();
  String? error;
  bool saving = false;

  Future<void> _save() async {
    final amt = Money.parse(_amount.text);
    if (amt == null || amt <= 0) {
      setState(() => error = 'Enter a valid amount');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final repo = ref.read(repoProvider);
    try {
      if (widget.sms != null) {
        await repo.confirmSms(
          widget.sms!.id,
          type: type,
          amountMinor: amt,
          accountId: accountId,
          categoryId: categoryId,
          paymentMethod: method,
          date: date,
          note: _note.text.trim(),
          merchant: _merchant.text.trim().isEmpty ? '' : _merchant.text.trim(),
        );
      } else if (widget.edit == null) {
        await repo.addTransaction(
          type: type,
          amountMinor: amt,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: type == 'transfer' ? null : categoryId,
          paymentMethod: method,
          date: date,
          note: _note.text.trim(),
          merchant: _merchant.text.trim().isEmpty
              ? null
              : _merchant.text.trim(),
        );
      } else {
        await repo.updateTransaction(
          widget.edit!.id,
          type: type,
          amountMinor: amt,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: type == 'transfer' ? null : categoryId,
          clearCategory: categoryId == null,
          paymentMethod: method,
          date: date,
          note: _note.text.trim(),
          merchant: _merchant.text.trim(),
        );
      }
      haptic();
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
    final settings = ref.watch(settingsProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? [];
    final cats = (ref.watch(categoriesProvider).value ?? [])
        .where((c) => c.kind == type)
        .toList();
    final split = settings?.split ?? false;
    final c = context.cash;
    final mains = cats.where((x) => x.parentId == null).toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sms != null
                  ? 'Review detected transaction'
                  : widget.edit == null
                  ? 'New transaction'
                  : 'Edit transaction',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sp.x4),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(value: 'debit', label: Text('Spent')),
                const ButtonSegment(value: 'credit', label: Text('Received')),
                if (split && widget.sms == null)
                  const ButtonSegment(
                    value: 'transfer',
                    label: Text('Transfer'),
                  ),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() {
                type = s.first;
                categoryId = null;
              }),
            ),
            const SizedBox(height: Sp.x4),
            AmountField(controller: _amount, autofocus: widget.edit == null),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x2),
                child: Text(error!, style: TextStyle(color: c.spending)),
              ),
            if (type != 'transfer') ...[
              const SizedBox(height: Sp.x4),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Uncategorised'),
                  ),
                  for (final m in mains) ...[
                    DropdownMenuItem(
                      value: m.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: colorOf(m.colorValue),
                          ),
                          const SizedBox(width: Sp.x2),
                          Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    for (final s in cats.where((x) => x.parentId == m.id))
                      DropdownMenuItem(
                        value: s.id,
                        child: Padding(
                          padding: const EdgeInsets.only(left: Sp.x6),
                          child: Text(s.name),
                        ),
                      ),
                  ],
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
            ],
            if (split) ...[
              const SizedBox(height: Sp.x4),
              DropdownButtonFormField<String>(
                initialValue:
                    accountId ??
                    (accounts.isNotEmpty ? accounts.first.id : null),
                decoration: InputDecoration(
                  labelText: type == 'transfer' ? 'From account' : 'Account',
                ),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => accountId = v),
              ),
              if (type == 'transfer') ...[
                const SizedBox(height: Sp.x4),
                DropdownButtonFormField<String>(
                  initialValue: toAccountId,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => toAccountId = v),
                ),
              ],
            ],
            if ((settings?.cashCard ?? false) && type != 'transfer') ...[
              const SizedBox(height: Sp.x4),
              Wrap(
                spacing: Sp.x2,
                children: [
                  for (final m in const ['cash', 'card'])
                    ChoiceChip(
                      label: Text(m == 'cash' ? 'Cash' : 'Card'),
                      selected: method == m,
                      onSelected: (s) => setState(() => method = s ? m : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Sp.x4),
            TextField(
              controller: _merchant,
              decoration: const InputDecoration(
                labelText: 'Merchant / person (optional)',
              ),
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: Sp.x3),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(DateFormat('EEE, d MMM y').format(date)),
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
            const SizedBox(height: Sp.x5),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(
                widget.sms != null
                    ? 'Add transaction'
                    : widget.edit == null
                    ? 'Add'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

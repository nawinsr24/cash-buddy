import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/card_repo.dart';
import '../data/db.dart';
import '../data/repo.dart';
import '../domain/card.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../l10n/l10n.dart';
import '../platform/app_lock.dart' show AppLockGate;
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'transactions.dart' show showTransactionSheet;

String _due(DateTime d) => DateFormat('d MMM').format(d);

/// The "Credit cards" tab of the Debts screen.
class CardsList extends ConsumerWidget {
  const CardsList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardStatusesProvider);
    return list.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => ErrorState(e),
      data: (cards) {
        if (cards.isEmpty) {
          return const EmptyState(
            icon: Icons.credit_card,
            title: 'No credit cards yet',
            body: 'Add a card to keep track of what you owe, when it is due and the interest if you pay late.',
          );
        }
        final owed = cards.fold<int>(0, (a, c) => a + c.owed);
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
                      'Card bills you owe',
                      style: context.text.labelLarge?.copyWith(
                        color: context.cash.textMuted,
                      ),
                    ),
                    MoneyText(
                      owed,
                      color: context.cash.liability,
                      style: context.text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            for (final (i, c) in cards.indexed)
              Reveal(index: i + 1, child: _CardTile(c)),
            const SizedBox(height: Sp.x2),
            Card(
              child: Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(cardBudgetModeProvider).value ?? 'pay';
                  return ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(tr('Card spending and my budget')),
                    subtitle: Text(
                      mode == 'swipe'
                          ? 'Reduces your budget when you swipe'
                          : 'Counts when you pay the bill',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showCardBudgetChoice(context),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardStatus c;
  const _CardTile(this.c);
  @override
  Widget build(BuildContext context) {
    final muted = context.cash.textMuted;
    final late = c.overdue;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Pressable(
        onTap: () => pushReveal(context, CardPage(cardId: c.id)),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💳', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Text(
                        c.last4 == null || c.last4!.isEmpty
                            ? c.name
                            : '${c.name} ••${c.last4}',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          c.owed,
                          color: context.cash.liability,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x2),
                if (c.limit != null && c.limit! > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.used,
                      minHeight: 6,
                      backgroundColor: context.scheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                ],
                Text(
                  late
                      ? 'Overdue${c.interest > 0 ? ' · interest so far about ${Money.format(c.interest)}' : ''}'
                      : c.owed == 0
                      ? 'Nothing owed'
                      : c.nextDue != null
                      ? 'Due ${_due(c.nextDue!)}'
                      : 'No due date set',
                  style: context.text.bodySmall?.copyWith(
                    color: late ? context.cash.spending : muted,
                    fontWeight: late ? FontWeight.w700 : null,
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

/// One card: what you owe, the due date, interest, spends and payments.
class CardPage extends ConsumerWidget {
  final String cardId;
  const CardPage({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(cardStatusesProvider).value ?? const [];
    final c = statuses.where((x) => x.id == cardId).firstOrNull;
    final cards = ref.watch(cardsProvider).value ?? const <Account>[];
    final acct = cards.where((x) => x.id == cardId).firstOrNull;
    final activity = ref.watch(cardActivityProvider(cardId)).value ?? const [];
    final cats = {
      for (final x in ref.watch(categoriesProvider).value ?? <Category>[])
        x.id: x,
    };
    if (c == null || acct == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.credit_card,
          title: 'Card not found',
        ),
      );
    }
    final muted = context.cash.textMuted;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                await showSheet(context, (_) => AddCardSheet(edit: acct));
              } else if (v == 'delete') {
                await _remove(context, ref, c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit card')),
              PopupMenuItem(value: 'delete', child: Text('Remove card')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You owe',
                    style: context.text.labelLarge?.copyWith(color: muted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(
                      c.owed,
                      color: context.cash.liability,
                      style: context.text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  if (c.interest > 0) ...[
                    const SizedBox(height: Sp.x1),
                    Text(
                      'Interest so far: about ${Money.format(c.interest)} (an estimate)',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.cash.spending,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: Sp.x2),
                  Text(
                    c.owed == 0
                        ? 'Nothing owed right now.'
                        : c.overdue
                        ? 'Overdue. It was due on the ${acct.dueDay}${_suffix(acct.dueDay!)}.'
                        : c.nextDue != null
                        ? 'Due on ${_due(c.nextDue!)}'
                        : 'No due date set. Edit the card to add one.',
                    style: context.text.bodyMedium?.copyWith(color: muted),
                  ),
                  if (c.limit != null && c.limit! > 0) ...[
                    const SizedBox(height: Sp.x3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.used,
                        minHeight: 8,
                        backgroundColor: context.scheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      '${Money.format(c.owed)} of ${Money.format(c.limit!)} limit used',
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: c.owed == 0
                      ? null
                      : () => showSheet(context, (_) => PayBillSheet(card: c)),
                  child: Text(tr('Mark bill paid')),
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => showTransactionSheet(
                    context,
                    initialType: 'debit',
                    accountId: cardId,
                  ),
                  child: Text(tr('Add a spend')),
                ),
              ),
            ],
          ),
          SectionTitle(tr('Recent')),
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text('No spends yet.', style: TextStyle(color: muted)),
            ),
          for (final t in activity)
            _ActivityRow(
              t,
              cat: cats[t.categoryId],
              isPayment: t.type == 'transfer',
            ),
        ],
      ),
    );
  }

  String _suffix(int d) {
    if (d >= 11 && d <= 13) return 'th';
    return switch (d % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CardStatus c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove this card?'),
        content: Text(
          c.owed > 0
              ? 'You still owe ${Money.format(c.owed)} on it. Removing hides the card; your past entries stay.'
              : 'The card is hidden. Your past entries stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(repoProvider).updateCard(c.id, archived: true);
    if (context.mounted) Navigator.pop(context);
  }
}

class _ActivityRow extends StatelessWidget {
  final Transaction t;
  final Category? cat;
  final bool isPayment;
  const _ActivityRow(this.t, {this.cat, required this.isPayment});
  @override
  Widget build(BuildContext context) {
    final credit = t.type == 'credit' || isPayment;
    final title = isPayment
        ? 'Bill payment'
        : (t.merchant?.isNotEmpty ?? false)
        ? t.merchant!
        : cat?.name ?? 'No category';
    return Card(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      child: Padding(
        padding: const EdgeInsets.all(Sp.x3),
        child: Row(
          children: [
            Text(
              isPayment ? '✅' : emojiForCategory(cat?.name ?? ''),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, overflow: TextOverflow.ellipsis),
                  Text(
                    DateFormat('d MMM y').format(Dates.parse(t.date)),
                    style: context.text.bodySmall?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MoneyText(
                  t.amountMinor,
                  color: credit ? context.cash.income : null,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  signed: credit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a credit card.
class AddCardSheet extends ConsumerStatefulWidget {
  final Account? edit;
  const AddCardSheet({super.key, this.edit});
  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  late final name = TextEditingController(text: widget.edit?.name ?? '');
  late final bank = TextEditingController(text: widget.edit?.bank ?? '');
  late final last4 = TextEditingController(text: widget.edit?.last4 ?? '');
  late final limit = TextEditingController(
    text: widget.edit?.limitMinor == null
        ? ''
        : Money.edit(widget.edit!.limitMinor!, trimZeros: true),
  );
  late final dueDay = TextEditingController(
    text: widget.edit?.dueDay?.toString() ?? '',
  );
  late final owed = TextEditingController();
  late final rate = TextEditingController(
    text: (widget.edit?.interestBps ?? 0) == 0
        ? ''
        : (widget.edit!.interestBps / 100).toString().replaceFirst(
            RegExp(r'\.0$'),
            '',
          ),
  );
  late final grace = TextEditingController(
    text: (widget.edit?.graceDays ?? 0) == 0 ? '' : '${widget.edit!.graceDays}',
  );
  late String period = widget.edit?.ratePeriod ?? 'month';
  String? error;
  bool saving = false;

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    final day = int.tryParse(dueDay.text.trim());
    if (dueDay.text.trim().isNotEmpty && (day == null || day < 1 || day > 31)) {
      return setState(() => error = 'Due day must be between 1 and 31');
    }
    final lim = limit.text.trim().isEmpty ? null : Money.parse(limit.text);
    if (limit.text.trim().isNotEmpty && lim == null) {
      return setState(() => error = 'Enter the limit as a number');
    }
    final pct = rate.text.trim().isEmpty
        ? 0.0
        : double.tryParse(rate.text.trim());
    if (pct == null || pct < 0 || pct > 500) {
      return setState(() => error = 'Enter the interest rate as a number');
    }
    final bps = (pct * 100).round();
    final g = int.tryParse(grace.text.trim().isEmpty ? '0' : grace.text.trim());
    if (g == null || g < 0 || g > 365) {
      return setState(
        () => error = 'Enter the number of days as a whole number',
      );
    }
    final already = owed.text.trim().isEmpty ? 0 : Money.parse(owed.text);
    if (already == null) {
      return setState(() => error = 'Enter the amount owed as a number');
    }
    setState(() => saving = true);
    try {
      if (widget.edit == null) {
        final first = (await repo.cards()).isEmpty;
        await repo.addCard(
          name: name.text,
          bank: bank.text.trim().isEmpty ? null : bank.text.trim(),
          last4: last4.text.trim().isEmpty ? null : last4.text.trim(),
          limitMinor: lim,
          dueDay: day,
          interestBps: bps,
          ratePeriod: period,
          graceDays: g,
          owedMinor: already,
        );
        if (first) {
          // the due-date reminders need notifications to be allowed
          AppLockGate.holdOff();
          await Notifications.instance.requestPermission();
        }
      } else {
        await repo.updateCard(
          widget.edit!.id,
          name: name.text.trim(),
          bank: bank.text.trim(),
          last4: last4.text.trim(),
          limitMinor: lim,
          clearLimit: lim == null,
          dueDay: day,
          interestBps: bps,
          ratePeriod: period,
          graceDays: g,
        );
      }
      await refreshCardReminders(repo);
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
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.edit == null ? 'Add a credit card' : 'Edit card',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x4),
            TextField(
              controller: name,
              autofocus: widget.edit == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Card name')),
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: bank,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Bank (optional)'),
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: digits,
              decoration: const InputDecoration(
                labelText: 'Last 4 digits (optional)',
                helperText: 'Helps match bank alerts to this card',
                counterText: '',
              ),
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: limit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(Money.inputPattern),
              ],
              decoration: InputDecoration(
                labelText: 'Credit limit (optional)',
                prefixText: '${Money.symbol} ',
              ),
            ),
            if (widget.edit == null) ...[
              const SizedBox(height: Sp.x3),
              TextField(
                controller: owed,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(Money.inputPattern),
                ],
                decoration: InputDecoration(
                  labelText: 'Already owed on this card (optional)',
                  prefixText: '${Money.symbol} ',
                ),
              ),
            ],
            const SizedBox(height: Sp.x3),
            TextField(
              controller: dueDay,
              keyboardType: TextInputType.number,
              maxLength: 2,
              inputFormatters: digits,
              decoration: const InputDecoration(
                labelText: 'Bill due on (day of the month)',
                helperText: 'For example 25. Used for reminders.',
                counterText: '',
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              tr('Interest if you pay late'),
              style: context.text.titleSmall,
            ),
            const SizedBox(height: Sp.x2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: period == 'year'
                          ? 'Interest rate (% per year)'
                          : 'Interest rate (% per month)',
                    ),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'month', label: Text(tr('Month'))),
                    ButtonSegment(value: 'year', label: Text(tr('Year'))),
                  ],
                  selected: {period},
                  onSelectionChanged: (v) => setState(() => period = v.first),
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: grace,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(
                labelText: 'Interest starts after (days past due date)',
                helperText: 'Leave empty if it starts right after the due date',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.x2),
                child: Text(
                  error!,
                  style: TextStyle(color: context.cash.spending),
                ),
              ),
            const SizedBox(height: Sp.x4),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: saving ? null : _save,
              child: Text(widget.edit == null ? 'Add card' : tr('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pays a card bill from one of your accounts.
class PayBillSheet extends ConsumerStatefulWidget {
  final CardStatus card;
  const PayBillSheet({super.key, required this.card});
  @override
  ConsumerState<PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<PayBillSheet> {
  late final amount = TextEditingController(
    text: Money.edit(widget.card.toPay),
  );
  String? from;
  late DateTime date = ref.read(repoProvider).today;
  String? error;
  bool saving = false;

  Future<void> _save(List<Account> accounts) async {
    final amt = Money.parse(amount.text);
    if (amt == null || amt <= 0) {
      return setState(() => error = 'Enter a valid amount');
    }
    final account = from ?? (accounts.isNotEmpty ? accounts.first.id : null);
    if (account == null) {
      return setState(() => error = 'Choose where it was paid from');
    }
    setState(() => saving = true);
    try {
      final repo = ref.read(repoProvider);
      await repo.payCardBill(
        cardId: widget.card.id,
        amountMinor: amt,
        fromAccountId: account,
        date: date,
      );
      await refreshCardReminders(repo);
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
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final c = widget.card;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark bill paid',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              c.interest > 0
                  ? 'You owe ${Money.format(c.owed)}, plus about ${Money.format(c.interest)} interest. Anything you pay above ${Money.format(c.owed)} is saved as card interest.'
                  : 'You owe ${Money.format(c.owed)}. It comes off the account you pay from.',
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: Sp.x4),
            AmountField(controller: amount, autofocus: true),
            const SizedBox(height: Sp.x3),
            DropdownButtonFormField<String>(
              initialValue:
                  from ?? (accounts.isNotEmpty ? accounts.first.id : null),
              decoration: InputDecoration(labelText: tr('Paid from')),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => from = v),
            ),
            const SizedBox(height: Sp.x3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(DateFormat('d MMM y').format(date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => date = Dates.fromLocal(d));
              },
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: context.cash.spending)),
            const SizedBox(height: Sp.x3),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: saving ? null : () => _save(accounts),
              child: Text(tr('Mark bill paid')),
            ),
          ],
        ),
      ),
    );
  }
}

/// "When you spend on a credit card, should it reduce your budget?"
Future<void> showCardBudgetChoice(BuildContext context) =>
    showSheet(context, (_) => const CardBudgetChoice());

class CardBudgetChoice extends ConsumerWidget {
  const CardBudgetChoice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(cardBudgetModeProvider).value ?? 'pay';
    Widget option(String value, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: InkWell(
        borderRadius: BorderRadius.circular(Sp.rCard),
        onTap: () => ref.read(repoProvider).setCardBudgetMode(value),
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            color: context.cash.surfaceRaised,
            borderRadius: BorderRadius.circular(Sp.rCard),
            border: Border.all(
              color: mode == value
                  ? context.scheme.primary
                  : context.scheme.outlineVariant,
              width: mode == value ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: context.text.bodySmall?.copyWith(
                        color: context.cash.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (mode == value)
                Icon(Icons.check_circle, color: context.scheme.primary),
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
              'When you spend on a credit card, should it reduce your budget?',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x4),
            option(
              'pay',
              'Not until I pay the bill',
              'Card spending does not touch your budget when you swipe. Your budget counts the bill when you pay it, and Home warns you before.',
            ),
            option(
              'swipe',
              'Right when I swipe',
              'Card spending reduces your budget the same day. Paying the bill later does not count again.',
            ),
          ],
        ),
      ),
    );
  }
}

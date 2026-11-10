import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../data/db.dart';
import '../data/repo.dart' show ValidationException;
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Moves money between a bank account and cash in hand (an ATM withdrawal or a
/// cash deposit). It is a transfer, so spending and income are untouched.
Future<void> showCashMoveSheet(
  BuildContext context, {
  required bool withdraw,
}) => showSheet(context, (_) => _CashMove(withdraw: withdraw));

class _CashMove extends ConsumerStatefulWidget {
  final bool withdraw;
  const _CashMove({required this.withdraw});
  @override
  ConsumerState<_CashMove> createState() => _CashMoveState();
}

class _CashMoveState extends ConsumerState<_CashMove> {
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime date = Dates.today();
  String? bankId;
  String? error;

  Future<void> _save(Account cash, List<Account> banks) async {
    final amt = Money.parse(amount.text);
    if (amt == null || amt <= 0) {
      setState(() => error = 'Enter a valid amount');
      return;
    }
    final bank = bankId ?? banks.first.id;
    try {
      await ref
          .read(repoProvider)
          .addTransaction(
            type: 'transfer',
            amountMinor: amt,
            accountId: widget.withdraw ? bank : cash.id,
            toAccountId: widget.withdraw ? cash.id : bank,
            date: date,
            note: note.text.trim().isEmpty
                ? (widget.withdraw ? 'Cash withdrawal' : 'Cash deposit')
                : note.text.trim(),
          );
      haptic();
      if (mounted) Navigator.pop(context);
    } on ValidationException catch (x) {
      setState(() => error = x.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? [];
    final bal = ref.watch(balancesProvider).value ?? const {};
    final cash = accounts.where((a) => a.kind == 'cash').firstOrNull;
    final banks = accounts.where((a) => a.kind == 'bank').toList();
    final title = widget.withdraw ? 'Withdraw cash' : 'Deposit cash';
    if (cash == null || banks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Sp.x6),
        child: Text(
          'Choose "Separate balances" in Settings to move money between bank and cash.',
          style: context.text.bodyLarge,
        ),
      );
    }
    final sel = banks.firstWhere(
      (b) => b.id == bankId,
      orElse: () => banks.first,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.withdraw ? '🏧' : '🏦'} $title',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              widget.withdraw
                  ? 'Takes money out of the bank into your cash in hand. Not counted as spending.'
                  : 'Puts cash back into the bank. Not counted as income.',
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
            const SizedBox(height: Sp.x4),
            AmountField(controller: amount, autofocus: true),
            const SizedBox(height: Sp.x3),
            if (banks.length > 1)
              DropdownButtonFormField<String>(
                initialValue: sel.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.withdraw ? 'From bank' : 'To bank',
                ),
                items: [
                  for (final b in banks)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => bankId = v),
              ),
            if (banks.length > 1) const SizedBox(height: Sp.x3),
            Text(
              '${sel.name}: ${Money.format(bal[sel.id] ?? 0)}   ·   ${cash.name}: ${Money.format(bal[cash.id] ?? 0)}',
              style: context.text.bodySmall?.copyWith(
                color: context.cash.textMuted,
              ),
            ),
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
              decoration: InputDecoration(labelText: tr('Note (optional)')),
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
              onPressed: () => _save(cash, banks),
              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}

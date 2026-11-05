import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/invest_repo.dart';
import '../data/repo.dart' show ValidationException;
import '../domain/dates.dart';
import '../domain/money.dart';
import '../providers.dart';
import '../ui/emoji.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// A field with its label printed above it, so the label can never sit on
/// top of what is typed.
class LabeledField extends StatelessWidget {
  final String label;
  final String? hint, help;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final String? prefix, suffix;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.help,
    this.keyboard,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.autofocus = false,
    this.formatters,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
        ),
      ),
      if (help != null)
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 5),
          child: Text(
            help!,
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
        ),
    ],
  );
}

final _moneyFormat = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];
final _qtyFormat = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
];
const _decimal = TextInputType.numberWithOptions(decimal: true);

class _Sheet extends StatelessWidget {
  final String emoji, title, subtitle;
  final List<Widget> children;
  const _Sheet({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x1),
          Text(
            subtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Sp.x4),
          ...children,
        ],
      ),
    ),
  );
}

Widget _gap([double h = Sp.x4]) => SizedBox(height: h);

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          alignment: Alignment.centerLeft,
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
          if (d != null) onPick(Dates.fromLocal(d));
        },
      ),
    ],
  );
}

/// "Take this money from my balance" with the account to take it from.
class _PayFrom extends ConsumerWidget {
  final bool take;
  final ValueChanged<bool> onTake;
  final String? accountId;
  final ValueChanged<String?> onAccount;
  const _PayFrom({
    required this.take,
    required this.onTake,
    required this.accountId,
    required this.onAccount,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final globalOn = settings?.investReducesBalance ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: globalOn && take,
          onChanged: globalOn ? onTake : null,
          title: const Text('Take this money from my balance'),
          subtitle: Text(
            globalOn
                ? (take
                      ? 'Your balance goes down by this amount.'
                      : 'Your balance stays the same (use for things you bought earlier).')
                : 'Switched off in Settings → Balance rules, so your balance will not change.',
          ),
        ),
        if ((settings?.split ?? false) &&
            accounts.length > 1 &&
            globalOn &&
            take) ...[
          _gap(Sp.x2),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'Pay from',
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DropdownButtonFormField<String?>(
            initialValue: accountId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Default account'),
              ),
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: onAccount,
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── stock ─────────────────────────
Future<void> showStockBuyForm(BuildContext context) =>
    showSheet(context, (_) => const _StockBuyForm());

class _StockBuyForm extends ConsumerStatefulWidget {
  const _StockBuyForm();
  @override
  ConsumerState<_StockBuyForm> createState() => _StockBuyFormState();
}

class _StockBuyFormState extends ConsumerState<_StockBuyForm> {
  final name = TextEditingController();
  final qty = TextEditingController();
  final price = TextEditingController();
  final today = TextEditingController();
  DateTime date = Dates.today();
  bool take = true;
  String? accountId, error;
  bool saving = false;

  double? get _q => double.tryParse(qty.text.trim());
  int? get _p => Money.parse(price.text);
  int? get _total => (_q != null && _p != null && _q! > 0 && _p! > 0)
      ? (_q! * _p!).round()
      : null;

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Enter the stock name');
      return;
    }
    if (_q == null || _q! <= 0) {
      setState(() => error = 'Enter how many shares you bought');
      return;
    }
    if (_p == null || _p! <= 0) {
      setState(() => error = 'Enter the price you paid for one share');
      return;
    }
    final t = today.text.trim().isEmpty ? null : Money.parse(today.text);
    if (today.text.trim().isNotEmpty && (t == null || t <= 0)) {
      return setState(() => error = 'Check today\'s price');
    }
    setState(() {
      saving = true;
      error = null;
    });
    final repo = ref.read(repoProvider);
    try {
      final id = await repo.createInvestment(
        kind: 'stock',
        name: name.text,
        accountId: accountId,
        startDate: date,
      );
      await repo.buyShares(
        id,
        units: _q!,
        pricePerUnitMinor: _p!,
        date: date,
        postToBalance: take,
      );
      if (t != null) await repo.setSharePrice(id, t);
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
  Widget build(BuildContext context) => _Sheet(
    emoji: emojiForInvestment('stock'),
    title: 'Add a stock',
    subtitle:
        'Enter what you bought: how many shares, and the price of one share.',
    children: [
      LabeledField(
        label: 'Stock name or symbol',
        controller: name,
        hint: 'For example TCS',
        capitalization: TextCapitalization.characters,
        autofocus: true,
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LabeledField(
              label: 'Number of shares',
              controller: qty,
              hint: '10',
              keyboard: _decimal,
              formatters: _qtyFormat,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: LabeledField(
              label: 'Price of 1 share',
              controller: price,
              hint: '2500',
              prefix: '₹ ',
              keyboard: _decimal,
              formatters: _moneyFormat,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      if (_total != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.x3),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Sp.x3),
            decoration: BoxDecoration(
              color: context.scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Sp.rChip),
            ),
            child: Text(
              'You pay ${Money.format(_total!)} in total',
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      _gap(),
      _DateButton(
        label: 'Bought on',
        date: date,
        onPick: (d) => setState(() => date = d),
      ),
      _gap(),
      LabeledField(
        label: 'Price of 1 share today (optional)',
        controller: today,
        hint: 'To see your profit or loss',
        prefix: '₹ ',
        keyboard: _decimal,
        formatters: _moneyFormat,
      ),
      _gap(),
      _PayFrom(
        take: take,
        onTake: (v) => setState(() => take = v),
        accountId: accountId,
        onAccount: (v) => setState(() => accountId = v),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.x2),
          child: Text(error!, style: TextStyle(color: context.cash.spending)),
        ),
      _gap(),
      FilledButton(
        onPressed: saving ? null : _save,
        child: const Text('Add stock'),
      ),
    ],
  );
}

/// Buy more, or sell, shares you already hold.
Future<void> showShareTradeSheet(
  BuildContext context,
  Investment inv, {
  required bool buy,
}) => showSheet(context, (_) => _ShareTrade(inv: inv, buy: buy));

class _ShareTrade extends ConsumerStatefulWidget {
  final Investment inv;
  final bool buy;
  const _ShareTrade({required this.inv, required this.buy});
  @override
  ConsumerState<_ShareTrade> createState() => _ShareTradeState();
}

class _ShareTradeState extends ConsumerState<_ShareTrade> {
  final qty = TextEditingController();
  late final price = TextEditingController();
  DateTime date = Dates.today();
  bool take = true;
  String? error;

  double? get _q => double.tryParse(qty.text.trim());
  int? get _p => Money.parse(price.text);

  Future<void> _save() async {
    if (_q == null || _q! <= 0) {
      setState(() => error = 'Enter how many shares');
      return;
    }
    if (_p == null || _p! <= 0) {
      setState(() => error = 'Enter the price of one share');
      return;
    }
    final repo = ref.read(repoProvider);
    try {
      if (widget.buy) {
        await repo.buyShares(
          widget.inv.id,
          units: _q!,
          pricePerUnitMinor: _p!,
          date: date,
          postToBalance: take,
        );
      } else {
        await repo.sellShares(
          widget.inv.id,
          units: _q!,
          pricePerUnitMinor: _p!,
          date: date,
          postToBalance: take,
        );
      }
      haptic();
      if (mounted) Navigator.pop(context);
    } on ValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final held = widget.inv.units ?? 0;
    final total = (_q != null && _p != null && _q! > 0 && _p! > 0)
        ? (_q! * _p!).round()
        : null;
    return _Sheet(
      emoji: widget.buy ? '🛒' : '💰',
      title: widget.buy
          ? 'Buy more ${widget.inv.name}'
          : 'Sell ${widget.inv.name}',
      subtitle:
          'You hold ${held == held.roundToDouble() ? held.round() : held} shares.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Number of shares',
                controller: qty,
                keyboard: _decimal,
                formatters: _qtyFormat,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: LabeledField(
                label: widget.buy
                    ? 'Buy price of 1 share'
                    : 'Sell price of 1 share',
                controller: price,
                prefix: '₹ ',
                keyboard: _decimal,
                formatters: _moneyFormat,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (total != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: Text(
              widget.buy
                  ? 'You pay ${Money.format(total)}'
                  : 'You receive ${Money.format(total)}',
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        _gap(),
        _DateButton(
          label: 'Date',
          date: date,
          onPick: (d) => setState(() => date = d),
        ),
        _gap(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: take,
          onChanged:
              (ref.watch(settingsProvider).value?.investReducesBalance ?? true)
              ? (v) => setState(() => take = v)
              : null,
          title: Text(
            widget.buy
                ? 'Take this money from my balance'
                : 'Add this money to my balance',
          ),
        ),
        if (error != null)
          Text(error!, style: TextStyle(color: context.cash.spending)),
        _gap(),
        FilledButton(
          onPressed: _save,
          child: Text(widget.buy ? 'Buy' : 'Sell'),
        ),
      ],
    );
  }
}

Future<void> showSharePriceSheet(BuildContext context, Investment inv) =>
    showSheet(context, (_) => _SharePrice(inv: inv));

class _SharePrice extends ConsumerStatefulWidget {
  final Investment inv;
  const _SharePrice({required this.inv});
  @override
  ConsumerState<_SharePrice> createState() => _SharePriceState();
}

class _SharePriceState extends ConsumerState<_SharePrice> {
  final price = TextEditingController();
  String? error;
  @override
  Widget build(BuildContext context) {
    final held = widget.inv.units ?? 0;
    final p = Money.parse(price.text);
    return _Sheet(
      emoji: '📈',
      title: 'Today\'s price',
      subtitle:
          'The price of one ${widget.inv.name} share today. We work out the rest.',
      children: [
        LabeledField(
          label: 'Price of 1 share',
          controller: price,
          prefix: '₹ ',
          keyboard: _decimal,
          formatters: _moneyFormat,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        if (p != null && p > 0)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: Text(
              'Your ${held == held.roundToDouble() ? held.round() : held} shares are worth ${Money.format((held * p).round())}',
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (error != null)
          Text(error!, style: TextStyle(color: context.cash.spending)),
        _gap(),
        FilledButton(
          onPressed: () async {
            if (p == null || p <= 0) {
              setState(() => error = 'Enter the price of one share');
              return;
            }
            await ref.read(repoProvider).setSharePrice(widget.inv.id, p);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save price'),
        ),
      ],
    );
  }
}

// ───────────────────────── mutual fund ─────────────────────────
Future<void> showFundForm(BuildContext context) =>
    showSheet(context, (_) => const _FundForm());

class _FundForm extends ConsumerStatefulWidget {
  const _FundForm();
  @override
  ConsumerState<_FundForm> createState() => _FundFormState();
}

class _FundFormState extends ConsumerState<_FundForm> {
  final name = TextEditingController();
  final amount = TextEditingController();
  final value = TextEditingController();
  bool sip = true;
  DateTime date = Dates.today();
  bool firstPaid = true;
  bool take = true;
  String? accountId, error;
  bool saving = false;

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Enter the fund name');
      return;
    }
    final amt = Money.parse(amount.text);
    if (amt == null || amt <= 0) {
      setState(
        () => error = sip
            ? 'Enter the monthly SIP amount'
            : 'Enter the amount you invested',
      );
      return;
    }
    final v = value.text.trim().isEmpty ? null : Money.parse(value.text);
    if (value.text.trim().isNotEmpty && (v == null || v < 0)) {
      setState(() => error = 'Check the current value');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final repo = ref.read(repoProvider);
    try {
      final id = await repo.createInvestment(
        kind: 'mutual_fund',
        name: name.text,
        accountId: accountId,
        startDate: date,
        currentValueMinor: v,
        sipMinor: amt,
        recurring: sip,
        cycle: sip ? 'monthly' : null,
        monthDay: sip ? date.day : null,
      );
      // the first payment is recorded now, so the balance really goes down
      if (!sip || (firstPaid && !date.isAfter(Dates.today()))) {
        await repo.addInvestmentEntry(
          id,
          type: 'contribute',
          amountMinor: amt,
          date: date,
          periodKey: sip ? 0 : null,
          postToBalance: take,
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
  Widget build(BuildContext context) => _Sheet(
    emoji: emojiForInvestment('mutual_fund'),
    title: 'Add a mutual fund',
    subtitle: 'Choose how you invest: every month (SIP) or one time.',
    children: [
      LabeledField(
        label: 'Fund name',
        controller: name,
        hint: 'For example Nifty 50 Index Fund',
        capitalization: TextCapitalization.words,
        autofocus: true,
      ),
      _gap(),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: true,
            label: Text('Monthly SIP'),
            icon: Icon(Icons.autorenew, size: 18),
          ),
          ButtonSegment(
            value: false,
            label: Text('One time'),
            icon: Icon(Icons.looks_one_outlined, size: 18),
          ),
        ],
        selected: {sip},
        onSelectionChanged: (v) => setState(() => sip = v.first),
      ),
      _gap(),
      LabeledField(
        label: sip ? 'Amount every month' : 'Amount you invested',
        controller: amount,
        hint: sip ? '5000' : '25000',
        prefix: '₹ ',
        keyboard: _decimal,
        formatters: _moneyFormat,
      ),
      _gap(),
      _DateButton(
        label: sip ? 'First SIP date' : 'Invested on',
        date: date,
        onPick: (d) => setState(() => date = d),
      ),
      if (sip) ...[
        Padding(
          padding: const EdgeInsets.only(top: Sp.x2),
          child: Text(
            'Repeats on day ${date.day} of every month. You tap Pay each month to record it.',
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
        ),
        if (!date.isAfter(Dates.today()))
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: firstPaid,
            onChanged: (v) => setState(() => firstPaid = v),
            title: const Text('First instalment already paid'),
            subtitle: const Text('Records it now.'),
          ),
      ],
      _gap(),
      LabeledField(
        label: 'What it is worth today (optional)',
        controller: value,
        hint: 'To see your profit or loss',
        prefix: '₹ ',
        keyboard: _decimal,
        formatters: _moneyFormat,
      ),
      _gap(),
      _PayFrom(
        take: take,
        onTake: (v) => setState(() => take = v),
        accountId: accountId,
        onAccount: (v) => setState(() => accountId = v),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.x2),
          child: Text(error!, style: TextStyle(color: context.cash.spending)),
        ),
      _gap(),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(sip ? 'Start SIP' : 'Add fund'),
      ),
    ],
  );
}

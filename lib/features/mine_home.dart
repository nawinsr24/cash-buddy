import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/theme.dart';

/// The icon for an account card.
IconData accountIcon(Account a) => switch (a.kind) {
  'cash' => Icons.payments_outlined,
  'card' => Icons.credit_card,
  _ => Icons.account_balance_outlined,
};

/// "Don't count this". Takes no space at all while home sharing is off.
class DontCountTile extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const DontCountTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(homeOnProvider).value != true) return const SizedBox.shrink();
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(tr('Don\'t count this')),
      subtitle: Text(
        tr('Not in the budget. Your partner won\'t see it.'),
        style: TextStyle(color: context.cash.textMuted),
      ),
    );
  }
}

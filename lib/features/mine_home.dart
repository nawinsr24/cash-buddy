import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/choice_cards.dart';
import '../ui/theme.dart';

/// The icon for an account card.
IconData accountIcon(Account a) => switch (a.kind) {
  'cash' => Icons.payments_outlined,
  'card' => Icons.credit_card,
  _ => Icons.account_balance_outlined,
};

/// Mine or Home. Takes no space at all while home sharing is off.
class MineHomeCards extends ConsumerWidget {
  final bool home;
  final ValueChanged<bool> onChanged;
  const MineHomeCards({super.key, required this.home, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(homeOnProvider).value != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChoiceCards<bool>(
            label: tr('Counts as'),
            value: home,
            onChanged: onChanged,
            choices: [
              Choice(false, tr('Mine'), Icons.person_outline),
              Choice(true, tr('Home'), Icons.home_outlined),
            ],
          ),
          if (home)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x2),
              child: Text(tr('Your partner will see this.')),
            ),
        ],
      ),
    );
  }
}

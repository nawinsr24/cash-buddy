import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/home_repo.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'group_keeper.dart';

/// Beside my balance, a swipe away: the partner's balance, or the switch that
/// offers mine.
class BalanceRow extends ConsumerWidget {
  final Widget mine;
  const BalanceRow({super.key, required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeMonthProvider).value;
    if (home == null) return mine;
    final width = MediaQuery.sizeOf(context).width - Sp.x4 * 2;
    final others = <Widget>[
      for (final p in home.partnerBalances) _Partner(p),
      if (home.partnerBalances.isEmpty) _Offer(home.showMyBalance),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // narrower than the screen, so the next card peeks in
            SizedBox(width: width * 0.9, child: mine),
            for (final card in others) ...[
              const SizedBox(width: Sp.x3),
              SizedBox(width: width * 0.8, child: card),
            ],
          ],
        ),
      ),
    );
  }
}

class _Partner extends StatelessWidget {
  final PartnerBalance p;
  const _Partner(this.p);

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: TextStyle(color: context.cash.textMuted)),
          FittedBox(
            child: MoneyText(
              p.amount,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            DateFormat('d MMM, h:mm a').format(p.at),
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Offer extends ConsumerWidget {
  final bool on;
  const _Offer(this.on);

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: EdgeInsets.zero,
    child: Center(
      child: SwitchListTile.adaptive(
        value: on,
        title: Text(tr('Show my balance to my partner')),
        subtitle: Text(
          tr(
            on
                ? "Waiting for your partner to switch it on."
                : 'Both must switch it on.',
          ),
        ),
        onChanged: (v) => setBalanceSharing(ref, v),
      ),
    ),
  );
}

/// Saves the choice and sends it to the partner.
Future<void> setBalanceSharing(WidgetRef ref, bool on) async {
  final repo = ref.read(repoProvider);
  final update = ref.read(groupUpdateProvider);
  await repo.showMyBalance(on);
  await update();
}

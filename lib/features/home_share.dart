import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../data/home_repo.dart';
import '../providers.dart';
import '../ui/theme.dart';
import 'group.dart';

/// The one small invitation, until it is closed or home sharing is set up.
class HomeInviteCard extends ConsumerWidget {
  const HomeInviteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(groupServiceProvider) == null) return const SizedBox.shrink();
    ref.watch(changesProvider);
    final repo = ref.watch(repoProvider);
    return FutureBuilder<bool>(
      future: () async {
        return await repo.homeMember() == null &&
            await repo.getSetting('homeCardClosed') != '1';
      }(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.x3),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Run a home together?'),
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Close'),
                        icon: const Icon(Icons.close),
                        onPressed: () => repo.setSetting('homeCardClosed', '1'),
                      ),
                    ],
                  ),
                  Text(tr('Share one budget with your partner.')),
                  const SizedBox(height: Sp.x3),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GroupPage()),
                    ),
                    child: Text(tr('Set it up')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

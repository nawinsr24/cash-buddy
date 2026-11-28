import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/account.dart';
import '../platform/google_identity.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'access_gate.dart';
import 'legal.dart';

/// Null in builds without a server: nothing about accounts is shown then.
final accountProvider = Provider<Account?>((ref) {
  final access = ref.watch(accessProvider);
  return access == null ? null : Account(access);
});

/// Signs in. The tick is asked for only if it was never given; with [have],
/// the token from a sign-in just made, Google is not shown again.
Future<bool> signInWithConsent(
  BuildContext context,
  Account account, {
  String? have,
}) async {
  final repo = account.access.repo;
  if (!await hasAgreed(repo)) {
    if (!context.mounted) return false;
    var ticked = false;
    final ok = await showSheet<bool>(
      context,
      (sheet) => StatefulBuilder(
        builder: (sheet, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConsentCheck(
                  value: ticked,
                  onChanged: (v) => set(() => ticked = v),
                ),
                const SizedBox(height: Sp.x3),
                FilledButton(
                  onPressed: ticked ? () => Navigator.pop(sheet, true) : null,
                  child: Text(tr('Continue')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return false;
    await recordAgreement(repo);
  }
  try {
    return await account.signIn(have: have);
  } on SignInProblem catch (e) {
    if (context.mounted) toast(context, tr(e.message));
    return false;
  }
}

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    if (account == null) return const SizedBox.shrink();
    // Rebuilds when settings are written.
    ref.watch(settingsProvider);
    return FutureBuilder<String?>(
      future: googleAccount(account.access.repo),
      builder: (context, snap) {
        final email = snap.data ?? '';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              email.isEmpty ? tr('Sign in with Google') : tr('Google account'),
            ),
            subtitle: Text(
              email.isEmpty ? tr('Needed only for a shared group') : email,
            ),
            trailing: email.isEmpty
                ? null
                : TextButton(
                    onPressed: () async {
                      // one account: signing out ends Drive backup too
                      await ref.read(syncServiceProvider).goOffline();
                      await account.signOut();
                      ref.invalidate(settingsProvider);
                    },
                    child: Text(tr('Sign out')),
                  ),
            onTap: email.isNotEmpty
                ? null
                : () async {
                    if (await signInWithConsent(context, account)) {
                      ref.invalidate(settingsProvider);
                    }
                  },
          ),
        );
      },
    );
  }
}

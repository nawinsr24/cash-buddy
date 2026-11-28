import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/account.dart';
import '../platform/google_identity.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'access_gate.dart';

/// Null in builds without a server: nothing about accounts is shown then.
final accountProvider = Provider<Account?>((ref) {
  final access = ref.watch(accessProvider);
  return access == null ? null : Account(access);
});

/// What the user agrees to before anything is sent.
Future<bool> askConsent(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Before you sign in')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in [
                'Our server stores your Google email, an ID for this phone and when it last connected.',
                'It does not receive your entries, balances or notes.',
                'It can turn off access to the app for an account or phone.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.x2),
                  child: Text(tr(line)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('I agree')),
          ),
        ],
      ),
    ) ??
    false;

/// Asks, then signs in. True once signed in. With [have], the token from a
/// sign-in just made, Google is not shown again.
Future<bool> signInWithConsent(
  BuildContext context,
  Account account, {
  String? have,
}) async {
  if (!await askConsent(context)) return false;
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

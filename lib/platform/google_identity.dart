/// The one Google account this app uses, for Drive backup and home sharing.
library;

import '../data/repo.dart';

/// The account in use, or empty.
Future<String> googleAccount(Repo repo) async {
  for (final key in ['googleEmail', 'accountEmail']) {
    final v = await repo.getSetting(key) ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// Records [email] as the account. Returns a message, and records nothing,
/// when the app already uses a different one.
Future<String?> useGoogleAccount(Repo repo, String? email) async {
  if (email == null || email.isEmpty) return null;
  final known = await googleAccount(repo);
  if (known.isNotEmpty && known.toLowerCase() != email.toLowerCase()) {
    return 'This app uses $known. Choose that account, or sign out in Settings first.';
  }
  await repo.setSetting('googleEmail', email);
  return null;
}

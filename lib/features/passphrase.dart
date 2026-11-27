import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../sync/vault.dart';

/// Backups no longer have passwords. This is only for data saved by an older
/// version that did: ask for that password once. False when dismissed.
Future<bool> askOldPassword(BuildContext context, Vault vault) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr('Old backup password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              'This was saved by an older version with a password. Enter it once.',
            ),
          ),
          TextField(controller: c, obscureText: true, autofocus: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(tr('OK')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    // replaces any earlier wrong entry
    await vault.clear();
    await vault.setPassphrase(c.text);
    return true;
  } on VaultException {
    return false;
  }
}

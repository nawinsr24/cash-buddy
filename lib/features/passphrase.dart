import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../sync/vault.dart';

/// Makes sure a backup passphrase exists before anything leaves the phone.
/// Returns true when one is set (already, or just now).
Future<bool> ensurePassphrase(BuildContext context, Vault vault) async {
  if (await vault.isSet) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PassphraseDialog(vault),
  );
  return ok == true;
}

class _PassphraseDialog extends StatefulWidget {
  final Vault vault;
  const _PassphraseDialog(this.vault);
  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _a = TextEditingController(), _b = TextEditingController();
  String? _error;
  bool _show = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_a.text != _b.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    try {
      await widget.vault.setPassphrase(_a.text);
      if (mounted) Navigator.pop(context, true);
    } on VaultException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Protect your backups')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your data is locked with a backup password before it leaves this phone. '
            'Write it down and keep it safe: if you forget it, nobody can recover your backup, not even us.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _a,
            obscureText: !_show,
            decoration: InputDecoration(labelText: tr('Backup password')),
          ),
          TextField(
            controller: _b,
            obscureText: !_show,
            decoration: InputDecoration(
              labelText: tr('Type it again'),
              errorText: _error,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('Show password')),
            value: _show,
            onChanged: (v) => setState(() => _show = v ?? false),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(tr('Cancel')),
      ),
      FilledButton(onPressed: _save, child: Text(tr('Save'))),
    ],
  );
}

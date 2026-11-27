import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../platform/reminders.dart';
import '../providers.dart';
import '../sync/backup_data.dart';
import '../sync/vault.dart';
import '../ui/widgets.dart';

/// The phone's own "save as" and "open" screens, replaceable in tests.
class FileDialogs {
  const FileDialogs();

  /// False when the user backed out.
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: name, bytes: bytes) != null;

  Future<Uint8List?> open() async =>
      (await FilePicker.pickFile())?.readAsBytes();
}

final fileDialogsProvider = Provider((ref) => const FileDialogs());

/// Saves a complete backup wherever the user chooses.
Future<void> saveBackup(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repoProvider);
  final dialogs = ref.read(fileDialogsProvider);
  var message = tr('Backup saved');
  try {
    final bytes = await buildBackup(repo);
    final day = DateFormat('yyyy-MM-dd').format(repo.today);
    // A browser download reports no location, so it cannot be told apart.
    if (!await dialogs.save('cashplusplus-$day.cbbackup', bytes)) return;
  } catch (_) {
    message = tr('The backup could not be saved.');
  }
  if (context.mounted) toast(context, message);
}

/// Replaces everything on this phone with a backup file, after asking.
Future<void> restoreFromFile(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repoProvider);
  final bytes = await ref.read(fileDialogsProvider).open();
  if (bytes == null || !context.mounted) return;
  final protected = Vault.isEncrypted(bytes);
  final password = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Replace everything on this phone?')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                'Entries on this phone that are not in the file will be lost.',
              ),
            ),
            if (protected)
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('Backup password')),
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
          child: Text(tr('Restore')),
        ),
      ],
    ),
  );
  if (ok != true) return;
  var message = tr('Backup restored');
  try {
    await restoreBackup(repo, bytes, passphrase: password.text);
    await refreshReminder(repo);
  } on VaultException catch (e) {
    message = e.message;
  } catch (_) {
    message = tr('This is not a backup file, or it is damaged.');
  }
  if (context.mounted) toast(context, message);
}

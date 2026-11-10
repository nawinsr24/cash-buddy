import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/repo.dart';
import 'vault.dart';

/// Writes a checksummed JSON snapshot of all synced data to the app's
/// documents folder (kept: the 5 most recent). Returns the file path.
Future<String?> createBackup(Repo repo, {Vault? vault}) async {
  final db = repo.db;
  Future<List<Map<String, dynamic>>> rows(Iterable<dynamic> l) async => [
    for (final x in l) (x as dynamic).toJson() as Map<String, dynamic>,
  ];
  final payload = jsonEncode({
    'app': 'cash-buddy',
    'schema': 1,
    'createdAt': repo.now().toUtc().toIso8601String(),
    'accounts': await rows(await db.select(db.accounts).get()),
    'categories': await rows(await db.select(db.categories).get()),
    'transactions': await rows(await db.select(db.transactions).get()),
    'debts': await rows(await db.select(db.debts).get()),
    'debt_events': await rows(await db.select(db.debtEvents).get()),
  });
  final dir = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'backups'),
  )..createSync(recursive: true);
  final name = 'backup-${DateTime.now().millisecondsSinceEpoch}.cbbackup';
  final file = File(p.join(dir.path, name));
  final body = utf8.encode(
    jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    }),
  );
  // Backup files are always encrypted when a passphrase is set.
  await file.writeAsBytes(
    vault != null && await vault.isSet ? await vault.encrypt(body) : body,
  );
  final all = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in all.take((all.length - 5).clamp(0, 1000))) {
    f.deleteSync();
  }
  return file.path;
}

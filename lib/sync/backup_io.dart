import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/repo.dart';
import 'backup_data.dart';
import 'vault.dart';

/// Writes a checksummed JSON snapshot of all synced data to the app's
/// documents folder (kept: the 5 most recent). Returns the file path.
Future<String?> createBackup(Repo repo, {Vault? vault}) async {
  final bytes = await buildBackup(repo, vault: vault);
  final dir = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'backups'),
  )..createSync(recursive: true);
  final name = 'backup-${DateTime.now().millisecondsSinceEpoch}.cbbackup';
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes);
  final all = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in all.take((all.length - 5).clamp(0, 1000))) {
    f.deleteSync();
  }
  return file.path;
}

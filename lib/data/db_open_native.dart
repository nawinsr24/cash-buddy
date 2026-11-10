import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db_crypto.dart';
import 'db_key.dart';

/// Opens the app database, encrypted with a key kept in the secure store.
/// An older plain database is encrypted in place the first time (with a
/// safety copy, see [encryptInPlace]); if that ever fails the old file keeps
/// working and the next launch tries again, so data is never lost.
QueryExecutor openAppDatabase() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'cash_buddy.sqlite');
  final key = await prepareDatabase(path, const SecureSecretStore());
  return NativeDatabase.createInBackground(
    File(path),
    setup: key == null ? null : (raw) => raw.execute("PRAGMA key = '$key'"),
  );
});

/// Returns the key to open [path] with, or null to open it plain (only when
/// encrypting an old file failed). Handles the first-run, upgrade and
/// lost-key cases.
@visibleForTesting
Future<String?> prepareDatabase(String path, SecretStore store) async {
  final key = await databaseKey(store);
  final f = File(path);
  if (!f.existsSync() || f.lengthSync() == 0) return key; // new install
  if (isPlainDatabase(path)) {
    return encryptInPlace(path, key) ? key : null; // upgrade from old version
  }
  try {
    openWithKey(path, key).close();
    return key;
  } catch (_) {
    // Encrypted with a key this phone no longer has (for example a restored
    // file). Keep it aside instead of deleting, and start clean: the data can
    // come back from the encrypted Drive sync.
    f.renameSync('$path.unreadable.${DateTime.now().millisecondsSinceEpoch}');
    return key;
  }
}

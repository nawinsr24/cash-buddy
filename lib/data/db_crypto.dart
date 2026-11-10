import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Opens [path] with [key] and proves the key is right by reading the schema.
/// Throws if the file is encrypted with another key or is not a database.
Database openWithKey(String path, String key) {
  final db = sqlite3.open(path);
  try {
    db.execute("PRAGMA key = '$key'");
    db.select('SELECT count(*) FROM sqlite_master');
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

/// True when [path] is a readable, unencrypted SQLite file.
bool isPlainDatabase(String path) {
  if (!File(path).existsSync() || File(path).lengthSync() == 0) return false;
  final db = sqlite3.open(path);
  try {
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } catch (_) {
    return false;
  } finally {
    db.close();
  }
}

/// Encrypts an existing plain database in place. The original is copied to
/// `<path>.plain.bak` first and only deleted once the encrypted file reopens
/// with the key and has the same number of tables. On any failure the original
/// is put back and `false` is returned, so no data is ever lost.
bool encryptInPlace(String path, String key) {
  final bak = File('$path.plain.bak');
  File(path).copySync(bak.path);
  try {
    final plain = sqlite3.open(path);
    final before = _tableCount(plain);
    plain.execute("PRAGMA rekey = '$key'");
    plain.close();
    final enc = openWithKey(path, key);
    final after = _tableCount(enc);
    enc.close();
    if (before != after) throw StateError('table count changed');
    bak.deleteSync();
    return true;
  } catch (_) {
    try {
      bak.copySync(path);
      bak.deleteSync();
    } catch (_) {}
    return false;
  }
}

int _tableCount(Database db) =>
    db
            .select(
              "SELECT count(*) AS n FROM sqlite_master WHERE type='table'",
            )
            .first['n']
        as int;

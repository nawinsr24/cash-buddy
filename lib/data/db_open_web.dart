import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Browser build: SQLite compiled to WASM on the main thread, persisted in
/// IndexedDB. Needs web/sqlite3.wasm. (Runs without web workers so it also
/// works in embedded webviews that block SharedWorkers.)
QueryExecutor openAppDatabase() => LazyDatabase(() async {
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  final fs = await IndexedDbFileSystem.open(dbName: 'cash_buddy');
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  return WasmDatabase(sqlite3: sqlite, path: '/cash_buddy.db', fileSystem: fs);
});

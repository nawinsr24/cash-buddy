import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/repo.dart';
import 'drive_remote.dart';
import 'sync_engine.dart';

/// Wires the sync engine to Google Drive and decides *when* to sync:
/// on foreground, and debounced after local changes. No polling, no timers
/// while idle (battery friendly). Only active in Online Mode.
class SyncService with WidgetsBindingObserver {
  final Repo repo;
  SyncService(this.repo);

  RemoteStore? _remote;
  Timer? _debounce;
  StreamSubscription<void>? _sub;
  bool _running = false;

  /// Test seam / alternative backends.
  void useRemote(RemoteStore r) => _remote = r;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _sub = repo.changes.listen((_) => _schedule());
    if (await repo.dataMode == 'online') {
      _remote ??= await DriveRemote.restore();
      unawaited(syncNow());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _debounce?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 45), () => unawaited(syncNow()));
  }

  /// Interactive: sign in, take a safety backup, enable Online Mode and merge.
  Future<SyncResult> goOnline() async {
    final remote = await DriveRemote.signIn();
    if (remote == null) return const SyncResult(0, 0, 0, 'Sign-in cancelled');
    await createBackup(repo);
    _remote = remote;
    await repo.setSetting('dataMode', 'online');
    return syncNow(force: true);
  }

  /// Stops syncing and keeps the local copy. Drive data is left untouched.
  Future<void> goOffline() async {
    _debounce?.cancel();
    await repo.setSetting('dataMode', 'offline');
    _remote = null;
    await DriveRemote.signOut();
  }

  Future<SyncResult> syncNow({bool force = false}) async {
    if (_running) return const SyncResult(0, 0, 0, 'Sync already running');
    if (!force && await repo.dataMode != 'online') {
      return const SyncResult(0, 0, 0);
    }
    final remote = _remote ??= await DriveRemote.restore();
    if (remote == null) {
      await repo.setSetting(
        'lastSyncError',
        'Signed out of Google. Sign in again from Settings.',
      );
      return const SyncResult(0, 0, 0, 'Not signed in');
    }
    _running = true;
    try {
      final device = await repo.getSetting('deviceId') ?? 'dev';
      return await SyncEngine(repo, remote, device).sync();
    } finally {
      _running = false;
    }
  }
}

/// Writes a checksummed JSON snapshot of all synced data to the app's
/// documents folder (kept: the 5 most recent). Returns the file path.
Future<String> createBackup(Repo repo) async {
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
  await file.writeAsString(
    jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    }),
  );
  final all = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in all.take((all.length - 5).clamp(0, 1000))) {
    f.deleteSync();
  }
  return file.path;
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repo.dart';
import 'backup.dart';
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
    final DriveRemote? remote;
    try {
      remote = await DriveRemote.signIn();
    } on DriveSignInException catch (e) {
      return SyncResult(0, 0, 0, e.message);
    }
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

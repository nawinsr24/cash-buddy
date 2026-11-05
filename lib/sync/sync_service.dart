import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repo.dart';
import 'backup.dart';
import 'drive_remote.dart';
import 'sync_engine.dart';

/// Wires the sync engine to Google Drive and decides *when* to sync:
/// on foreground, and debounced after local changes. No polling, no timers
/// while idle (battery friendly). Only active in Online Mode.
/// Interactive Google sign-in; returns the remote and the account's email,
/// or null if the user cancelled. Replaceable in tests.
typedef SignInFn = Future<({RemoteStore remote, String? email})?> Function();

Future<({RemoteStore remote, String? email})?> _googleSignIn() async {
  final r = await DriveRemote.signIn();
  return r == null ? null : (remote: r, email: r.email);
}

/// Outcome of signing in during first-run setup.
class SetupSignIn {
  final bool ok;
  final String? email, error;

  /// Cash++ data already exists in that Google account's Drive.
  final bool hasData;
  const SetupSignIn({
    required this.ok,
    this.email,
    this.error,
    this.hasData = false,
  });
}

class SyncService with WidgetsBindingObserver {
  final Repo repo;
  final SignInFn _signIn;
  SyncService(this.repo, {SignInFn? signIn})
    : _signIn = signIn ?? _googleSignIn;

  /// The account signed in during this session (display only).
  String? signedInEmail;

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
    final ({RemoteStore remote, String? email})? signed;
    try {
      signed = await _signIn();
    } on DriveSignInException catch (e) {
      return SyncResult(0, 0, 0, e.message);
    }
    if (signed == null) return const SyncResult(0, 0, 0, 'Sign-in cancelled');
    await createBackup(repo);
    _remote = signed.remote;
    signedInEmail = signed.email;
    await repo.setSetting('dataMode', 'online');
    return syncNow(force: true);
  }

  /// First-run setup: sign in right away and look for existing data. Changes
  /// nothing locally; Online Mode is only switched on by [finishSetupOnline]
  /// or [restoreFromDrive].
  Future<SetupSignIn> signInForSetup() async {
    try {
      final signed = await _signIn();
      if (signed == null) {
        return const SetupSignIn(ok: false, error: 'Sign-in was cancelled.');
      }
      final names = await signed.remote.list();
      _remote = signed.remote;
      signedInEmail = signed.email;
      return SetupSignIn(
        ok: true,
        email: signed.email,
        hasData: names.any((n) => n.startsWith('seg/')),
      );
    } on DriveSignInException catch (e) {
      return SetupSignIn(ok: false, error: e.message);
    } catch (e) {
      return SetupSignIn(
        ok: false,
        error: 'Could not reach your Google Drive: $e',
      );
    }
  }

  /// Setup finished as a new user: switch on Online Mode and merge in the
  /// background (nothing in Drive is overwritten or deleted).
  Future<SyncResult> finishSetupOnline() async {
    if (_remote == null) return const SyncResult(0, 0, 0, 'Not signed in');
    return syncNow(force: true);
  }

  /// Setup, returning user: pull everything from Drive and skip the wizard.
  /// Only marks the app set up when the data really arrived.
  Future<SyncResult> restoreFromDrive() async {
    if (_remote == null) return const SyncResult(0, 0, 0, 'Not signed in');
    await repo.setSetting('dataMode', 'online');
    final r = await syncNow(force: true);
    if (!r.ok) {
      await repo.setSetting('dataMode', 'offline');
      return r;
    }
    final accounts = await repo.accounts(includeArchived: true);
    final split = accounts.any((a) => a.kind == 'cash');
    await repo.setSetting('accountMode', split ? 'split' : 'combined');
    await repo.setSetting('onboarded', '1');
    return r;
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

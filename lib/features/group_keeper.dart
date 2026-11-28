import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repo.dart';
import '../data/repo.dart';
import '../sync/group/group_service.dart';
import '../platform/diag.dart';
import '../platform/push.dart';
import '../providers.dart';
import 'group.dart';

/// Sends my changes and fetches the partner's. A second round follows when
/// what arrived (consent to share balances, or a request to send again) gives
/// me more to send. Calls take turns, so two never work on the group at once.
Future<void> updateGroup(GroupService group, Repo repo) {
  final next = _turn.catchError((_) {}).then((_) async {
    await group.change(repo.publishHome);
    await group.sync();
    await group.change(repo.publishHome);
    if ((await group.open())!.disk.outbox.isNotEmpty) await group.sync();
    groupSynced.value++;
  });
  return _turn = next;
}

Future<void> _turn = Future.value();

/// For buttons: update now, ignoring being offline.
final groupUpdateProvider = Provider<Future<void> Function()>((ref) {
  final group = ref.watch(groupServiceProvider);
  final repo = ref.watch(repoProvider);
  return () async {
    if (group == null || await group.open() == null) return;
    try {
      await updateGroup(group, repo);
    } on GroupProblem {
      // sent at the next sync
    }
  };
});

final pushProvider = Provider((ref) => const Push());

/// Goes up each time the group has been synced in the background, so an open
/// group screen can redraw.
final groupSynced = ValueNotifier(0);

/// Keeps the group up to date: on opening the app, on coming back to it and
/// when a nudge arrives. Does nothing for people without a group.
class GroupKeeper extends ConsumerStatefulWidget {
  final Widget child;
  const GroupKeeper({super.key, required this.child});
  @override
  ConsumerState<GroupKeeper> createState() => _GroupKeeperState();
}

class _GroupKeeperState extends ConsumerState<GroupKeeper>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _nudges;
  var _busy = false;
  var _again = false;
  var _setUp = false;
  Timer? _check;
  StreamSubscription<void>? _spends;
  Timer? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_update());
    _startChecking();
    final db = ref.read(repoProvider).db;
    _spends = db.tableUpdates(TableUpdateQuery.onTable(db.transactions)).listen(
      (_) {
        if (ref.read(groupServiceProvider) == null) return;
        _later?.cancel();
        _later = Timer(const Duration(seconds: 3), _update);
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nudges?.cancel();
    _spends?.cancel();
    _later?.cancel();
    _check?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_update());
      _startChecking();
    } else if (state == AppLifecycleState.paused) {
      _check?.cancel();
    }
  }

  /// While the app is open, a signal that is late or lost is made up for by a
  /// small check. It also notices a home paired since the app started.
  void _startChecking() {
    _check?.cancel();
    _check = Timer.periodic(const Duration(seconds: 20), (_) async {
      final group = ref.read(groupServiceProvider);
      if (group == null || _busy) return;
      try {
        if (await group.open() == null) {
          _setUp = false;
        } else if (!_setUp || await group.hasNews()) {
          await _update();
        }
      } catch (_) {
        // offline: the next tick tries again
      }
    });
  }

  Future<void> _update() async {
    final group = ref.read(groupServiceProvider);
    if (group == null) return;
    // Something changed while a sync was running: run once more afterwards.
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      if (await group.open() == null) return;
      final push = ref.read(pushProvider);
      final token = await push.token();
      if (token == null) Diag.instance.log('home push not available');
      if (token != null) {
        await group.registerPush(token);
        _nudges ??= push.nudges.listen((_) => _update());
      }
      final repo = ref.read(repoProvider);
      await updateGroup(group, repo);
      _setUp = true;
      if (!mounted) return;
      ref.invalidate(budgetStatusProvider);
    } catch (e) {
      // offline or signed out: tried again next time
      Diag.instance.log(
        'home update skipped: ${e is GroupProblem ? e.message : e.runtimeType}',
      );
    } finally {
      _busy = false;
      if (_again && mounted) {
        _again = false;
        unawaited(_update());
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

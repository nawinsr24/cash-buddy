import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repo.dart';
import '../data/repo.dart';
import '../sync/group/group_service.dart';
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
  StreamSubscription<void>? _spends;
  Timer? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_update());
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_update());
  }

  Future<void> _update() async {
    final group = ref.read(groupServiceProvider);
    if (group == null || _busy) return;
    _busy = true;
    try {
      if (await group.open() == null) return;
      final push = ref.read(pushProvider);
      final token = await push.token();
      if (token != null) {
        await group.registerPush(token);
        _nudges ??= push.nudges.listen((_) => _update());
      }
      final repo = ref.read(repoProvider);
      await updateGroup(group, repo);
      if (!mounted) return;
      ref.invalidate(budgetStatusProvider);
    } catch (_) {
      // offline or signed out: tried again next time
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Creating, joining and using the one shared group.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/db_key.dart';
import '../../data/repo.dart';
import '../../platform/diag.dart';
import 'group_store.dart';
import 'http_post_box.dart';
import 'note.dart';
import 'replica.dart';

class GroupProblem implements Exception {
  final String message;
  GroupProblem(this.message);
  @override
  String toString() => message;
}

String _random(int bytes) {
  final r = Random.secure();
  return base64Url
      .encode([for (var i = 0; i < bytes; i++) r.nextInt(256)])
      .replaceAll('=', '');
}

class GroupService {
  final Repo repo;
  final SecretStore secrets;
  final Uri server;
  final Send send;
  final GroupStore _store;
  GroupService(
    this.repo, {
    required this.secrets,
    required this.server,
    this.send = sendHttp,
  }) : _store = GroupStore(repo);

  String? _groupId;
  Replica? _replica;

  /// Null when this phone is in no group.
  Future<Replica?> open() async {
    if (_replica != null) return _replica;
    final saved = await _store.load();
    if (saved == null) return null;
    _groupId = saved.$1;
    return _replica = Replica(saved.$2);
  }

  Future<String> _session() async {
    final s = await repo.getSetting('accountSession') ?? '';
    if (s.isEmpty) {
      _log('not signed in on this phone');
      throw GroupProblem('Sign in first.');
    }
    return s;
  }

  Future<HttpPostBox> _box() async {
    final key = await secrets.read('group_key');
    if (key == null || await open() == null) {
      throw GroupProblem('You are not in a group.');
    }
    return HttpPostBox(
      server: server,
      groupId: _groupId!,
      memberId: _replica!.disk.member,
      session: await _session(),
      key: base64Url.decode(base64Url.normalize(key)),
      send: send,
    );
  }

  /// Proves knowledge of the key without revealing it.
  static String _joinToken(String key) =>
      sha256.convert(utf8.encode('join:$key')).toString();

  Future<void> create(String myName) =>
      _enter('create', _random(16), _random(32), myName);

  /// [code] is what [inviteCode] gave on the other phone.
  Future<void> join(String code, String myName) async {
    final parts = code.trim().split('.');
    if (parts.length != 2 || parts[0].length < 8 || parts[1].length < 40) {
      throw GroupProblem('That invite code is not complete.');
    }
    try {
      base64Url.decode(base64Url.normalize(parts[1]));
    } on FormatException {
      throw GroupProblem('That invite code is not complete.');
    }
    await _enter('join', parts[0], parts[1], myName);
  }

  Future<void> _enter(String how, String id, String key, String name) async {
    if (name.trim().isEmpty) throw GroupProblem('Enter your name.');
    if (await open() != null) throw GroupProblem('You are already in a group.');
    final member = 'm${_random(9)}';
    final box = HttpPostBox(
      server: server,
      groupId: id,
      memberId: member,
      session: await _session(),
      key: base64Url.decode(base64Url.normalize(key)),
      send: send,
    );
    _log('$how: asking the server');
    await _guard(() => box.call(how, body: {'join': _joinToken(key)}));
    _log('$how: accepted');
    await secrets.write('group_key', key);
    _groupId = id;
    final replica = _replica = Replica(Disk(member));
    replica.put('member:$member', {'kind': 'member', 'name': name.trim()});
    await _store.save(id, replica.disk);
  }

  /// The code to show the person joining. Valid for a day.
  Future<String> inviteCode() async {
    final box = await _box();
    final key = (await secrets.read('group_key'))!;
    await _guard(() => box.call('invite', body: {'join': _joinToken(key)}));
    return '$_groupId.$key';
  }

  /// Sends and receives. Safe to call at any time.
  Future<void> sync() async {
    final box = await _box();
    final replica = _replica!;
    Future<void> save() => _store.save(_groupId!, replica.disk);
    final toSend = replica.disk.outbox.length;
    final had = replica.disk.notes.length;
    await _guard(() => replica.sync(box, step: save));
    await save();
    final me = replica.disk.member;
    final entries = replica.entries.values;
    _log(
      'sync ok: sent $toSend, received ${replica.disk.notes.length - had}, '
      'waiting to send ${replica.disk.outbox.length}, '
      'people ${ofKind(replica, 'member').length}, '
      'spends from partner '
      '${entries.where((e) => e.data['kind'] == 'expense' && e.data['paidBy'] != me).length}',
    );
  }

  /// Help and troubleshooting shows these. Counts and error codes only: never
  /// amounts, notes, names or codes. Repeats are logged once.
  static void _log(String line) {
    final text = 'home $line';
    final last = Diag.instance.lines.lastOrNull ?? '';
    if (!last.endsWith(text)) Diag.instance.log(text);
  }

  /// Tells the server where to nudge this phone.
  Future<void> registerPush(String token) async {
    final box = await _box();
    await _guard(() => box.call('push', body: {'token': token}));
    _log('push address registered');
  }

  /// Makes a change and saves it; it is sent at the next [sync].
  Future<void> change(FutureOr<void> Function(Replica group) edit) async {
    final replica = await open();
    if (replica == null) throw GroupProblem('You are not in a group.');
    await edit(replica);
    await _store.save(_groupId!, replica.disk);
  }

  /// Leaves and removes the group from this phone. Others keep their copy.
  Future<void> leave() async {
    final box = await _box();
    await _guard(() => box.call('leave', body: {}));
    await _store.clear();
    await secrets.delete('group_key');
    _replica = null;
    _groupId = null;
  }

  Future<void> _guard(Future<Object?> Function() work) async {
    try {
      await work();
    } on GroupServerException catch (e) {
      _log('server refused, code ${e.status}');
      throw GroupProblem(switch (e.status) {
        401 => 'Sign in again.',
        403 => 'This invite code is not valid.',
        409 => 'The group is full.',
        410 => 'This invite has expired. Ask for a new one.',
        _ => 'The server could not be reached. Try again later.',
      });
    } on GroupProblem {
      rethrow;
    } catch (e) {
      _log('failed: ${e.runtimeType}');
      throw GroupProblem('The server could not be reached. Try again later.');
    }
  }

  // ───────────── what is in the group ─────────────

  static Iterable<Entry> ofKind(Replica g, String kind) =>
      g.entries.values.where((e) => e.data['kind'] == kind);
}

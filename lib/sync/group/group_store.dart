/// Keeps a phone's side of the group in the encrypted database.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/db.dart';
import '../../data/repo.dart';
import 'replica.dart';

class GroupStore {
  final Repo repo;
  GroupStore(this.repo);

  /// What is already on disk: note id -> waiting to be sent.
  final _saved = <String, bool>{};

  /// Null when this phone is in no group.
  Future<(String groupId, Disk disk)?> load() async {
    final raw = await repo.getSetting('group');
    if (raw == null || raw.isEmpty) return null;
    final c = jsonDecode(raw) as Map<String, dynamic>;
    final rows = await repo.db.select(repo.db.groupNotes).get();
    _saved
      ..clear()
      ..addAll({for (final r in rows) r.id: r.pending});
    return (
      c['id'] as String,
      Disk(
        c['member'] as String,
        writer: c['writer'] as String,
        nextSeq: c['nextSeq'] as int,
        notes: {for (final r in rows) r.id: r.body},
        outbox: {
          for (final r in rows)
            if (r.pending) r.id,
        },
      ),
    );
  }

  /// Writes what changed, in one transaction.
  Future<void> save(String groupId, Disk disk) async {
    final db = repo.db;
    final changed = <String, bool>{};
    for (final id in disk.notes.keys) {
      final pending = disk.outbox.contains(id);
      if (_saved[id] != pending) changed[id] = pending;
    }
    await db.transaction(() async {
      for (final e in changed.entries) {
        await db
            .into(db.groupNotes)
            .insertOnConflictUpdate(
              GroupNotesCompanion.insert(
                id: e.key,
                body: disk.notes[e.key]!,
                pending: Value(e.value),
              ),
            );
      }
      await repo.setSetting(
        'group',
        jsonEncode({
          'id': groupId,
          'member': disk.member,
          'writer': disk.writer,
          'nextSeq': disk.nextSeq,
        }),
      );
    });
    _saved.addAll(changed);
  }

  Future<void> clear() async {
    await repo.db.transaction(() async {
      await repo.db.delete(repo.db.groupNotes).go();
      await repo.setSetting('group', '');
    });
    _saved.clear();
  }
}

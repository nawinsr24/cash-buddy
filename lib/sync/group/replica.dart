/// One phone's side of the shared group, and the post box it talks to.
library;

import '../../domain/hlc.dart';
import 'note.dart';

/// Carries sealed notes between phones. It never needs to read them.
abstract class PostBox {
  /// Returning means the note is safely held.
  Future<void> upload(String member, String noteId, String sealed);

  /// Notes waiting for [member].
  Future<List<String>> fetch(String member);

  Future<void> ack(String member, String noteId);

  /// Highest note number ever uploaded for each writer.
  Future<Map<String, int>> highest();

  /// Asks the other members to send these notes again.
  Future<void> request(String member, Map<String, List<int>> missing);

  /// What other members are asking [member] for.
  Future<List<Map<String, List<int>>>> requests(String member);
}

/// Everything a phone has saved. Each change to it stands for one database
/// transaction, so a crash can happen between changes but not inside one.
class Disk {
  final String member;
  String writer;
  int nextSeq;
  final Map<String, String> notes;
  final Set<String> outbox;
  Disk(
    this.member, {
    String? writer,
    this.nextSeq = 1,
    Map<String, String>? notes,
    Set<String>? outbox,
  }) : writer = writer ?? '$member.0',
       notes = notes ?? {},
       outbox = outbox ?? {};

  Disk copy() => Disk(
    member,
    writer: writer,
    nextSeq: nextSeq,
    notes: Map.of(notes),
    outbox: Set.of(outbox),
  );

  /// A restored backup. [freshWriter] must never have been used before
  /// (random in the app), so old note numbers cannot be reused.
  Disk restored(String freshWriter) => copy()
    ..writer = freshWriter
    ..nextSeq = 1;
}

class Replica {
  final Disk disk;
  final Hlc _clock;
  final int Function() _now;
  final Map<String, Note> _notes = {};
  Map<String, Entry>? _cache;

  Replica(this.disk, {int Function()? now})
    : _clock = Hlc(disk.writer, now: now),
      _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    for (final s in disk.notes.values) {
      final n = Note.decode(s);
      _notes[n.id] = n;
      _clock.observe(n.stamp);
    }
  }

  Map<String, Entry> get entries => _cache ??= entriesOf(_notes.values);
  int get total => totalMinor(entries);
  List<Change> history(String id) => historyOf(_notes.values, id);
  Set<String> get deleted => deletedEntries(_notes.values);
  Iterable<Note> get notes => _notes.values;
  bool get needsUpdate => _notes.values.any((n) => n.format > noteFormat);

  // ───────────── changes ─────────────

  /// Adds rows that are saved together or not at all. Several rows form a
  /// split, which is later deleted as one.
  List<String> add(List<Map<String, Object?>> rows) {
    final seq = disk.nextSeq;
    final ids = [
      for (var i = 0; i < rows.length; i++) '${disk.writer}:$seq/$i',
    ];
    _write([
      for (var i = 0; i < rows.length; i++)
        Op(ids[i], data: {...rows[i], if (rows.length > 1) 'split': ids}),
    ]);
    return ids;
  }

  /// Editing an entry that needs review also settles it.
  void edit(String id, Map<String, Object?> changes) {
    final e = entries[id];
    if (e == null) return;
    _write([
      Op(id, replaces: _headIds(e), data: {...e.data, ...changes}),
    ]);
  }

  /// Keeps one of the competing versions.
  void resolve(String id, int head) {
    final e = entries[id];
    if (e == null || !e.needsReview) return;
    _write([Op(id, replaces: _headIds(e), data: e.heads[head].data)]);
  }

  void delete(String id) {
    final e = entries[id];
    if (e == null) return;
    final split = (e.data['split'] as List?)?.cast<String>() ?? [id];
    _write([
      for (final part in split)
        Op(part, replaces: [...?entries[part]?.heads.map((v) => v.id)]),
    ]);
  }

  List<String> _headIds(Entry e) => [for (final v in e.heads) v.id];

  void _write(List<Op> ops) {
    final n = Note(
      writer: disk.writer,
      seq: disk.nextSeq,
      stamp: _clock.next(),
      at: _now(),
      ops: ops,
    );
    // One transaction: the note, its number and the outbox entry.
    disk.notes[n.id] = n.encode();
    disk.outbox.add(n.id);
    disk.nextSeq++;
    _notes[n.id] = n;
    _cache = null;
  }

  // ───────────── delivery ─────────────

  /// Safe to interrupt anywhere and run again. [step] is called between
  /// saved steps (tests crash there).
  Future<void> sync(PostBox box, {void Function()? step}) async {
    final pause = step ?? () {};
    for (final id in disk.outbox.toList()) {
      await box.upload(disk.member, id, disk.notes[id]!);
      pause();
      disk.outbox.remove(id);
      pause();
    }

    for (final sealed in await box.fetch(disk.member)) {
      final n = Note.decode(sealed);
      if (!disk.notes.containsKey(n.id)) {
        disk.notes[n.id] = sealed;
        _notes[n.id] = n;
        _clock.observe(n.stamp);
        _cache = null;
      }
      pause();
      await box.ack(disk.member, n.id);
      pause();
    }

    // Send again whatever a partner is missing; it goes out next time.
    for (final wanted in await box.requests(disk.member)) {
      for (final w in wanted.entries) {
        for (final seq in w.value) {
          final id = '${w.key}:$seq';
          if (disk.notes.containsKey(id)) disk.outbox.add(id);
        }
      }
    }
    pause();

    // Ask for what the box has seen but this phone does not hold: a note that
    // expired while away, or one made after a restored backup.
    final missing = <String, List<int>>{};
    for (final h in (await box.highest()).entries) {
      final gaps = [
        for (var s = 1; s <= h.value; s++)
          if (!disk.notes.containsKey('${h.key}:$s')) s,
      ];
      if (gaps.isNotEmpty) missing[h.key] = gaps;
    }
    await box.request(disk.member, missing);
  }
}

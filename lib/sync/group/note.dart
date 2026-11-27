/// The shared group's add-only ledger. Nothing is ever overwritten: every add,
/// edit or delete is a [Note], and the visible entries are a pure function of
/// the set of notes a phone holds, whatever order they arrived in.
library;

import 'dart:convert';

/// Newest note format this app understands.
const noteFormat = 1;

/// One change to one entry inside a note.
class Op {
  final String entry;

  /// Versions (note ids) this change was based on and takes the place of.
  final List<String> replaces;

  /// The whole row, or null for a delete.
  final Map<String, Object?>? data;
  const Op(this.entry, {this.replaces = const [], this.data});

  Map<String, Object?> toJson() => {
    'entry': entry,
    'replaces': replaces,
    'data': data,
  };

  static Op fromJson(Map<String, dynamic> j) => Op(
    j['entry'] as String,
    replaces: (j['replaces'] as List).cast<String>(),
    data: (j['data'] as Map?)?.cast<String, Object?>(),
  );
}

/// An immutable, atomically applied batch of changes.
class Note {
  /// Unique per phone install; a restored phone gets a new one so that it can
  /// never reuse a note number.
  final String writer;
  final int seq;

  /// Hybrid logical clock; gives every phone the same order.
  final String stamp;
  final int format;

  /// The phone's wall clock when the change was made, only for display.
  final int at;
  final List<Op> ops;
  const Note({
    required this.writer,
    required this.seq,
    required this.stamp,
    required this.ops,
    this.at = 0,
    this.format = noteFormat,
  });

  String get id => '$writer:$seq';

  /// Whose phone made it: the writer without its restore counter.
  String get member => writer.substring(0, writer.lastIndexOf('.'));

  String encode() => jsonEncode({
    'writer': writer,
    'seq': seq,
    'stamp': stamp,
    'format': format,
    'at': at,
    'ops': [for (final o in ops) o.toJson()],
  });

  static Note decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final format = j['format'] as int;
    return Note(
      writer: j['writer'] as String,
      seq: j['seq'] as int,
      stamp: j['stamp'] as String,
      format: format,
      at: j['at'] as int? ?? 0,
      // A newer format is kept untouched until the app is updated.
      ops: format > noteFormat
          ? const []
          : [
              for (final o in j['ops'] as List)
                Op.fromJson((o as Map).cast<String, dynamic>()),
            ],
    );
  }
}

/// One surviving version of an entry.
class Version {
  final String id;
  final String stamp;
  final Map<String, Object?> data;
  const Version(this.id, this.stamp, this.data);
}

/// An entry as shown. More than one head means two phones changed the same
/// version: the earliest is shown until someone chooses.
class Entry {
  final String id;
  final List<Version> heads;
  const Entry(this.id, this.heads);

  Map<String, Object?> get data => heads.first.data;
  bool get needsReview => heads.length > 1;
}

/// The notes that count, in the order every phone agrees on.
///
/// An edit waits until the versions it changes are here; otherwise one part of
/// a split could appear before the split itself. A change is always stamped
/// later than what it was based on, so one pass in stamp order is enough.
/// Deletes never wait.
List<Note> _applied(Iterable<Note> notes) {
  final ordered = notes.toList()
    ..sort((a, b) {
      final c = a.stamp.compareTo(b.stamp);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final ids = <String>{};
  final out = <Note>[];
  for (final n in ordered) {
    final waiting = n.ops.any(
      (op) => op.data != null && !op.replaces.every(ids.contains),
    );
    if (waiting) continue;
    ids.add(n.id);
    out.add(n);
  }
  return out;
}

/// The visible entries for a set of notes. Order of [notes] does not matter.
Map<String, Entry> entriesOf(Iterable<Note> notes) {
  final deleted = <String>{};
  final replaced = <String, Set<String>>{};
  final versions = <String, List<Version>>{};
  for (final n in _applied(notes)) {
    for (final op in n.ops) {
      (replaced[op.entry] ??= {}).addAll(op.replaces);
      final data = op.data;
      if (data == null) {
        deleted.add(op.entry); // a delete beats any edit, for good
      } else {
        (versions[op.entry] ??= []).add(Version(n.id, n.stamp, data));
      }
    }
  }
  final out = <String, Entry>{};
  for (final e in versions.entries) {
    if (deleted.contains(e.key)) continue;
    final heads =
        e.value.where((v) => !replaced[e.key]!.contains(v.id)).toList()
          ..sort((a, b) {
            final c = a.stamp.compareTo(b.stamp);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    if (heads.isNotEmpty) out[e.key] = Entry(e.key, heads);
  }
  return out;
}

/// Money is never sent as a total; it is always added up from the entries.
int totalMinor(Map<String, Entry> entries) => entries.values.fold(
  0,
  (sum, e) => sum + (e.data['amountMinor'] as int? ?? 0),
);

enum ChangeKind { added, changed, settled, deleted }

/// One line of an entry's history.
class Change {
  final ChangeKind kind;
  final String member;
  final int at;

  /// The row it was based on (null when added) and the row it left behind
  /// (null when deleted).
  final Map<String, Object?>? before, after;
  const Change(this.kind, this.member, this.at, this.before, this.after);
}

/// Who did what to an entry, oldest first. Deleted entries keep theirs.
List<Change> historyOf(Iterable<Note> notes, String entry) {
  final rows = <String, Map<String, Object?>>{};
  final out = <Change>[];
  for (final n in _applied(notes)) {
    for (final op in n.ops.where((o) => o.entry == entry)) {
      Map<String, Object?>? before;
      for (final id in op.replaces) {
        before ??= rows[id];
      }
      final data = op.data;
      if (data != null) rows[n.id] = data;
      final kind = data == null
          ? ChangeKind.deleted
          : op.replaces.isEmpty
          ? ChangeKind.added
          : op.replaces.length > 1
          ? ChangeKind.settled
          : ChangeKind.changed;
      out.add(Change(kind, n.member, n.at, before, data));
    }
  }
  return out;
}

/// Entries somebody deleted, for the "Deleted" list.
Set<String> deletedEntries(Iterable<Note> notes) => {
  for (final n in notes)
    for (final op in n.ops)
      if (op.data == null) op.entry,
};

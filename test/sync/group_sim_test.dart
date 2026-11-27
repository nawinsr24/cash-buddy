import 'dart:convert';
import 'dart:math';

import 'package:cash_buddy/sync/group/note.dart';
import 'package:cash_buddy/sync/group/replica.dart';
import 'package:flutter_test/flutter_test.dart';

import 'group_post_box.dart';

/// More runs: flutter test test/sync/group_sim_test.dart
/// --dart-define=SIM_RUNS=10000
const _runs = int.fromEnvironment('SIM_RUNS', defaultValue: 200);
const _firstSeed = int.fromEnvironment('SIM_SEED');

class _Crash implements Exception {}

class _Phone {
  Replica replica;
  Disk? backup;
  final int skew;
  _Phone(String member, this.skew, int Function() time)
    : replica = Replica(Disk(member), now: () => time() + skew);
}

class _Stats {
  int changes = 0, conflicts = 0, crashes = 0, offline = 0;
  int restores = 0, expired = 0, lostUnsent = 0, unrecoverable = 0;
}

String _picture(Replica r) {
  final ids = r.entries.keys.toList()..sort();
  final all = {...ids, ...r.deleted}.toList()..sort();
  return jsonEncode([
    r.total,
    for (final id in all)
      [
        id,
        for (final c in r.history(id))
          [c.kind.name, c.member, c.at, c.before, c.after],
      ],
    for (final id in ids)
      [
        id,
        for (final v in r.entries[id]!.heads) [v.id, v.data],
      ],
  ]);
}

/// Rules that must hold on any phone at any moment, worked out from the raw
/// notes separately from the code under test.
void _checkAnytime(Replica r) {
  final deleted = {
    for (final n in r.notes)
      for (final o in n.ops)
        if (o.data == null) o.entry,
  };
  expect(r.entries.keys.toSet().intersection(deleted), isEmpty);
  var sum = 0;
  for (final e in r.entries.values) {
    sum += e.data['amountMinor'] as int;
    final split = (e.data['split'] as List?)?.cast<String>();
    if (split != null) {
      expect(split.every(r.entries.containsKey), isTrue, reason: 'half split');
    }
  }
  expect(r.total, sum);

  // Every shown entry has a history that starts with its creation and
  // contains what is on screen.
  for (final e in r.entries.values) {
    final history = r.history(e.id);
    expect(history.first.kind, ChangeKind.added);
    expect(
      history.map((c) => jsonEncode(c.after)),
      contains(jsonEncode(e.data)),
    );
  }
}

Future<void> _simulate(int seed, _Stats stats) async {
  final random = Random(seed);
  var time = 1000000000;
  var epoch = 0;
  var restores = 0;
  // Notes whose last copy on any phone was removed by restoring a backup.
  final rolledAway = <String>{};
  final box = FakePostBox(['a', 'b'], random)..faultRate = 0.08;
  final phones = [
    for (final m in ['a', 'b'])
      _Phone(m, random.nextInt(600000000) - 300000000, () => time),
  ];

  Replica reopen(_Phone p, Disk disk) =>
      Replica(disk, now: () => time + p.skew);

  Future<void> sync(_Phone p, {required bool crashes}) async {
    try {
      await p.replica.sync(
        box,
        step: () {
          if (crashes && random.nextDouble() < 0.03) throw _Crash();
        },
      );
    } on Offline {
      stats.offline++;
    } on _Crash {
      stats.crashes++;
      p.replica = reopen(p, p.replica.disk);
    }
  }

  final steps = 40 + random.nextInt(60);
  for (var i = 0; i < steps; i++) {
    time += random.nextInt(100000) - 5000; // clocks sometimes step back
    final p = phones[random.nextInt(2)];
    final r = p.replica;
    final ids = r.entries.keys.toList();
    String any() => ids[random.nextInt(ids.length)];
    Map<String, Object?> row() => {
      'amountMinor': 1 + random.nextInt(500000),
      'note': 'n${random.nextInt(50)}',
    };

    final what = random.nextInt(100);
    if (what < 18) {
      r.add([row()]);
      stats.changes++;
    } else if (what < 25) {
      r.add([for (var k = 0; k < 2 + random.nextInt(3); k++) row()]);
      stats.changes++;
    } else if (what < 40 && ids.isNotEmpty) {
      r.edit(any(), {'amountMinor': 1 + random.nextInt(500000)});
      stats.changes++;
    } else if (what < 47 && ids.isNotEmpty) {
      r.delete(any());
      stats.changes++;
    } else if (what < 53) {
      final open = ids.where((id) => r.entries[id]!.needsReview).toList();
      if (open.isNotEmpty) {
        final id = open[random.nextInt(open.length)];
        r.resolve(id, random.nextInt(r.entries[id]!.heads.length));
      }
    } else if (what < 85) {
      await sync(p, crashes: true);
    } else if (what < 90) {
      box.down = !box.down;
    } else if (what < 93) {
      p.backup = r.disk.copy();
    } else if (what < 94 && p.backup != null) {
      // Work that never left this phone and is newer than the backup is gone;
      // no design can bring that back.
      stats.lostUnsent += r.disk.notes.keys
          .where(
            (id) =>
                !p.backup!.notes.containsKey(id) && !box.accepted.contains(id),
          )
          .length;
      final other = phones.firstWhere((x) => x != p).replica.disk.notes;
      rolledAway.addAll(
        r.disk.notes.keys.where(
          (id) => !p.backup!.notes.containsKey(id) && !other.containsKey(id),
        ),
      );
      p.replica = reopen(p, p.backup!.restored('${r.disk.member}.${++epoch}'));
      restores++;
    } else if (what < 96) {
      box.pass(random.nextInt(120));
    }
    _checkAnytime(p.replica);
  }

  // The network comes back and both phones are opened a few times.
  box
    ..down = false
    ..faultRate = 0;
  for (var i = 0; i < 6; i++) {
    for (final p in phones) {
      await sync(p, crashes: false);
    }
  }

  final a = phones[0].replica, b = phones[1].replica;
  final why = 'seed $seed';
  expect(a.disk.notes.keys.toSet(), b.disk.notes.keys.toSet(), reason: why);
  expect(_picture(a), _picture(b), reason: why);
  _checkAnytime(a);
  _checkAnytime(b);

  // Everything that ever reached the post box is on both phones. The only
  // exception: a restored backup removed the last copy any phone had, and the
  // post box no longer held it.
  final missing = box.accepted.difference(a.disk.notes.keys.toSet());
  expect(rolledAway.containsAll(missing), isTrue, reason: '$why $missing');

  // Reading the same notes in another order gives the same result.
  final shuffled = a.notes.toList()..shuffle(random);
  expect(totalMinor(entriesOf(shuffled)), a.total, reason: why);

  stats
    ..conflicts += a.entries.values.where((e) => e.needsReview).length
    ..restores += restores
    ..expired += box.expired.length
    ..unrecoverable += missing.length;
}

void main() {
  test('two phones always end up identical ($_runs random runs)', () async {
    final stats = _Stats();
    for (var seed = _firstSeed; seed < _firstSeed + _runs; seed++) {
      try {
        await _simulate(seed, stats);
      } catch (_) {
        // Replay with --dart-define=SIM_SEED=<seed> --dart-define=SIM_RUNS=1
        // ignore: avoid_print
        print('FAILED at seed $seed');
        rethrow;
      }
    }
    // ignore: avoid_print
    print(
      'runs=$_runs changes=${stats.changes} openConflicts=${stats.conflicts} '
      'crashes=${stats.crashes} offline=${stats.offline} '
      'restores=${stats.restores} expired=${stats.expired} '
      'lostUnsentOnRestore=${stats.lostUnsent} '
      'unrecoverable=${stats.unrecoverable}',
    );
  }, timeout: const Timeout(Duration(minutes: 9)));

  test(
    'both phones show the same conflict, and either choice settles it',
    () async {
      final box = FakePostBox(['a', 'b'], Random(1));
      var a = Replica(Disk('a'), now: () => 1000);
      final b = Replica(Disk('b'), now: () => 2000);
      Future<void> both() async {
        for (var i = 0; i < 2; i++) {
          await a.sync(box);
          await b.sync(box);
        }
      }

      final id = a.add([
        {'amountMinor': 200000},
      ]).single;
      await both();
      a.edit(id, {'amountMinor': 250000});
      b.edit(id, {'amountMinor': 220000});
      await both();
      expect(a.entries[id]!.needsReview, isTrue);
      expect(_picture(a), _picture(b));

      b.resolve(id, 1);
      await both();
      expect(a.entries[id]!.needsReview, isFalse);
      expect(_picture(a), _picture(b));
    },
  );

  test('history says who changed what, and who deleted', () async {
    final box = FakePostBox(['naveen', 'priya'], Random(1));
    var clock = 1000;
    final n = Replica(Disk('naveen'), now: () => clock++);
    final p = Replica(Disk('priya'), now: () => clock++);
    Future<void> both() async {
      for (var i = 0; i < 2; i++) {
        await n.sync(box);
        await p.sync(box);
      }
    }

    final id = n.add([
      {'amountMinor': 200000},
    ]).single;
    await both();
    n.edit(id, {'amountMinor': 250000});
    await both();
    p.edit(id, {'amountMinor': 220000});
    await both();
    p.delete(id);
    await both();

    List<Object?> lines(Replica r) => [
      for (final c in r.history(id))
        '${c.member} ${c.kind.name} '
            '${c.before?['amountMinor']} ${c.after?['amountMinor']}',
    ];
    expect(lines(n), [
      'naveen added null 200000',
      'naveen changed 200000 250000',
      'priya changed 250000 220000',
      'priya deleted 220000 null',
    ]);
    expect(lines(p), lines(n));
    expect(n.deleted, {id});
    expect(n.entries, isEmpty);
  });

  test('a note from a newer app is kept, not applied', () async {
    final box = FakePostBox(['a', 'b'], Random(1));
    final b = Replica(Disk('b'));
    final future = const Note(
      writer: 'a.0',
      seq: 1,
      stamp: '000000000000001-0000-a.0',
      format: noteFormat + 1,
      ops: [],
    );
    await box.upload('a', future.id, future.encode());
    await b.sync(box);
    expect(b.needsUpdate, isTrue);
    expect(b.entries, isEmpty);
    expect(b.disk.notes[future.id], future.encode());
  });
}

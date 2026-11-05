import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

class Dev {
  final String id;
  final TestEnv env;
  late final SyncEngine engine;
  Dev(this.id, this.env, InMemoryRemote remote) {
    engine = SyncEngine(env.repo, remote, id);
  }
  Repo get repo => env.repo;
}

Future<Dev> dev(String id, InMemoryRemote remote, {DateTime? now}) async =>
    Dev(id, await newEnv(device: id, now: now), remote);

/// Canonical content of all synced tables, ignoring versions (hlc).
Future<String> dump(Repo r) async {
  Map<String, dynamic> strip(Map<String, dynamic> m) =>
      Map.of(m)..remove('hlc');
  List<Map<String, dynamic>> rows(Iterable<dynamic> l) {
    final out = [
      for (final x in l) strip((x as dynamic).toJson() as Map<String, dynamic>),
    ];
    out.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return out;
  }

  return jsonEncode({
    'a': rows(await r.db.select(r.db.accounts).get()),
    'c': rows(await r.db.select(r.db.categories).get()),
    't': rows(await r.db.select(r.db.transactions).get()),
    'd': rows(await r.db.select(r.db.debts).get()),
    'e': rows(await r.db.select(r.db.debtEvents).get()),
    'i': rows(await r.db.select(r.db.investments).get()),
    'ie': rows(await r.db.select(r.db.investmentEntries).get()),
  });
}

Future<void> syncAll(List<Dev> devs, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    for (final d in devs) {
      final res = await d.engine.sync();
      expect(res.ok, isTrue, reason: res.error);
    }
  }
}

void main() {
  test(
    'push then pull transfers rows; repeated syncs reach quiescence',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      await a.repo.addTransaction(
        type: 'credit',
        amountMinor: 50000,
        categoryId: 'cat_salary',
      );
      final r1 = await a.engine.sync();
      expect(r1.ok && r1.pushedRows > 0, isTrue);
      final r2 = await b.engine.sync();
      expect(r2.pulledRows > 0, isTrue);
      expect(await b.repo.totalBalance(), 50000);
      // no endless ping-pong: repeated syncs stop producing segments
      final w = remote.writes;
      await syncAll([a, b], rounds: 3);
      expect(remote.writes, w);
    },
  );

  test(
    'upload failure loses nothing: cursor not advanced, retry succeeds',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      await a.repo.addTransaction(type: 'debit', amountMinor: 1234);
      remote.failNextWrites = 1;
      final bad = await a.engine.sync();
      expect(bad.ok, isFalse);
      expect(await a.repo.getSetting('lastSyncError'), isNotEmpty);
      expect(remote.files, isEmpty);
      final good = await a.engine.sync();
      expect(good.ok, isTrue);
      await b.engine.sync();
      expect(await b.repo.totalBalance(), -1234);
    },
  );

  test(
    'download failure is surfaced and retried without corrupting state',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      await a.repo.addTransaction(type: 'debit', amountMinor: 500);
      await a.engine.sync();
      remote.failNextReads = 1;
      expect((await b.engine.sync()).ok, isFalse);
      expect(await b.repo.totalBalance(), 0);
      expect((await b.engine.sync()).ok, isTrue);
      expect(await b.repo.totalBalance(), -500);
    },
  );

  test('corrupt segment is rejected by checksum', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    await a.repo.addTransaction(type: 'debit', amountMinor: 500);
    await a.engine.sync();
    final name = remote.files.keys.first;
    final env = jsonDecode(
      utf8.decode(gzip.decode(remote.files[name]!)),
    ) as Map<String, dynamic>;
    env['payload'] = (env['payload'] as String).replaceFirst('500', '999');
    remote.files[name] = gzip.encode(utf8.encode(jsonEncode(env)));
    final res = await b.engine.sync();
    expect(res.ok, isFalse);
    expect(res.error, contains('checksum'));
    expect(await b.repo.totalBalance(), 0);
  });

  test(
    'concurrent edits: last writer wins; delete (newer) beats older edit',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      final id = await a.repo.addTransaction(type: 'debit', amountMinor: 1000);
      await syncAll([a, b]);
      // B edits, then A (later) edits => A wins
      await b.repo.updateTransaction(id, amountMinor: 2000);
      a.env.clockNow = a.env.clockNow.add(const Duration(minutes: 5));
      await a.repo.updateTransaction(id, amountMinor: 3000);
      await syncAll([a, b]);
      expect(await a.repo.totalBalance(), -3000);
      expect(await b.repo.totalBalance(), -3000);
      // A edits (older), B deletes (newer) => tombstone wins
      await a.repo.updateTransaction(id, note: 'edit');
      b.env.clockNow = b.env.clockNow.add(const Duration(minutes: 10));
      await b.repo.deleteTransaction(id);
      await syncAll([a, b]);
      expect(await a.repo.totalBalance(), 0);
      expect(await b.repo.totalBalance(), 0);
      expect(await dump(a.repo), await dump(b.repo));
    },
  );

  test(
    'device with a skewed (slow) clock still converges (HLC observes remote)',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote, now: DateTime(2026, 11, 4, 10));
      final b = await dev(
        'devB',
        remote,
        now: DateTime(2026, 11, 3, 10),
      ); // a day behind
      final id = await a.repo.addTransaction(type: 'debit', amountMinor: 1000);
      await syncAll([a, b]);
      await b.repo.updateTransaction(
        id,
        amountMinor: 7000,
      ); // causally after, despite slow clock
      await syncAll([a, b]);
      expect(await a.repo.totalBalance(), -7000);
      expect(await dump(a.repo), await dump(b.repo));
    },
  );

  test('both devices confirming the same SMS yields one transaction', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    final parser = SmsParser();
    final msg = (
      sender: 'VM-HDFCBK',
      body: 'Rs.500.00 debited from a/c XX1234 on 03-11-26. Ref 9000011111',
      receivedAt: DateTime(2026, 11, 4),
    );
    for (final d in [a, b]) {
      await d.repo.ingestSms([msg], parser);
      await d.repo.confirmSms((await d.repo.pendingSms()).single.id);
    }
    await syncAll([a, b]);
    expect((await a.repo.searchTransactions(const TxnFilter())).length, 1);
    expect(await a.repo.totalBalance(), -50000);
    expect(await dump(a.repo), await dump(b.repo));
  });

  test('debts converge: concurrent repayments on two devices re-derive consistently', () async {
    final remote = InMemoryRemote();
    final now = DateTime(2026, 11, 4, 10);
    final a = await dev('devA', remote, now: now);
    final b = await dev('devB', remote, now: now);
    final id = await a.repo.createDebt(
      direction: 'receivable',
      counterparty: 'X',
      principalMinor: 100000,
      issuedOn: Dates.day(2026, 8, 4),
      interestEnabled: true,
      rateBps: 200,
    );
    await syncAll([a, b]);
    await a.repo.addRepayment(id, 10000, date: Dates.day(2026, 10, 1));
    await b.repo.addRepayment(id, 20000, date: Dates.day(2026, 10, 20));
    await syncAll([a, b], rounds: 4);
    expect(await dump(a.repo), await dump(b.repo));
    final sa = await a.repo.debtState(id), sb = await b.repo.debtState(id);
    expect(sa.outstanding, sb.outstanding);
    expect(sa.totalPaid, 30000);
    // ledger has exactly one row per leg (no double posting after merge)
    expect(await a.repo.checkInvariants(), isEmpty);
    expect(await b.repo.checkInvariants(), isEmpty);
    expect(await a.repo.totalBalance(), await b.repo.totalBalance());
  });

  test('3 devices, random offline edits, converge with zero loss', () async {
    final remote = InMemoryRemote();
    final now = DateTime(2026, 11, 4, 10);
    final devs = [
      for (final n in ['devA', 'devB', 'devC']) await dev(n, remote, now: now),
    ];
    final rng = Random(2024);
    final debtIds = <String>[];
    final everCreated = <String>{}; // transaction ids ever created
    for (var round = 0; round < 12; round++) {
      for (final d in devs) {
        d.env.clockNow = d.env.clockNow.add(
          Duration(minutes: 1 + rng.nextInt(30)),
        );
        final txns = await d.repo.searchTransactions(
          const TxnFilter(source: 'manual'),
        );
        for (var k = 0; k < 1 + rng.nextInt(4); k++) {
          final op = rng.nextInt(10);
          try {
            if (op < 4 || txns.isEmpty) {
              final id = await d.repo.addTransaction(
                type: rng.nextBool() ? 'credit' : 'debit',
                amountMinor: 1 + rng.nextInt(50000),
                categoryId: rng.nextBool() ? 'cat_food' : 'cat_salary',
                date: Dates.day(2026, 11, 1 + rng.nextInt(4)),
              );
              everCreated.add(id);
            } else if (op == 4) {
              await d.repo.updateTransaction(
                txns[rng.nextInt(txns.length)].id,
                amountMinor: 1 + rng.nextInt(50000),
              );
            } else if (op == 5) {
              await d.repo.deleteTransaction(txns[rng.nextInt(txns.length)].id);
            } else if (op == 6) {
              await d.repo.updateCategory(
                'cat_food',
                name: 'Food ${rng.nextInt(100)}',
              );
            } else if (op == 7) {
              debtIds.add(
                await d.repo.createDebt(
                  direction: rng.nextBool() ? 'receivable' : 'liability',
                  counterparty: 'P${rng.nextInt(9)}',
                  principalMinor: 10000 + rng.nextInt(90000),
                  issuedOn: Dates.day(2026, 8, 1 + rng.nextInt(20)),
                  interestEnabled: rng.nextBool(),
                  rateBps: 100 + rng.nextInt(200),
                ),
              );
            } else if (debtIds.isNotEmpty) {
              final debts = await d.repo.debts();
              if (debts.isNotEmpty) {
                await d.repo.addRepayment(
                  debts[rng.nextInt(debts.length)].id,
                  100 + rng.nextInt(5000),
                  date: Dates.day(2026, 10, 1 + rng.nextInt(28)),
                );
              }
            }
          } on OverpaymentException {
            // legitimate rejection
          } on ValidationException {
            // e.g. editing a row another device already deleted locally
          }
        }
      }
      // random partial sync: some devices skip rounds (offline periods)
      for (final d in devs) {
        if (rng.nextInt(3) != 0) {
          final res = await d.engine.sync();
          expect(res.ok, isTrue, reason: res.error);
        }
      }
    }
    await syncAll(devs, rounds: 4);
    final d0 = await dump(devs[0].repo);
    expect(await dump(devs[1].repo), d0);
    expect(await dump(devs[2].repo), d0);
    // zero loss: every transaction ever created exists on every device (live or tombstoned)
    for (final d in devs) {
      final ids = (await d.repo.db.select(d.repo.db.transactions).get())
          .map((t) => t.id)
          .toSet();
      expect(ids.containsAll(everCreated), isTrue);
      expect(await d.repo.checkInvariants(), isEmpty);
    }
    final b0 = await devs[0].repo.balances();
    expect(await devs[1].repo.balances(), b0);
    expect(await devs[2].repo.balances(), b0);
    // and the system is quiescent: another round writes nothing
    final w = remote.writes;
    await syncAll(devs, rounds: 2);
    expect(remote.writes, w);
  });

  test('investments and their entries converge across devices', () async {
    final remote = InMemoryRemote();
    final a = await dev('A', remote);
    final b = await dev('B', remote);
    await syncAll([a, b]);
    final id = await a.repo.createInvestment(kind: 'chit', name: 'Chit');
    await a.repo.addInvestmentEntry(
      id,
      type: 'contribute',
      amountMinor: 5000,
      periodKey: 0,
    );
    await syncAll([a, b]);
    expect((await b.repo.investments()).single.name, 'Chit');
    expect(await b.repo.totalBalance(), await a.repo.totalBalance());
    // B deletes the entry; A converges
    final en = (await b.repo.investmentEntries(id)).single;
    await b.repo.deleteInvestmentEntry(en.id);
    await syncAll([a, b]);
    expect(await a.repo.investmentEntries(id), isEmpty);
    expect(await dump(a.repo), await dump(b.repo));
    expect(await a.repo.checkInvariants(), isEmpty);
  });
}

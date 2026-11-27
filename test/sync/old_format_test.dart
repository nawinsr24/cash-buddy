import 'dart:convert';

import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/sync/gzip_codec.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show Dev, dev, syncAll;

/// Fields that did not exist in earlier releases.
const _newer = {
  'accounts': [
    'bank',
    'limitMinor',
    'dueDay',
    'interestBps',
    'ratePeriod',
    'graceDays',
  ],
  'debts': ['affectsBalance'],
  'investments': ['recurring', 'everyN'],
};

Map<String, dynamic> _open(List<int> bytes) {
  final env = jsonDecode(utf8.decode(gzipDecode(bytes))) as Map;
  return jsonDecode(env['payload'] as String) as Map<String, dynamic>;
}

List<int> _seal(Map<String, dynamic> data) {
  final payload = jsonEncode(data);
  return gzipEncode(
    utf8.encode(
      jsonEncode({
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
        'payload': payload,
      }),
    ),
  );
}

/// Rewrites everything in [remote] the way an older release wrote it.
void _downgrade(InMemoryRemote remote, {String prefix = 'seg/'}) {
  for (final name in remote.files.keys.toList()) {
    if (!name.startsWith(prefix)) continue;
    final data = _open(remote.files[name]!)..['schema'] = 1;
    final rows = data['rows'] as Map<String, dynamic>;
    for (final e in _newer.entries) {
      for (final row in (rows[e.key] as List? ?? const [])) {
        e.value.forEach((row as Map).remove);
      }
    }
    remote.files[name] = _seal(data);
  }
}

Future<String> _card(Dev d) => d.repo.addCard(
  name: 'HDFC',
  bank: 'HDFC',
  last4: '1234',
  limitMinor: 100000,
  dueDay: 25,
  interestBps: 4200,
  ratePeriod: 'year',
  graceDays: 3,
);

void main() {
  test('a backup written by an older app can be restored', () async {
    final remote = InMemoryRemote();
    final old = await dev('devA', remote);
    await old.repo.addTransaction(
      type: 'debit',
      amountMinor: 2500,
      accountId: 'acc_cash',
    );
    await old.repo.createDebt(
      direction: 'receivable',
      counterparty: 'Ravi',
      principalMinor: 900,
      accountId: 'acc_cash',
    );
    await old.repo.createInvestment(kind: 'stock', name: 'INFY');
    await syncAll([old]);
    _downgrade(remote);

    final fresh = await dev('devB', remote);
    final result = await fresh.engine.sync();
    expect(result.ok, isTrue, reason: result.error);
    expect(await fresh.repo.totalBalance(), await old.repo.totalBalance());
    expect((await fresh.repo.debts()).single.affectsBalance, isTrue);
    expect(
      (await fresh.repo.db.select(fresh.repo.db.investments).get())
          .single
          .recurring,
      isFalse,
    );
  });

  test('an edit from an older app does not wipe card settings', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    final id = await _card(a);
    await syncAll([a, b]);

    // B renames the card, and its upload looks like the older app's.
    final db = b.repo.db;
    final row = await (db.select(
      db.accounts,
    )..where((t) => t.id.equals(id))).getSingle();
    await db
        .update(db.accounts)
        .replace(row.copyWith(name: 'Renamed', hlc: b.repo.clock.next()));
    final before = remote.files.keys.toSet();
    await b.engine.sync();
    for (final name in remote.files.keys.toSet().difference(before)) {
      _downgrade(remote, prefix: name);
    }

    await a.engine.sync();
    final card = (await a.repo.cards()).single;
    expect(card.name, 'Renamed');
    expect(card.dueDay, 25);
    expect(card.interestBps, 4200);
    expect(card.graceDays, 3);
    expect(card.limitMinor, 100000);
  });

  test('uploads are marked so older apps ask to be updated', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    await _card(a);
    await a.engine.sync();
    final segment = remote.files.entries.firstWhere(
      (e) => e.key.startsWith('seg/'),
    );
    // Released builds understand format 1 and refuse anything newer.
    expect(_open(segment.value)['schema'], greaterThan(1));
  });
}

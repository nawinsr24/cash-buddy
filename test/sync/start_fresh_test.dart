import 'package:cash_buddy/platform/google_identity.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'sync_test.dart' show dev, syncAll;

void main() {
  test('after "Start fresh" the old data never comes back', () async {
    final remote = InMemoryRemote();
    final old = await dev('devA', remote);
    await old.repo.addTransaction(type: 'debit', amountMinor: 4200);
    await syncAll([old]);

    final fresh = await dev('devB', remote);
    await SyncEngine.startFresh(remote, '1');
    await syncAll([fresh]);
    expect(await fresh.repo.db.select(fresh.repo.db.transactions).get(), []);
    await fresh.repo.addTransaction(type: 'debit', amountMinor: 7);
    await syncAll([fresh]);

    // a later reinstall that restores gets only what came after
    final again = await dev('devC', remote);
    await syncAll([again]);
    expect(
      (await again.repo.db.select(again.repo.db.transactions).get()).map(
        (t) => t.amountMinor,
      ),
      [7],
    );
  });

  test('the app keeps to one Google account', () async {
    final env = await newEnv();
    addTearDown(() => env.db.close());
    expect(await useGoogleAccount(env.repo, 'a@x.com'), isNull);
    expect(await useGoogleAccount(env.repo, 'A@x.com'), isNull);
    final refused = await useGoogleAccount(env.repo, 'b@x.com');
    expect(refused?.toLowerCase(), contains('a@x.com'));
    expect((await googleAccount(env.repo)).toLowerCase(), 'a@x.com');
  });
}

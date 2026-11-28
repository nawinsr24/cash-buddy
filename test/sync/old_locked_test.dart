import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show dev, dump, syncAll;

void main() {
  test(
    'files locked by an old password are skipped; data is re-sent',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      await a.repo.addTransaction(type: 'debit', amountMinor: 4200);
      await syncAll([a]);
      // as an older version left it: every file locked, already counted as sent
      for (final name in remote.files.keys.toList()) {
        remote.files[name] = [0x43, 0x42, 0x45, 0x31, 9, 9, 9, 9];
      }
      await a.repo.setSetting('plainUpload', '');
      await syncAll([a]);

      final b = await dev('devB', remote);
      await syncAll([b, a]);
      expect(await dump(b.repo), await dump(a.repo));
    },
  );
}

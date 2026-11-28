import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:cash_buddy/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

class SpyRemote extends InMemoryRemote {
  int calls = 0;
  @override
  Future<List<String>> list() {
    calls++;
    return super.list();
  }

  @override
  Future<void> write(String name, List<int> bytes) {
    calls++;
    return super.write(name, bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Offline Mode makes zero remote calls, even if sync is triggered',
    () async {
      final e = await newEnv(); // onboarded as offline
      final spy = SpyRemote();
      final svc = SyncService(e.repo)..useRemote(spy);
      await e.repo.addTransaction(type: 'debit', amountMinor: 100);
      final res = await svc.syncNow();
      expect(res.ok, isTrue);
      expect(spy.calls, 0);
      expect(await e.repo.dataMode, 'offline');
    },
  );

  test('Online Mode syncs through the injected remote', () async {
    final e = await newEnv();
    await e.repo.setSetting('dataMode', 'online');
    final spy = SpyRemote();
    final svc = SyncService(e.repo)..useRemote(spy);
    await e.repo.addTransaction(type: 'debit', amountMinor: 100);
    final res = await svc.syncNow();
    expect(res.ok, isTrue);
    expect(spy.calls, greaterThan(0));
  });
}

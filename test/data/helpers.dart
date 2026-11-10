import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/sync/vault.dart';
import 'package:cash_buddy/data/db.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/hlc.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

class TestEnv {
  DateTime clockNow;
  final AppDatabase db;
  late final Repo repo;
  TestEnv(this.db, this.clockNow, String device) {
    var tick = 0;
    repo = Repo(
      db,
      Hlc(
        device,
        now: () => clockNow.millisecondsSinceEpoch + (tick++ ~/ 1000),
      ),
      now: () => clockNow,
    );
  }
}

Future<TestEnv> newEnv({
  String device = 'devA',
  String accountMode = 'combined',
  DateTime? now,
  int opening = 0,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final env = TestEnv(
    AppDatabase(NativeDatabase.memory()),
    now ?? DateTime(2026, 11, 4, 10),
    device,
  );
  await env.repo.completeOnboarding(
    dataMode: 'offline',
    accountMode: accountMode,
    openingCashMinor: opening,
    openingBankMinor: 0,
  );
  return env;
}

/// A vault with a passphrase already set, for tests that sync.
Future<Vault> testVault() async {
  final v = Vault(MemorySecretStore(), iterations: 1000);
  await v.setPassphrase('test passphrase');
  return v;
}

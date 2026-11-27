/// A complete backup of everything the user entered, and putting it back.
/// Unlike sync, which merges, restoring replaces what is on the phone.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/db.dart';
import '../data/db_key.dart';
import '../data/repo.dart';
import 'sync_engine.dart';
import 'vault.dart';

/// Choices that belong to the user's data, not to this particular phone.
const backedUpSettings = [
  'accountMode',
  'budgetMode',
  'cardBudgetMode',
  'currency',
  'language',
  'expectedIncome',
  'themeMode',
  'reminderEnabled',
  'reminderTime',
  'titleCelebrated',
  'titleBannerDismissed',
];

/// Table key -> (table, how to read one row back).
Map<
  String,
  (
    TableInfo<Table, dynamic>,
    Insertable<dynamic> Function(Map<String, dynamic>),
  )
>
_tables(AppDatabase db) => {
  'accounts': (db.accounts, Account.fromJson),
  'categories': (db.categories, Category.fromJson),
  'transactions': (db.transactions, Transaction.fromJson),
  'debts': (db.debts, Debt.fromJson),
  'debt_events': (db.debtEvents, DebtEvent.fromJson),
  'investments': (db.investments, Investment.fromJson),
  'investment_entries': (db.investmentEntries, InvestmentEntry.fromJson),
  'budget_items': (db.budgetItems, BudgetItem.fromJson),
};

/// The backup file's bytes, encrypted when a backup password is set.
Future<Uint8List> buildBackup(Repo repo, {Vault? vault}) async {
  final db = repo.db;
  final data = <String, Object?>{
    'app': 'cash-buddy',
    'schema': SyncEngine.schema,
    'createdAt': repo.now().toUtc().toIso8601String(),
  };
  for (final e in _tables(db).entries) {
    data[e.key] = [
      for (final row in await db.select(e.value.$1).get())
        (row as dynamic).toJson() as Map<String, dynamic>,
    ];
  }
  data['settings'] = {
    for (final k in backedUpSettings) k: ?await repo.getSetting(k),
  };
  final payload = jsonEncode(data);
  final body = utf8.encode(
    jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    }),
  );
  return vault != null && await vault.isSet
      ? await vault.encrypt(body)
      : Uint8List.fromList(body);
}

/// Replaces this phone's data with the backup's. All or nothing: a damaged
/// file or wrong password changes nothing. Tables an older backup does not
/// contain are left alone. Returns the number of rows restored.
Future<int> restoreBackup(
  Repo repo,
  Uint8List bytes, {
  String? passphrase,
  int iterations = 150000,
}) async {
  var raw = bytes;
  if (Vault.isEncrypted(raw)) {
    if (passphrase == null || passphrase.length < 8) {
      throw VaultException('Enter the backup password for this file.');
    }
    final vault = Vault(MemorySecretStore(), iterations: iterations);
    await vault.setPassphrase(passphrase);
    raw = await vault.decrypt(raw);
  }
  final Map<String, dynamic> data;
  try {
    final envelope = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final payload = envelope['payload'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('checksum');
    }
    data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['app'] != 'cash-buddy') throw const FormatException('app');
  } catch (_) {
    throw VaultException('This is not a backup file, or it is damaged.');
  }
  if ((data['schema'] as int) > SyncEngine.schema) {
    throw VaultException('Update the app to restore this backup.');
  }

  final db = repo.db;
  var restored = 0;
  await db.transaction(() async {
    for (final e in _tables(db).entries) {
      final rows = data[e.key] as List?;
      if (rows == null) continue;
      await db.delete(e.value.$1).go();
      for (final row in rows) {
        final json = {
          ...?SyncEngine.addedLater[e.key],
          ...(row as Map).cast<String, dynamic>(),
        };
        repo.clock.observe(json['hlc'] as String);
        await db.into(e.value.$1).insert(e.value.$2(json));
        restored++;
      }
    }
    final settings = (data['settings'] as Map?) ?? const {};
    for (final k in backedUpSettings) {
      final v = settings[k];
      if (v is String) await repo.setSetting(k, v);
    }
    // Drive sync starts over from the restored data.
    await repo.setSetting('lastPushedHlc', '');
    await repo.setSetting('appliedSegs', '[]');
    await repo.reconcileAllDebts();
  });
  return restored;
}

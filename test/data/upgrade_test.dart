import 'dart:io';

import 'package:cash_buddy/data/db.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rebuilds the database as it looked in version [v] by removing everything
/// added later, with one row of real data in each table that existed.
Future<File> databaseAt(int v) async {
  final dir = Directory.systemTemp.createTempSync('upgrade');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/db.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  Future<void> run(String sql) => db.customStatement(sql);
  Future<void> drop(String table, List<String> columns) async {
    for (final c in columns) {
      await run('ALTER TABLE $table DROP COLUMN $c');
    }
  }

  await run(
    "INSERT INTO accounts(id,name,kind,color_value,opening_minor,hlc) "
    "VALUES('a','Cash','cash',1,50000,'x')",
  );
  await run(
    "INSERT INTO transactions(id,type,amount_minor,account_id,date,hlc) "
    "VALUES('t','debit',1200,'a','2026-11-01','x')",
  );
  await run(
    "INSERT INTO debts(id,direction,counterparty,principal_minor,issued_on,"
    "account_id,hlc) VALUES('d','receivable','Ravi',900,'2026-11-01','a','x')",
  );
  if (v >= 2) {
    await run(
      "INSERT INTO investments(id,kind,name,hlc) VALUES('i','stock','INFY','x')",
    );
    await run(
      "INSERT INTO investment_entries(id,investment_id,type,amount_minor,date,"
      "hlc) VALUES('ie','i','contribute',700,'2026-11-01','x')",
    );
  }

  if (v < 8) {
    await drop('accounts', [
      'bank',
      'limit_minor',
      'due_day',
      'interest_bps',
      'rate_period',
      'grace_days',
    ]);
  }
  if (v < 10) {
    await drop('debts', [
      'loan_kind',
      'annual_rate',
      'emi_minor',
      'emi_day',
      'emi_in_budget',
    ]);
  }
  if (v < 9) await drop('debts', ['split_id']);
  if (v < 7) await drop('debts', ['affects_balance']);
  if (v < 6 && v >= 2) await drop('investment_entries', ['units']);
  if (v < 5) await drop('debt_events', ['target']);
  if (v < 4) await run('DROP TABLE budget_items');
  if (v == 2) {
    await drop('investments', [
      'recurring',
      'cycle',
      'every_n',
      'weekday',
      'month_day',
      'time_of_day',
      'installments',
      'end_date',
    ]);
  }
  if (v < 2) {
    await run('DROP TABLE investment_entries');
    await run('DROP TABLE investments');
  }
  await run('PRAGMA user_version = $v');
  await db.close();
  return file;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (var v = 1; v <= 9; v++) {
    test('upgrading from version $v keeps the data', () async {
      final db = AppDatabase(NativeDatabase(await databaseAt(v)));
      addTearDown(db.close);

      final account = (await db.select(db.accounts).get()).single;
      expect(account.openingMinor, 50000);
      expect(account.interestBps, 0);
      expect((await db.select(db.transactions).get()).single.amountMinor, 1200);
      expect((await db.select(db.debts).get()).single.principalMinor, 900);
      expect(await db.select(db.budgetItems).get(), isEmpty);
      await db.select(db.debtEvents).get();
      final investments = await db.select(db.investments).get();
      final entries = await db.select(db.investmentEntries).get();
      expect(investments.length, v >= 2 ? 1 : 0);
      expect(entries.length, v >= 2 ? 1 : 0);
    });
  }
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

// Every synced table carries `hlc` (hybrid logical clock, LWW version) and
// `deletedAt` (soft delete tombstone).

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // cash | bank | overall
  IntColumn get colorValue => integer()();
  IntColumn get openingMinor => integer().withDefault(const Constant(0))();
  TextColumn get last4 => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // credit | debit
  TextColumn get parentId => text().nullable()();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withDefault(const Constant('category'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'txn_date', columns: {#date})
@TableIndex(name: 'txn_cat_date', columns: {#categoryId, #date})
@TableIndex(name: 'txn_acc_date', columns: {#accountId, #date})
@TableIndex(name: 'txn_source_ref', columns: {#sourceRef})
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // credit | debit | transfer
  IntColumn get amountMinor => integer()();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()(); // transfers only
  TextColumn get categoryId => text().nullable()(); // leaf category
  TextColumn get paymentMethod => text().nullable()(); // cash | card | other
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get merchant => text().nullable()();
  // manual | sms | debt (principal movement) | interest (interest paid/received)
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get direction => text()(); // receivable | liability
  TextColumn get counterparty => text()();
  IntColumn get principalMinor => integer()();
  TextColumn get issuedOn => text()();
  TextColumn get dueOn => text().nullable()();
  BoolColumn get interestEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get interestType => text().withDefault(const Constant('simple'))();
  IntColumn get rateBps => integer().withDefault(const Constant(0))();
  TextColumn get ratePeriod => text().withDefault(const Constant('monthly'))();
  TextColumn get accountId => text()(); // account that cash legs post to
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'debt_ev_debt', columns: {#debtId, #date})
class DebtEvents extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text()();
  TextColumn get type => text()(); // issue | repayment | accrual | writeoff
  IntColumn get amountMinor => integer()();
  TextColumn get date => text()();
  IntColumn get principalPart => integer().withDefault(const Constant(0))();
  IntColumn get interestPart => integer().withDefault(const Constant(0))();
  IntColumn get periodKey => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Device-local (never synced): SMS candidates awaiting review.
class SmsInbox extends Table {
  TextColumn get id => text()();
  TextColumn get fingerprint => text().unique()();
  TextColumn get semanticKey => text()();
  TextColumn get sender => text()();
  TextColumn get body => text()(); // purged ('') once resolved
  TextColumn get direction => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get date => text()();
  TextColumn get merchant => text().nullable()();
  TextColumn get accountRef => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending|confirmed|discarded
  @override
  Set<Column> get primaryKey => {id};
}

/// Device-local key/value settings.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Debts,
    DebtEvents,
    SmsInbox,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  static AppDatabase file() => AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'cash_buddy.sqlite')),
      );
    }),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // One ledger row per debt-event leg: retries/sync can never double-post.
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS uq_txn_source_ref ON transactions(source_ref) WHERE source_ref IS NOT NULL AND deleted_at IS NULL',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS uq_debt_accrual ON debt_events(debt_id, period_key) WHERE period_key IS NOT NULL AND deleted_at IS NULL',
      );
    },
  );
}

import 'package:drift/drift.dart';

import 'db_open.dart';

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

/// Something money was put into: mutual fund, stock or a custom investment. Only the
/// name and kind are required; every other field is optional.
class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // mutual_fund | stock | custom
  TextColumn get name => text()();
  TextColumn get accountId => text().nullable()(); // default paying account
  TextColumn get startDate => text().nullable()();
  IntColumn get expectedGrowthBps => integer().nullable()(); // per year
  IntColumn get currentValueMinor => integer().nullable()();
  TextColumn get valueUpdatedOn => text().nullable()();
  RealColumn get units => real().nullable()();
  IntColumn get buyPriceMinor => integer().nullable()();
  IntColumn get sipMinor => integer().nullable()();
  // Recurring plan (custom investments; see domain/schedule.dart). The amount
  // of each instalment is [sipMinor]; start is [startDate].
  BoolColumn get recurring => boolean().withDefault(const Constant(false))();
  TextColumn get cycle => text().nullable()(); // daily|weekly|monthly|yearly
  IntColumn get everyN => integer().withDefault(const Constant(1))();
  IntColumn get weekday => integer().nullable()(); // 1 = Mon .. 7 = Sun
  IntColumn get monthDay => integer().nullable()();
  TextColumn get timeOfDay => text().nullable()(); // HH:mm, daily only
  IntColumn get installments => integer().nullable()(); // null = no count limit
  TextColumn get endDate => text().nullable()(); // null = no end date
  // Legacy chit-fund columns (chit funds were folded into custom investments).
  IntColumn get chitValueMinor => integer().nullable()();
  IntColumn get tenureMonths => integer().nullable()();
  IntColumn get members => integer().nullable()();
  IntColumn get monthlyMinor => integer().nullable()();
  IntColumn get commissionBps => integer().nullable()();
  TextColumn get organiser => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'inv_entry_inv', columns: {#investmentId, #date})
class InvestmentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get investmentId => text()();
  // contribute | withdraw | dividend | payout
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get date => text()();
  IntColumn get periodKey => integer().nullable()(); // chit month index
  BoolColumn get postToBalance => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Budget data, synced like everything else. Row ids are deterministic:
///  `base`            the amount that applies to every month
///  `month:YYYY-MM`   a one-month override
///  `split:<catId>`   money set aside for a main category
///  `since`           the first month a budget existed ([key] = YYYY-MM)
///  `result:YYYY-MM`  frozen result of a finished month (amount = budget,
///                    spent = what was spent)
class BudgetItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // base | month | split | since | result
  TextColumn get key => text().withDefault(const Constant(''))();
  IntColumn get amountMinor => integer().withDefault(const Constant(0))();
  IntColumn get spentMinor => integer().withDefault(const Constant(0))();
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
    Investments,
    InvestmentEntries,
    BudgetItems,
    SmsInbox,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Chit funds became custom monthly plans: one instalment per month for the
  /// old tenure, of the old monthly amount.
  static const chitMigrationSql =
      "UPDATE investments SET kind='custom', recurring=1, cycle='monthly', "
      "every_n=1, installments=tenure_months, sip_minor=monthly_minor "
      "WHERE kind='chit'";

  /// Native file on mobile, WASM/IndexedDB in the browser (see db_open.dart).
  static AppDatabase open() => AppDatabase(openAppDatabase());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(investments);
        await m.createTable(investmentEntries);
      }
      if (from == 2) {
        await m.addColumn(investments, investments.recurring);
        await m.addColumn(investments, investments.cycle);
        await m.addColumn(investments, investments.everyN);
        await m.addColumn(investments, investments.weekday);
        await m.addColumn(investments, investments.monthDay);
        await m.addColumn(investments, investments.timeOfDay);
        await m.addColumn(investments, investments.installments);
        await m.addColumn(investments, investments.endDate);
      }
      if (from < 4) {
        await m.createTable(budgetItems);
      }
      if (from < 3) {
        // Chit funds became custom monthly plans: instalment = monthly amount,
        // number of instalments = tenure.
        await customStatement(chitMigrationSql);
      }
    },
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

import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/hlc.dart';
import '../domain/interest.dart';
import '../domain/sms_parser.dart';
import 'db.dart';

class OverpaymentException implements Exception {
  final int excessMinor;
  OverpaymentException(this.excessMinor);
  @override
  String toString() =>
      'Payment exceeds the outstanding balance by $excessMinor';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class TxnFilter {
  final String? query;
  final String? type;
  final String? categoryId; // matches the category and its children
  final String? accountId;
  final String? paymentMethod;
  final String? source;
  final DateRange? range;
  final int? minMinor;
  final int? maxMinor;
  const TxnFilter({
    this.query,
    this.type,
    this.categoryId,
    this.accountId,
    this.paymentMethod,
    this.source,
    this.range,
    this.minMinor,
    this.maxMinor,
  });
  bool get isEmpty =>
      query == null &&
      type == null &&
      categoryId == null &&
      accountId == null &&
      paymentMethod == null &&
      source == null &&
      range == null &&
      minMinor == null &&
      maxMinor == null;
}

class CatSlice {
  final String categoryId;
  final String name;
  final int colorValue;
  final int totalMinor;
  const CatSlice(this.categoryId, this.name, this.colorValue, this.totalMinor);
}

class DebtSummary {
  final Debt debt;
  final DebtState state;
  const DebtSummary(this.debt, this.state);
  bool get settled => state.outstanding == 0;
  String get status =>
      settled ? 'settled' : (state.totalPaid > 0 ? 'partial' : 'open');
}

class DashboardData {
  final DateRange range;
  final int spending, income, prevSpending, prevIncome;
  final int incomingDebts,
      liabilities; // outstanding as of range end (capped at today)
  final int incomingPrincipal,
      incomingInterest,
      liabilityPrincipal,
      liabilityInterest;
  final List<CatSlice> spendingByCategory, incomeByCategory;
  final Map<String, int> dailySpending, dailyIncome;
  final int cashSpending, cardSpending;
  final List<MapEntry<String, int>> spendingByAccount;
  final List<DebtSummary> receivables, liabilityList;
  final int totalBalance;
  const DashboardData({
    required this.range,
    required this.spending,
    required this.income,
    required this.prevSpending,
    required this.prevIncome,
    required this.incomingDebts,
    required this.liabilities,
    required this.incomingPrincipal,
    required this.incomingInterest,
    required this.liabilityPrincipal,
    required this.liabilityInterest,
    required this.spendingByCategory,
    required this.incomeByCategory,
    required this.dailySpending,
    required this.dailyIncome,
    required this.cashSpending,
    required this.cardSpending,
    required this.spendingByAccount,
    required this.receivables,
    required this.liabilityList,
    required this.totalBalance,
  });
}

class Repo {
  final AppDatabase db;
  final Hlc clock;
  final DateTime Function() now;
  Repo(this.db, this.clock, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  static final _rng = Random.secure();
  static String newId([String prefix = '']) {
    final b = List.generate(
      8,
      (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '$prefix$b';
  }

  String get _nowIso => now().toUtc().toIso8601String();
  DateTime get today => Dates.fromLocal(now());

  // ───────────────────────── settings ─────────────────────────
  Future<String?> getSetting(String key) async {
    final r = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return r?.value;
  }

  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<bool> get isOnboarded async => (await getSetting('onboarded')) == '1';
  Future<String> get accountMode async =>
      (await getSetting('accountMode')) ?? 'combined';
  Future<String> get dataMode async =>
      (await getSetting('dataMode')) ?? 'offline';
  Future<bool> get cashCardEnabled async =>
      (await getSetting('cashCard')) == '1';

  /// Emits whenever any data table changes (used to refresh UI providers).
  Stream<void> get changes => db.tableUpdates();

  // ───────────────────────── onboarding ─────────────────────────
  Future<void> completeOnboarding({
    required String dataMode,
    required String accountMode,
    required bool cashCard,
    int openingCashMinor = 0,
    int openingBankMinor = 0,
  }) async {
    await db.transaction(() async {
      await setSetting('dataMode', dataMode);
      await setSetting('accountMode', accountMode);
      await setSetting('cashCard', cashCard ? '1' : '0');
      await seedCategories();
      if (accountMode == 'combined') {
        await _putAccount(
          AccountsCompanion.insert(
            id: 'acc_overall',
            name: 'Overall',
            kind: 'overall',
            colorValue: 0xFF2F6BFF,
            hlc: clock.next(),
            openingMinor: Value(openingCashMinor + openingBankMinor),
          ),
        );
      } else {
        await _putAccount(
          AccountsCompanion.insert(
            id: 'acc_cash',
            name: 'Cash',
            kind: 'cash',
            colorValue: 0xFF1FA971,
            hlc: clock.next(),
            openingMinor: Value(openingCashMinor),
            sortOrder: const Value(0),
          ),
        );
        await _putAccount(
          AccountsCompanion.insert(
            id: 'acc_bank',
            name: 'Bank',
            kind: 'bank',
            colorValue: 0xFF2F6BFF,
            hlc: clock.next(),
            openingMinor: Value(openingBankMinor),
            sortOrder: const Value(1),
          ),
        );
      }
      await setSetting('onboarded', '1');
    });
  }

  static const _palette = [
    0xFF2F6BFF,
    0xFF1FA971,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF84CC16,
    0xFFF97316,
    0xFF14B8A6,
    0xFF6366F1,
    0xFF64748B,
  ];

  Future<void> seedCategories() async {
    var order = 0;
    Future<void> cat(
      String id,
      String name,
      String kind,
      int color, {
      String? parent,
      String icon = 'category',
    }) => _putCategory(
      CategoriesCompanion.insert(
        id: id,
        name: name,
        kind: kind,
        colorValue: color,
        hlc: clock.next(),
        parentId: Value(parent),
        iconKey: Value(icon),
        sortOrder: Value(order++),
      ),
    );
    // Credit
    await cat('cat_salary', 'Salary', 'credit', _palette[1], icon: 'work');
    await cat(
      'cat_cash_received',
      'Cash Received',
      'credit',
      _palette[5],
      icon: 'payments',
    );
    await cat(
      'cat_interest_income',
      'Interest Income',
      'credit',
      _palette[2],
      icon: 'percent',
    );
    await cat('cat_refund', 'Refund', 'credit', _palette[4], icon: 'undo');
    await cat('cat_gift', 'Gift', 'credit', _palette[6], icon: 'card_giftcard');
    await cat('cat_other_income', 'Other Income', 'credit', _palette[11]);
    // Debit (main -> sub)
    final tree = <String, (int, List<String>)>{
      'Food': (_palette[8], ['Groceries', 'Dining', 'Coffee']),
      'Transport': (_palette[0], ['Fuel', 'Cab', 'Public']),
      'Bills': (_palette[3], ['Rent', 'Electricity', 'Internet']),
      'Entertainment': (_palette[4], ['Movies', 'Streaming', 'Games']),
      'Shopping': (_palette[6], []),
      'Health': (_palette[9], []),
      'Education': (_palette[10], []),
      'Travel': (_palette[5], []),
      'Interest Paid': (_palette[2], []),
      'Other': (_palette[11], []),
    };
    for (final e in tree.entries) {
      final pid = 'cat_${_slug(e.key)}';
      await cat(pid, e.key, 'debit', e.value.$1);
      for (final s in e.value.$2) {
        await cat('${pid}_${_slug(s)}', s, 'debit', e.value.$1, parent: pid);
      }
    }
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ───────────────────────── low level writes ─────────────────────────
  // Compare-before-write: unchanged rows keep their hlc, so syncing and
  // reconciling never churns versions.
  Future<void> _putAccount(AccountsCompanion c) =>
      db.into(db.accounts).insertOnConflictUpdate(c);
  Future<void> _putCategory(CategoriesCompanion c) =>
      db.into(db.categories).insertOnConflictUpdate(c);

  // ───────────────────────── accounts ─────────────────────────
  Future<List<Account>> accounts({bool includeArchived = false}) =>
      (db.select(db.accounts)
            ..where(
              (a) =>
                  a.deletedAt.isNull() &
                  (includeArchived
                      ? const Constant(true)
                      : a.archived.equals(false)),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .get();

  Future<String> defaultAccountId() async {
    final list = await accounts();
    if (list.isEmpty) throw StateError('No accounts');
    if (await accountMode == 'combined') {
      return list
          .firstWhere((a) => a.kind != 'cash', orElse: () => list.first)
          .id;
    }
    return list.first.id;
  }

  Future<String> addAccount(
    String name, {
    String kind = 'bank',
    int openingMinor = 0,
    int? color,
    String? last4,
  }) async {
    if (name.trim().isEmpty) throw ValidationException('Account name required');
    final id = newId('acc_');
    final n = (await accounts(includeArchived: true)).length;
    await _putAccount(
      AccountsCompanion.insert(
        id: id,
        name: name.trim(),
        kind: kind,
        colorValue: color ?? _palette[n % _palette.length],
        hlc: clock.next(),
        openingMinor: Value(openingMinor),
        last4: Value(last4),
        sortOrder: Value(n),
      ),
    );
    return id;
  }

  Future<void> updateAccount(
    String id, {
    String? name,
    int? openingMinor,
    bool? archived,
    int? color,
  }) async {
    final a = await (db.select(
      db.accounts,
    )..where((t) => t.id.equals(id))).getSingle();
    await _putAccount(
      AccountsCompanion(
        id: Value(id),
        name: Value(name ?? a.name),
        kind: Value(a.kind),
        colorValue: Value(color ?? a.colorValue),
        openingMinor: Value(openingMinor ?? a.openingMinor),
        archived: Value(archived ?? a.archived),
        hlc: Value(clock.next()),
      ),
    );
  }

  /// Balance per account: opening + credits - debits - transfers out + transfers in.
  /// Derived straight from the ledger, so it can never drift from transactions.
  Future<Map<String, int>> balances() async {
    final rows = await db
        .customSelect(
          '''
      SELECT a.id AS id,
        a.opening_minor
        + COALESCE((SELECT SUM(CASE t.type WHEN 'credit' THEN t.amount_minor ELSE -t.amount_minor END)
                    FROM transactions t WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
        + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
                    WHERE t.to_account_id = a.id AND t.type = 'transfer' AND t.deleted_at IS NULL), 0) AS bal
      FROM accounts a WHERE a.deleted_at IS NULL''',
          readsFrom: {db.accounts, db.transactions},
        )
        .get();
    return {for (final r in rows) r.read<String>('id'): r.read<int>('bal')};
  }

  Future<int> totalBalance() async =>
      (await balances()).values.fold<int>(0, (a, b) => a + b);

  /// Switches Combined <-> Split without changing any balance.
  Future<void> setAccountMode(String mode) async {
    await db.transaction(() async {
      final before = await totalBalance();
      if (mode == 'split') {
        final all = await accounts(includeArchived: true);
        if (!all.any((a) => a.kind == 'cash')) {
          await _putAccount(
            AccountsCompanion.insert(
              id: 'acc_cash',
              name: 'Cash',
              kind: 'cash',
              colorValue: 0xFF1FA971,
              hlc: clock.next(),
              sortOrder: const Value(0),
            ),
          );
        }
        final overall = all.where((a) => a.kind == 'overall').toList();
        for (final o in overall) {
          await _putAccount(
            AccountsCompanion(
              id: Value(o.id),
              name: const Value('Bank'),
              kind: const Value('bank'),
              colorValue: Value(o.colorValue),
              hlc: Value(clock.next()),
              sortOrder: const Value(1),
            ),
          );
        }
      }
      await setSetting('accountMode', mode);
      final after = await totalBalance();
      if (before != after) {
        throw StateError('Balance changed during mode switch');
      }
    });
  }

  // ───────────────────────── categories ─────────────────────────
  Future<List<Category>> categories({
    String? kind,
    bool includeArchived = false,
  }) =>
      (db.select(db.categories)
            ..where(
              (c) =>
                  c.deletedAt.isNull() &
                  (kind == null ? const Constant(true) : c.kind.equals(kind)) &
                  (includeArchived
                      ? const Constant(true)
                      : c.archived.equals(false)),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<String> addCategory(
    String name,
    String kind, {
    String? parentId,
    int? color,
  }) async {
    if (name.trim().isEmpty) {
      throw ValidationException('Category name required');
    }
    if (parentId != null) {
      final p = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(parentId))).getSingle();
      if (p.parentId != null) {
        throw ValidationException('Only two category levels are supported');
      }
      if (p.kind != kind) {
        throw ValidationException('Subcategory kind must match parent');
      }
    }
    final id = newId('cat_');
    final n = (await categories(includeArchived: true)).length;
    await _putCategory(
      CategoriesCompanion.insert(
        id: id,
        name: name.trim(),
        kind: kind,
        colorValue: color ?? _palette[n % _palette.length],
        hlc: clock.next(),
        parentId: Value(parentId),
        sortOrder: Value(n),
      ),
    );
    return id;
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    int? color,
    String? iconKey,
    bool? archived,
    String? parentId,
    bool clearParent = false,
  }) async {
    final c = await (db.select(
      db.categories,
    )..where((t) => t.id.equals(id))).getSingle();
    var newParent = clearParent ? null : (parentId ?? c.parentId);
    if (newParent != null) {
      if (newParent == id) {
        throw ValidationException('Category cannot be its own parent');
      }
      final p = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(newParent))).getSingle();
      if (p.parentId != null) {
        throw ValidationException('Only two category levels are supported');
      }
      final kids = await (db.select(
        db.categories,
      )..where((t) => t.parentId.equals(id) & t.deletedAt.isNull())).get();
      if (kids.isNotEmpty) {
        throw ValidationException(
          'A category with subcategories cannot become a subcategory',
        );
      }
    }
    await _putCategory(
      CategoriesCompanion(
        id: Value(id),
        name: Value(name ?? c.name),
        kind: Value(c.kind),
        parentId: Value(newParent),
        colorValue: Value(color ?? c.colorValue),
        iconKey: Value(iconKey ?? c.iconKey),
        archived: Value(archived ?? c.archived),
        hlc: Value(clock.next()),
      ),
    );
  }

  /// Deleting a category that has history requires a replacement (never orphan).
  Future<void> deleteCategory(String id, {String? reassignTo}) async {
    await db.transaction(() async {
      final kids = await (db.select(
        db.categories,
      )..where((c) => c.parentId.equals(id) & c.deletedAt.isNull())).get();
      final ids = [id, ...kids.map((k) => k.id)];
      final used = await (db.select(
        db.transactions,
      )..where((t) => t.categoryId.isIn(ids) & t.deletedAt.isNull())).get();
      if (used.isNotEmpty) {
        if (reassignTo == null || ids.contains(reassignTo)) {
          throw ValidationException(
            'Category has ${used.length} transactions; choose a replacement',
          );
        }
        for (final t in used) {
          await _writeTxnRow(
            t
                .toCompanion(true)
                .copyWith(
                  categoryId: Value(reassignTo),
                  hlc: Value(clock.next()),
                ),
          );
        }
      }
      for (final cid in ids) {
        final c = await (db.select(
          db.categories,
        )..where((t) => t.id.equals(cid))).getSingle();
        await _putCategory(
          c
              .toCompanion(true)
              .copyWith(deletedAt: Value(_nowIso), hlc: Value(clock.next())),
        );
      }
    });
  }

  // ───────────────────────── transactions ─────────────────────────
  Future<void> _writeTxnRow(TransactionsCompanion c) =>
      db.into(db.transactions).insertOnConflictUpdate(c);

  void _validateTxn(
    String type,
    int amount,
    String? toAccountId,
    String accountId,
  ) {
    if (!{'credit', 'debit', 'transfer'}.contains(type)) {
      throw ValidationException('Bad type');
    }
    if (amount <= 0) throw ValidationException('Amount must be positive');
    if (type == 'transfer') {
      if (toAccountId == null) {
        throw ValidationException('Transfer needs a destination account');
      }
      if (toAccountId == accountId) {
        throw ValidationException('Transfer accounts must differ');
      }
    }
  }

  Future<String> addTransaction({
    required String type,
    required int amountMinor,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? paymentMethod,
    DateTime? date,
    String note = '',
    String? merchant,
    String source = 'manual',
    String? sourceRef,
    String? id,
  }) async {
    final acc = accountId ?? await defaultAccountId();
    _validateTxn(type, amountMinor, toAccountId, acc);
    final tid = id ?? newId('txn_');
    await _writeTxnRow(
      TransactionsCompanion.insert(
        id: tid,
        type: type,
        amountMinor: amountMinor,
        accountId: acc,
        date: Dates.str(date ?? today),
        hlc: clock.next(),
        toAccountId: Value(toAccountId),
        categoryId: Value(categoryId),
        paymentMethod: Value(paymentMethod),
        note: Value(note),
        merchant: Value(merchant),
        source: Value(source),
        sourceRef: Value(sourceRef),
      ),
    );
    return tid;
  }

  Future<Transaction> getTransaction(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  Future<void> updateTransaction(
    String id, {
    String? type,
    int? amountMinor,
    String? accountId,
    String? toAccountId,
    bool clearTo = false,
    String? categoryId,
    bool clearCategory = false,
    String? paymentMethod,
    DateTime? date,
    String? note,
    String? merchant,
  }) async {
    final t = await getTransaction(id);
    if (t.deletedAt != null) {
      throw ValidationException('Transaction was deleted');
    }
    if (t.source == 'debt' || t.source == 'interest') {
      throw ValidationException(
        'This entry is managed by a debt; edit it from the Debts tab',
      );
    }
    final nt = type ?? t.type;
    final amt = amountMinor ?? t.amountMinor;
    final acc = accountId ?? t.accountId;
    final to = nt == 'transfer'
        ? (clearTo ? null : (toAccountId ?? t.toAccountId))
        : null;
    _validateTxn(nt, amt, to, acc);
    await _writeTxnRow(
      TransactionsCompanion(
        id: Value(id),
        type: Value(nt),
        amountMinor: Value(amt),
        accountId: Value(acc),
        toAccountId: Value(to),
        categoryId: Value(
          nt == 'transfer'
              ? null
              : (clearCategory ? null : (categoryId ?? t.categoryId)),
        ),
        paymentMethod: Value(paymentMethod ?? t.paymentMethod),
        date: Value(date != null ? Dates.str(date) : t.date),
        note: Value(note ?? t.note),
        merchant: Value(merchant ?? t.merchant),
        source: Value(t.source),
        sourceRef: Value(t.sourceRef),
        hlc: Value(clock.next()),
      ),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final t = await getTransaction(id);
    if (t.source == 'debt' || t.source == 'interest') {
      throw ValidationException(
        'This entry is managed by a debt; edit it from the Debts tab',
      );
    }
    await _writeTxnRow(
      t
          .toCompanion(true)
          .copyWith(deletedAt: Value(_nowIso), hlc: Value(clock.next())),
    );
  }

  Future<void> restoreTransaction(String id) async {
    final t = await getTransaction(id);
    await _writeTxnRow(
      t
          .toCompanion(true)
          .copyWith(deletedAt: const Value(null), hlc: Value(clock.next())),
    );
  }

  Future<List<Transaction>> searchTransactions(
    TxnFilter f, {
    int limit = 500,
    int offset = 0,
  }) async {
    Set<String>? catIds;
    if (f.categoryId != null) {
      final kids = await (db.select(
        db.categories,
      )..where((c) => c.parentId.equals(f.categoryId!))).get();
      catIds = {f.categoryId!, ...kids.map((k) => k.id)};
    }
    final q = db.select(db.transactions)
      ..where((t) {
        Expression<bool> e = t.deletedAt.isNull();
        if (f.type != null) e = e & t.type.equals(f.type!);
        if (catIds != null) e = e & t.categoryId.isIn(catIds);
        if (f.accountId != null) {
          e =
              e &
              (t.accountId.equals(f.accountId!) |
                  t.toAccountId.equals(f.accountId!));
        }
        if (f.paymentMethod != null) {
          e = e & t.paymentMethod.equals(f.paymentMethod!);
        }
        if (f.source != null) e = e & t.source.equals(f.source!);
        if (f.range != null) {
          e = e & t.date.isBetweenValues(f.range!.startStr, f.range!.endStr);
        }
        if (f.minMinor != null) {
          e = e & t.amountMinor.isBiggerOrEqualValue(f.minMinor!);
        }
        if (f.maxMinor != null) {
          e = e & t.amountMinor.isSmallerOrEqualValue(f.maxMinor!);
        }
        if (f.query != null && f.query!.trim().isNotEmpty) {
          final like =
              '%${f.query!.trim().replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
          e = e & (t.note.like(like) | t.merchant.like(like));
        }
        return e;
      })
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.hlc),
      ])
      ..limit(limit, offset: offset);
    return q.get();
  }

  // ───────────────────────── debts ─────────────────────────
  DebtTerms _terms(Debt d) => DebtTerms(
    principalMinor: d.principalMinor,
    issuedOn: Dates.parse(d.issuedOn),
    interestEnabled: d.interestEnabled,
    interestType: d.interestType == 'compound'
        ? InterestType.compound
        : InterestType.simple,
    rateBps: d.rateBps,
    ratePeriod: RatePeriod.values.firstWhere(
      (p) => p.name == d.ratePeriod,
      orElse: () => RatePeriod.monthly,
    ),
  );

  Future<List<DebtEvent>> _events(
    String debtId, {
    bool includeDeleted = false,
  }) =>
      (db.select(db.debtEvents)
            ..where(
              (e) =>
                  e.debtId.equals(debtId) &
                  (includeDeleted
                      ? const Constant(true)
                      : e.deletedAt.isNull()),
            )
            ..orderBy([
              (e) => OrderingTerm.asc(e.date),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  List<DebtPayment> _payments(List<DebtEvent> ev) => [
    for (final e in ev)
      if (e.deletedAt == null &&
          (e.type == 'repayment' || e.type == 'writeoff'))
        DebtPayment(e.id, Dates.parse(e.date), e.amountMinor),
  ];

  Future<String> createDebt({
    required String direction, // receivable | liability
    required String counterparty,
    required int principalMinor,
    DateTime? issuedOn,
    DateTime? dueOn,
    bool interestEnabled = false,
    String interestType = 'simple',
    int rateBps = 0,
    String ratePeriod = 'monthly',
    String? accountId,
    String note = '',
  }) async {
    if (!{'receivable', 'liability'}.contains(direction)) {
      throw ValidationException('Bad direction');
    }
    if (counterparty.trim().isEmpty) {
      throw ValidationException('Counterparty required');
    }
    if (principalMinor <= 0) {
      throw ValidationException('Principal must be positive');
    }
    if (interestEnabled && rateBps <= 0) {
      throw ValidationException('Interest rate must be positive');
    }
    final id = newId('debt_');
    final acc = accountId ?? await defaultAccountId();
    final on = Dates.str(issuedOn ?? today);
    await db.transaction(() async {
      await db
          .into(db.debts)
          .insert(
            DebtsCompanion.insert(
              id: id,
              direction: direction,
              counterparty: counterparty.trim(),
              principalMinor: principalMinor,
              issuedOn: on,
              accountId: acc,
              hlc: clock.next(),
              dueOn: Value(dueOn == null ? null : Dates.str(dueOn)),
              interestEnabled: Value(interestEnabled),
              interestType: Value(interestType),
              rateBps: Value(interestEnabled ? rateBps : 0),
              ratePeriod: Value(ratePeriod),
              note: Value(note),
            ),
          );
      await db
          .into(db.debtEvents)
          .insert(
            DebtEventsCompanion.insert(
              id: 'ev_${id}_issue',
              debtId: id,
              type: 'issue',
              amountMinor: principalMinor,
              date: on,
              hlc: clock.next(),
              principalPart: Value(principalMinor),
            ),
          );
      await reconcileDebt(id);
    });
    return id;
  }

  /// Records a repayment (a payment received for receivables / made for liabilities).
  Future<String> addRepayment(
    String debtId,
    int amountMinor, {
    DateTime? date,
    String note = '',
    bool writeOff = false,
  }) async {
    if (amountMinor <= 0) throw ValidationException('Amount must be positive');
    final debt = await (db.select(
      db.debts,
    )..where((d) => d.id.equals(debtId))).getSingle();
    final d = date ?? today;
    if (d.isBefore(Dates.parse(debt.issuedOn))) {
      throw ValidationException('Payment is before the debt was issued');
    }
    final id = newId('ev_');
    await db.transaction(() async {
      final existing = await _events(debtId);
      final all = [..._payments(existing), DebtPayment(id, d, amountMinor)];
      final state = InterestEngine.replay(_terms(debt), all, _maxDate(d));
      final excess = state.allocations[id]?.excessMinor ?? 0;
      if (excess > 0) throw OverpaymentException(excess);
      // A later-dated payment may also push earlier ones over after allocation shifts.
      if (state.allocations.values.any((a) => a.excessMinor > 0)) {
        throw OverpaymentException(
          state.allocations.values.fold<int>(0, (s, a) => s + a.excessMinor),
        );
      }
      await db
          .into(db.debtEvents)
          .insert(
            DebtEventsCompanion.insert(
              id: id,
              debtId: debtId,
              type: writeOff ? 'writeoff' : 'repayment',
              amountMinor: amountMinor,
              date: Dates.str(d),
              hlc: clock.next(),
              note: Value(note),
            ),
          );
      await reconcileDebt(debtId);
    });
    return id;
  }

  DateTime _maxDate(DateTime d) => d.isAfter(today) ? d : today;

  Future<void> deleteDebtEvent(String eventId) async {
    final e = await (db.select(
      db.debtEvents,
    )..where((x) => x.id.equals(eventId))).getSingle();
    if (e.type == 'accrual') {
      throw ValidationException('Accruals are computed automatically');
    }
    if (e.type == 'issue') {
      throw ValidationException('Delete the whole debt instead');
    }
    await db.transaction(() async {
      await db
          .into(db.debtEvents)
          .insertOnConflictUpdate(
            e
                .toCompanion(true)
                .copyWith(deletedAt: Value(_nowIso), hlc: Value(clock.next())),
          );
      await reconcileDebt(e.debtId);
    });
  }

  Future<void> deleteDebt(String debtId) async {
    await db.transaction(() async {
      final d = await (db.select(
        db.debts,
      )..where((x) => x.id.equals(debtId))).getSingle();
      await db
          .into(db.debts)
          .insertOnConflictUpdate(
            d
                .toCompanion(true)
                .copyWith(deletedAt: Value(_nowIso), hlc: Value(clock.next())),
          );
      for (final e in await _events(debtId)) {
        await db
            .into(db.debtEvents)
            .insertOnConflictUpdate(
              e
                  .toCompanion(true)
                  .copyWith(
                    deletedAt: Value(_nowIso),
                    hlc: Value(clock.next()),
                  ),
            );
      }
      await reconcileDebt(debtId);
    });
  }

  /// Idempotent: rebuilds accruals, repayment allocations and the linked
  /// ledger legs from the debt's events. Safe to call any number of times, on
  /// any device; unchanged rows are not rewritten.
  Future<void> reconcileDebt(String debtId) async {
    final debt = await (db.select(
      db.debts,
    )..where((d) => d.id.equals(debtId))).getSingleOrNull();
    if (debt == null) return;
    final allEvents = await _events(debtId, includeDeleted: true);
    final live = allEvents.where((e) => e.deletedAt == null).toList();
    final debtLive = debt.deletedAt == null;
    final state = InterestEngine.replay(
      _terms(debt),
      _payments(debtLive ? live : []),
      _maxDate(today),
    );

    // 1) accruals (non-cash)
    final desired = {for (final a in state.accruals) a.periodIndex: a};
    final existing = {
      for (final e in allEvents)
        if (e.type == 'accrual') e.periodKey!: e,
    };
    for (final a in desired.values) {
      final id = 'acc_${debtId}_${a.periodIndex}';
      final cur = existing[a.periodIndex];
      if (cur != null &&
          cur.deletedAt == null &&
          cur.amountMinor == a.amountMinor &&
          cur.date == Dates.str(a.date)) {
        continue;
      }
      await db
          .into(db.debtEvents)
          .insertOnConflictUpdate(
            DebtEventsCompanion.insert(
              id: id,
              debtId: debtId,
              type: 'accrual',
              amountMinor: a.amountMinor,
              date: Dates.str(a.date),
              hlc: clock.next(),
              periodKey: Value(a.periodIndex),
              interestPart: Value(a.amountMinor),
            ),
          );
    }
    for (final e in existing.values) {
      if (e.deletedAt == null && !desired.containsKey(e.periodKey)) {
        await db
            .into(db.debtEvents)
            .insertOnConflictUpdate(
              e
                  .toCompanion(true)
                  .copyWith(
                    deletedAt: Value(_nowIso),
                    hlc: Value(clock.next()),
                  ),
            );
      }
    }

    // 2) allocation of each repayment
    for (final e in live.where(
      (e) => e.type == 'repayment' || e.type == 'writeoff',
    )) {
      final a = state.allocations[e.id];
      if (a == null) continue; // dated in the future: not yet applied
      if (a.interestMinor != e.interestPart ||
          a.principalMinor != e.principalPart) {
        await db
            .into(db.debtEvents)
            .insertOnConflictUpdate(
              e
                  .toCompanion(true)
                  .copyWith(
                    interestPart: Value(a.interestMinor),
                    principalPart: Value(a.principalMinor),
                    hlc: Value(clock.next()),
                  ),
            );
      }
    }

    // 3) ledger legs: at most one row per (event, leg), keyed by source_ref
    final isRec = debt.direction == 'receivable';
    final legs = <String, _Leg>{};
    if (debtLive) {
      for (final e in live) {
        if (e.type == 'issue') {
          legs['ev:${e.id}:p'] = _Leg(
            isRec ? 'debit' : 'credit',
            e.amountMinor,
            e.date,
            'debt',
            null,
          );
        } else if (e.type == 'repayment') {
          final a = state.allocations[e.id];
          if (a == null) continue;
          if (a.principalMinor > 0) {
            legs['ev:${e.id}:p'] = _Leg(
              isRec ? 'credit' : 'debit',
              a.principalMinor,
              e.date,
              'debt',
              null,
            );
          }
          if (a.interestMinor > 0) {
            legs['ev:${e.id}:i'] = _Leg(
              isRec ? 'credit' : 'debit',
              a.interestMinor,
              e.date,
              'interest',
              isRec ? 'cat_interest_income' : 'cat_interest_paid',
            );
          }
        }
      }
    }
    final refs = <String>{};
    for (final e in allEvents) {
      refs
        ..add('ev:${e.id}:p')
        ..add('ev:${e.id}:i');
    }
    final existingLegs =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.sourceRef.isIn(refs) &
                  (t.source.equals('debt') | t.source.equals('interest')),
            ))
            .get();
    final byRef = {for (final t in existingLegs) t.sourceRef!: t};
    for (final entry in legs.entries) {
      final cur = byRef[entry.key];
      final l = entry.value;
      final same =
          cur != null &&
          cur.deletedAt == null &&
          cur.type == l.type &&
          cur.amountMinor == l.amount &&
          cur.date == l.date &&
          cur.accountId == debt.accountId &&
          cur.categoryId == l.categoryId &&
          cur.source == l.source &&
          cur.merchant == debt.counterparty;
      if (same) continue;
      await _writeTxnRow(
        TransactionsCompanion.insert(
          id: 'led:${entry.key}',
          type: l.type,
          amountMinor: l.amount,
          accountId: debt.accountId,
          date: l.date,
          hlc: clock.next(),
          categoryId: Value(l.categoryId),
          merchant: Value(debt.counterparty),
          note: Value(
            isRec
                ? 'Lent: ${debt.counterparty}'
                : 'Borrowed: ${debt.counterparty}',
          ),
          source: Value(l.source),
          sourceRef: Value(entry.key),
        ),
      );
    }
    for (final t in existingLegs) {
      if (t.deletedAt == null && !legs.containsKey(t.sourceRef)) {
        await _writeTxnRow(
          t
              .toCompanion(true)
              .copyWith(deletedAt: Value(_nowIso), hlc: Value(clock.next())),
        );
      }
    }
  }

  Future<void> reconcileAllDebts() async {
    final all = await db.select(db.debts).get();
    for (final d in all) {
      await reconcileDebt(d.id);
    }
  }

  Future<List<Debt>> debts({String? direction}) =>
      (db.select(db.debts)
            ..where(
              (d) =>
                  d.deletedAt.isNull() &
                  (direction == null
                      ? const Constant(true)
                      : d.direction.equals(direction)),
            )
            ..orderBy([(d) => OrderingTerm.desc(d.issuedOn)]))
          .get();

  Future<DebtState> debtState(String debtId, {DateTime? asOf}) async {
    final d = await (db.select(
      db.debts,
    )..where((x) => x.id.equals(debtId))).getSingle();
    return InterestEngine.replay(
      _terms(d),
      _payments(await _events(debtId)),
      asOf ?? today,
    );
  }

  Future<List<DebtSummary>> debtSummaries({
    String? direction,
    DateTime? asOf,
  }) async {
    final out = <DebtSummary>[];
    for (final d in await debts(direction: direction)) {
      if (asOf != null && Dates.parse(d.issuedOn).isAfter(asOf)) continue;
      out.add(DebtSummary(d, await debtState(d.id, asOf: asOf)));
    }
    return out;
  }

  Future<List<DebtEvent>> debtTimeline(String debtId) async =>
      (await _events(debtId)).reversed.toList();

  // ───────────────────────── dashboard ─────────────────────────
  Future<int> _sum(String type, DateRange r) async {
    final row = await db
        .customSelect(
          "SELECT COALESCE(SUM(amount_minor),0) AS s FROM transactions WHERE type = ? AND source != 'debt' AND deleted_at IS NULL AND date BETWEEN ? AND ?",
          variables: [Variable(type), Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .getSingle();
    return row.read<int>('s');
  }

  Future<List<CatSlice>> _byCategory(String type, DateRange r) async {
    final rows = await db
        .customSelect(
          '''
      SELECT COALESCE(p.id, c.id) AS cid, COALESCE(p.name, c.name) AS cname,
             COALESCE(p.color_value, c.color_value) AS color, SUM(t.amount_minor) AS s
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN categories p ON p.id = c.parent_id
      WHERE t.type = ? AND t.source != 'debt' AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ?
      GROUP BY COALESCE(p.id, c.id, '_none') ORDER BY s DESC''',
          variables: [Variable(type), Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions, db.categories},
        )
        .get();
    return [
      for (final x in rows)
        CatSlice(
          x.read<String?>('cid') ?? '_none',
          x.read<String?>('cname') ?? 'Uncategorised',
          x.read<int?>('color') ?? 0xFF64748B,
          x.read<int>('s'),
        ),
    ];
  }

  Future<Map<String, int>> _daily(String type, DateRange r) async {
    final rows = await db
        .customSelect(
          "SELECT date AS d, SUM(amount_minor) AS s FROM transactions WHERE type = ? AND source != 'debt' AND deleted_at IS NULL AND date BETWEEN ? AND ? GROUP BY date ORDER BY date",
          variables: [Variable(type), Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .get();
    return {for (final x in rows) x.read<String>('d'): x.read<int>('s')};
  }

  Future<DashboardData> dashboard(DateRange r) async {
    final prev = r.previous;
    // Debt metrics are "as of" the end of the range, never beyond today.
    final asOf = r.end.isAfter(today) ? today : r.end;
    final rec = await debtSummaries(direction: 'receivable', asOf: asOf);
    final lia = await debtSummaries(direction: 'liability', asOf: asOf);
    int sum(Iterable<DebtSummary> l, int Function(DebtState) f) =>
        l.fold(0, (a, s) => a + f(s.state));

    final accs = {
      for (final a in await accounts(includeArchived: true)) a.id: a.name,
    };
    final perAcc = await db
        .customSelect(
          "SELECT account_id AS a, SUM(amount_minor) AS s FROM transactions WHERE type='debit' AND source != 'debt' AND deleted_at IS NULL AND date BETWEEN ? AND ? GROUP BY account_id ORDER BY s DESC",
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .get();
    final byPm = await db
        .customSelect(
          "SELECT COALESCE(payment_method,'') AS m, SUM(amount_minor) AS s FROM transactions WHERE type='debit' AND source != 'debt' AND deleted_at IS NULL AND date BETWEEN ? AND ? GROUP BY payment_method",
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .get();
    var cash = 0, card = 0;
    for (final x in byPm) {
      if (x.read<String>('m') == 'cash') cash = x.read<int>('s');
      if (x.read<String>('m') == 'card') card = x.read<int>('s');
    }
    return DashboardData(
      range: r,
      spending: await _sum('debit', r),
      income: await _sum('credit', r),
      prevSpending: await _sum('debit', prev),
      prevIncome: await _sum('credit', prev),
      incomingDebts: sum(rec, (s) => s.outstanding),
      liabilities: sum(lia, (s) => s.outstanding),
      incomingPrincipal: sum(rec, (s) => s.principalOutstanding),
      incomingInterest: sum(rec, (s) => s.interestOutstanding),
      liabilityPrincipal: sum(lia, (s) => s.principalOutstanding),
      liabilityInterest: sum(lia, (s) => s.interestOutstanding),
      spendingByCategory: await _byCategory('debit', r),
      incomeByCategory: await _byCategory('credit', r),
      dailySpending: await _daily('debit', r),
      dailyIncome: await _daily('credit', r),
      cashSpending: cash,
      cardSpending: card,
      spendingByAccount: [
        for (final x in perAcc)
          MapEntry(accs[x.read<String>('a')] ?? '?', x.read<int>('s')),
      ],
      receivables: rec.where((s) => !s.settled).toList(),
      liabilityList: lia.where((s) => !s.settled).toList(),
      totalBalance: await totalBalance(),
    );
  }

  // ───────────────────────── SMS inbox ─────────────────────────
  /// Parses messages and stores *candidates* only; nothing touches the ledger
  /// until the user confirms. Returns (added, ignored, duplicates).
  Future<({int added, int rejected, int duplicates})> ingestSms(
    Iterable<({String sender, String body, DateTime receivedAt})> messages,
    SmsParser parser,
  ) async {
    var added = 0, rejected = 0, dup = 0;
    await db.transaction(() async {
      for (final m in messages) {
        final r = parser.parse(m.sender, m.body, m.receivedAt);
        if (!r.isAccepted) {
          rejected++;
          continue;
        }
        final p = r.parsed!;
        final sameFp = await (db.select(
          db.smsInbox,
        )..where((s) => s.fingerprint.equals(p.fingerprint))).getSingleOrNull();
        // Semantic duplicate: same amount/direction/account and reference (or day),
        // e.g. the same payment reported by both the bank and the card issuer.
        final sameSem = await (db.select(
          db.smsInbox,
        )..where((s) => s.semanticKey.equals(p.semanticKey))).getSingleOrNull();
        final sameSource =
            await (db.select(db.transactions)..where(
                  (t) =>
                      t.sourceRef.equals(p.fingerprint) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (sameFp != null || sameSem != null || sameSource != null) {
          dup++;
          continue;
        }
        await db
            .into(db.smsInbox)
            .insert(
              SmsInboxCompanion.insert(
                id: newId('sms_'),
                fingerprint: p.fingerprint,
                semanticKey: p.semanticKey,
                sender: m.sender,
                body: m.body,
                direction: p.direction,
                amountMinor: p.amountMinor,
                date: Dates.str(p.date),
                merchant: Value(p.merchant),
                accountRef: Value(p.accountRef),
                reference: Value(p.reference),
              ),
            );
        added++;
      }
    });
    return (added: added, rejected: rejected, duplicates: dup);
  }

  Future<List<SmsInboxData>> pendingSms() =>
      (db.select(db.smsInbox)
            ..where((s) => s.status.equals('pending'))
            ..orderBy([(s) => OrderingTerm.desc(s.date)]))
          .get();

  Future<int> pendingSmsCount() async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS c FROM sms_inbox WHERE status='pending'",
                readsFrom: {db.smsInbox},
              )
              .getSingle())
          .read<int>('c');

  /// Confirm = create the ledger transaction + mark confirmed, atomically.
  /// The transaction id is derived from the fingerprint so two devices
  /// confirming the same message converge on one row.
  Future<String> confirmSms(
    String smsId, {
    String? categoryId,
    String? accountId,
    int? amountMinor,
    String? note,
    String? merchant,
    String? paymentMethod,
    DateTime? date,
    String? type,
  }) async {
    return db.transaction(() async {
      final s = await (db.select(
        db.smsInbox,
      )..where((x) => x.id.equals(smsId))).getSingle();
      if (s.status != 'pending') {
        throw ValidationException('Already ${s.status}');
      }
      final id = await addTransaction(
        type: type ?? s.direction,
        amountMinor: amountMinor ?? s.amountMinor,
        accountId: accountId,
        categoryId: categoryId,
        paymentMethod: paymentMethod,
        date: date ?? Dates.parse(s.date),
        merchant: (merchant ?? s.merchant)?.trim().isEmpty ?? true
            ? null
            : (merchant ?? s.merchant),
        note: note ?? '',
        source: 'sms',
        sourceRef: s.fingerprint,
        id: 'sms:${s.fingerprint}',
      );
      await (db.update(db.smsInbox)..where((x) => x.id.equals(smsId))).write(
        const SmsInboxCompanion(status: Value('confirmed'), body: Value('')),
      );
      return id;
    });
  }

  Future<void> discardSms(String smsId) =>
      (db.update(db.smsInbox)..where((x) => x.id.equals(smsId))).write(
        const SmsInboxCompanion(status: Value('discarded'), body: Value('')),
      );

  Future<void> purgeSmsText() =>
      db.update(db.smsInbox).write(const SmsInboxCompanion(body: Value('')));

  // ───────────────────────── integrity ─────────────────────────
  /// Verifies invariants; returns a list of human-readable problems (empty = healthy).
  Future<List<String>> checkInvariants() async {
    final problems = <String>[];
    final dupRefs = await db
        .customSelect(
          'SELECT source_ref, COUNT(*) c FROM transactions WHERE source_ref IS NOT NULL AND deleted_at IS NULL GROUP BY source_ref HAVING c > 1',
          readsFrom: {db.transactions},
        )
        .get();
    for (final r in dupRefs) {
      problems.add(
        'Duplicate ledger posting for ${r.read<String>('source_ref')}',
      );
    }
    final orphans = await db
        .customSelect(
          'SELECT COUNT(*) c FROM transactions t WHERE t.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = t.account_id)',
          readsFrom: {db.transactions, db.accounts},
        )
        .getSingle();
    if (orphans.read<int>('c') > 0) {
      problems.add('Transactions reference a missing account');
    }
    // Every live debt event leg must exist exactly once.
    for (final d in await debts()) {
      final st = await debtState(d.id);
      if (st.principalOutstanding < 0 || st.interestOutstanding < 0) {
        problems.add('Negative debt balance for ${d.id}');
      }
    }
    return problems;
  }
}

class _Leg {
  final String type;
  final int amount;
  final String date;
  final String source;
  final String? categoryId;
  _Leg(this.type, this.amount, this.date, this.source, this.categoryId);
}

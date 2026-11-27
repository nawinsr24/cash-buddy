import 'package:drift/drift.dart';

import '../domain/card.dart';
import '../domain/dates.dart';
import 'budget_repo.dart';
import 'db.dart';
import 'repo.dart';

/// Credit cards. A card is an account of kind 'card': a spend is a debit on
/// it, so its balance is minus what you owe, and paying the bill is a transfer
/// from a bank or cash account into the card. Your own total balance leaves
/// cards out (see [Repo.totalBalance]), so a swipe does not change it; the
/// payment does.
extension CardRepo on Repo {
  Future<List<Account>> cards({bool includeArchived = false}) =>
      (db.select(db.accounts)
            ..where(
              (a) =>
                  a.deletedAt.isNull() &
                  a.kind.equals('card') &
                  (includeArchived
                      ? const Constant(true)
                      : a.archived.equals(false)),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .get();

  Future<String> addCard({
    required String name,
    String? bank,
    String? last4,
    int? limitMinor,
    int? dueDay,
    int interestBps = 0,
    String ratePeriod = 'month',
    int graceDays = 0,
    int owedMinor = 0,
  }) async {
    if (name.trim().isEmpty) throw ValidationException('Card name required');
    if (dueDay != null && (dueDay < 1 || dueDay > 31)) {
      throw ValidationException('Due day must be between 1 and 31');
    }
    if (owedMinor < 0) {
      throw ValidationException('Amount owed cannot be negative');
    }
    final id = Repo.newId('card_');
    final n = (await cards(includeArchived: true)).length;
    await db
        .into(db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion.insert(
            id: id,
            name: name.trim(),
            kind: 'card',
            colorValue: 0xFF6366F1,
            hlc: clock.next(),
            openingMinor: Value(-owedMinor),
            last4: Value(last4),
            sortOrder: Value(100 + n),
            bank: Value(bank),
            limitMinor: Value(limitMinor),
            dueDay: Value(dueDay),
            interestBps: Value(interestBps),
            ratePeriod: Value(ratePeriod),
            graceDays: Value(graceDays),
          ),
        );
    return id;
  }

  Future<void> updateCard(
    String id, {
    String? name,
    String? bank,
    String? last4,
    int? limitMinor,
    bool clearLimit = false,
    int? dueDay,
    int? interestBps,
    String? ratePeriod,
    int? graceDays,
    bool? archived,
  }) async {
    final a = await (db.select(
      db.accounts,
    )..where((t) => t.id.equals(id))).getSingle();
    await db
        .into(db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion(
            id: Value(id),
            name: Value(name ?? a.name),
            kind: Value(a.kind),
            colorValue: Value(a.colorValue),
            openingMinor: Value(a.openingMinor),
            last4: Value(last4 ?? a.last4),
            archived: Value(archived ?? a.archived),
            bank: Value(bank ?? a.bank),
            limitMinor: Value(clearLimit ? null : (limitMinor ?? a.limitMinor)),
            dueDay: Value(dueDay ?? a.dueDay),
            interestBps: Value(interestBps ?? a.interestBps),
            ratePeriod: Value(ratePeriod ?? a.ratePeriod),
            graceDays: Value(graceDays ?? a.graceDays),
            hlc: Value(clock.next()),
          ),
        );
  }

  /// The card's balance on [date]: opening, spends, refunds and payments up
  /// to and including that day. Minus this is what was owed.
  Future<int> cardBalanceAsOf(String cardId, DateTime date) async {
    final d = Dates.str(date);
    final r = await db
        .customSelect(
          '''
      SELECT a.opening_minor
        + COALESCE((SELECT SUM(CASE t.type WHEN 'credit' THEN t.amount_minor ELSE -t.amount_minor END)
                    FROM transactions t WHERE t.account_id = a.id AND t.deleted_at IS NULL AND t.date <= ?1), 0)
        + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
                    WHERE t.to_account_id = a.id AND t.type = 'transfer' AND t.deleted_at IS NULL AND t.date <= ?1), 0) AS bal
      FROM accounts a WHERE a.id = ?2''',
          variables: [Variable(d), Variable(cardId)],
          readsFrom: {db.accounts, db.transactions},
        )
        .getSingle();
    return r.read<int>('bal');
  }

  /// Payments into the card after [date].
  Future<int> cardPaymentsAfter(String cardId, DateTime date) async {
    final r = await db
        .customSelect(
          "SELECT COALESCE(SUM(amount_minor),0) AS s FROM transactions WHERE to_account_id = ? AND type='transfer' AND deleted_at IS NULL AND date > ?",
          variables: [Variable(cardId), Variable(Dates.str(date))],
          readsFrom: {db.transactions},
        )
        .getSingle();
    return r.read<int>('s');
  }

  Future<CardStatus> cardStatus(Account a) async {
    final now = today;
    final bal = await cardBalanceAsOf(a.id, now);
    final owed = bal < 0 ? -bal : 0;
    var interest = 0;
    var overdue = false;
    DateTime? next;
    final day = a.dueDay;
    if (day != null) {
      next = nextDueDate(day, now);
      final latest = latestDueDate(day, now);
      // What was due on the last due date, less what was paid since.
      final atDue = await cardBalanceAsOf(a.id, latest);
      final billAtDue = atDue < 0 ? -atDue : 0;
      final paidSince = await cardPaymentsAfter(a.id, latest);
      final unpaid = (billAtDue - paidSince).clamp(0, owed);
      interest = cardInterest(
        unpaidBill: unpaid,
        rateBps: a.interestBps,
        period: a.ratePeriod,
        graceDays: a.graceDays,
        dueDate: latest,
        today: now,
      );
      overdue = unpaid > 0 && now.isAfter(latest);
    }
    return CardStatus(
      id: a.id,
      name: a.name,
      bank: a.bank,
      last4: a.last4,
      owed: owed,
      interest: interest,
      limit: a.limitMinor,
      nextDue: next,
      overdue: overdue,
    );
  }

  Future<List<CardStatus>> cardStatuses() async => [
    for (final a in await cards()) await cardStatus(a),
  ];

  /// Pays [amountMinor] towards a card from [fromAccountId]. Up to what is
  /// owed it goes to the card (a transfer); anything above that is interest or
  /// fees, recorded as spending on the paying account.
  Future<void> payCardBill({
    required String cardId,
    required int amountMinor,
    required String fromAccountId,
    DateTime? date,
  }) async {
    if (amountMinor <= 0) {
      throw ValidationException('Amount must be more than zero');
    }
    final d = date ?? today;
    await db.transaction(() async {
      final bal = await cardBalanceAsOf(cardId, today);
      final owed = bal < 0 ? -bal : 0;
      final toCard = amountMinor < owed ? amountMinor : owed;
      final extra = amountMinor - toCard;
      if (toCard > 0) {
        await addTransaction(
          type: 'transfer',
          amountMinor: toCard,
          accountId: fromAccountId,
          toAccountId: cardId,
          date: d,
          note: 'Credit card bill',
        );
      }
      if (extra > 0) {
        await addTransaction(
          type: 'debit',
          amountMinor: extra,
          accountId: fromAccountId,
          categoryId: 'cat_interest_paid',
          date: d,
          note: 'Card interest and fees',
        );
      }
    });
  }

  /// Spends, refunds and payments of one card, newest first.
  Future<List<Transaction>> cardActivity(String cardId, {int limit = 50}) =>
      (db.select(db.transactions)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (t.accountId.equals(cardId) | t.toAccountId.equals(cardId)),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.date),
              (t) => OrderingTerm.desc(t.hlc),
            ])
            ..limit(limit))
          .get();

  // ── budget choice ──
  /// 'pay' (default): card spends wait until the bill is paid, then the
  /// payment counts against the budget. 'swipe': card spends count at once.
  Future<String> cardBudgetMode() async =>
      (await getSetting('cardBudgetMode')) == 'swipe' ? 'swipe' : 'pay';

  Future<void> setCardBudgetMode(String mode) =>
      setSetting('cardBudgetMode', mode == 'swipe' ? 'swipe' : 'pay');

  /// For the "after paying your card bills" line on Home. Only when card
  /// spends are kept apart from the budget, there is a budget, and some
  /// bill is due this month or already overdue.
  Future<({int due, int left, int after})?> cardWarning() async {
    if (await cardBudgetMode() != 'pay') return null;
    final now = today;
    final st = await budgetStatus(now.year, now.month);
    if (st == null) return null;
    final monthEnd = Dates.day(
      now.year,
      now.month,
      Dates.daysInMonth(now.year, now.month),
    );
    var due = 0;
    for (final c in await cardStatuses()) {
      final soon =
          c.overdue || (c.nextDue != null && !c.nextDue!.isAfter(monthEnd));
      if (soon && c.toPay > 0) due += c.toPay;
    }
    if (due <= 0) return null;
    final left = st.budget - st.spent;
    return (due: due, left: left, after: left - due);
  }
}

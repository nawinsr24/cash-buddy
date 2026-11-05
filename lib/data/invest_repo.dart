import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/invest.dart';
import '../domain/schedule.dart';
import 'db.dart';
import 'repo.dart';

class InvestSummary {
  final Investment inv;
  final List<InvestmentEntry> entries;
  final int contributed, withdrawn, dividends;

  /// What the investment is worth now: the value the user entered, or (if none)
  /// simply what was put in minus what came back.
  final int currentValue;
  final bool valueIsEstimate; // true when no value was entered
  final int? projected; // from the optional growth rate
  final double? xirrRate;
  const InvestSummary({
    required this.inv,
    required this.entries,
    required this.contributed,
    required this.withdrawn,
    required this.dividends,
    required this.currentValue,
    required this.valueIsEstimate,
    required this.projected,
    required this.xirrRate,
  });

  int get netInvested => contributed - withdrawn - dividends;

  /// Gain = (value now + everything received) - everything put in.
  /// With nothing recorded as put in there is no basis, so no gain is claimed.
  int get gain =>
      contributed == 0 ? 0 : currentValue + withdrawn + dividends - contributed;
  double? get gainPct => contributed == 0 ? null : gain / contributed;
}

class InvestTotals {
  final int contributed, currentValue, gain;
  const InvestTotals(this.contributed, this.currentValue, this.gain);
  double? get pct => contributed == 0 ? null : gain / contributed;
}

extension InvestmentSchedule on Investment {
  /// The repeat rule of a recurring plan, or null for one-off investments.
  Schedule? get schedule {
    if (!recurring || cycle == null || startDate == null) return null;
    return Schedule(
      cycle: cycle!,
      every: everyN,
      start: Dates.parse(startDate!),
      weekday: weekday,
      monthDay: monthDay,
      count: installments,
      until: endDate == null ? null : Dates.parse(endDate!),
      timeOfDay: timeOfDay,
    );
  }
}

extension InvestRepo on Repo {
  String get _iso => now().toUtc().toIso8601String();

  Future<bool> get investReducesBalance async =>
      (await getSetting('investReducesBalance') ?? '1') == '1';
  Future<bool> get lendReducesBalance async =>
      (await getSetting('lendReducesBalance') ?? '1') == '1';

  /// Balance rules live in settings; changing one re-derives the ledger legs.
  Future<void> setBalanceRule(String key, bool on) async {
    assert(key == 'investReducesBalance' || key == 'lendReducesBalance');
    await setSetting(key, on ? '1' : '0');
    await db.transaction(() async {
      await reconcileAllDebts();
      await reconcileAllInvestments();
    });
  }

  // ───────────────────────── investments ─────────────────────────
  Future<String> createInvestment({
    required String kind,
    required String name,
    String? accountId,
    DateTime? startDate,
    int? expectedGrowthBps,
    int? currentValueMinor,
    double? units,
    int? buyPriceMinor,
    int? sipMinor,
    bool recurring = false,
    String? cycle,
    int everyN = 1,
    int? weekday,
    int? monthDay,
    String? timeOfDay,
    int? installments,
    DateTime? endDate,
    String note = '',
  }) async {
    if (!{'mutual_fund', 'stock', 'custom'}.contains(kind)) {
      throw ValidationException('Unknown investment type');
    }
    if (name.trim().isEmpty) throw ValidationException('Give it a name');
    _checkSchedule(
      recurring: recurring,
      cycle: cycle,
      everyN: everyN,
      weekday: weekday,
      monthDay: monthDay,
      timeOfDay: timeOfDay,
      installments: installments,
      endDate: endDate,
      startDate: startDate,
    );
    final id = Repo.newId('inv_');
    await db
        .into(db.investments)
        .insert(
          InvestmentsCompanion.insert(
            id: id,
            kind: kind,
            name: name.trim(),
            hlc: clock.next(),
            accountId: Value(accountId),
            startDate: Value(startDate == null ? null : Dates.str(startDate)),
            expectedGrowthBps: Value(expectedGrowthBps),
            currentValueMinor: Value(currentValueMinor),
            valueUpdatedOn: Value(
              currentValueMinor == null ? null : Dates.str(today),
            ),
            units: Value(units),
            buyPriceMinor: Value(buyPriceMinor),
            sipMinor: Value(sipMinor),
            recurring: Value(recurring),
            cycle: Value(recurring ? cycle : null),
            everyN: Value(recurring ? everyN : 1),
            weekday: Value(recurring ? weekday : null),
            monthDay: Value(recurring ? monthDay : null),
            timeOfDay: Value(recurring ? timeOfDay : null),
            installments: Value(recurring ? installments : null),
            endDate: Value(
              recurring && endDate != null ? Dates.str(endDate) : null,
            ),
            note: Value(note),
          ),
        );
    return id;
  }

  void _checkSchedule({
    required bool recurring,
    String? cycle,
    required int everyN,
    int? weekday,
    int? monthDay,
    String? timeOfDay,
    int? installments,
    DateTime? endDate,
    DateTime? startDate,
  }) {
    if (!recurring) return;
    if (startDate == null) {
      throw ValidationException('A recurring plan needs a start date');
    }
    final bad = Schedule(
      cycle: cycle ?? '',
      every: everyN,
      start: startDate,
      weekday: weekday,
      monthDay: monthDay,
      count: installments,
      until: endDate,
      timeOfDay: timeOfDay,
    ).validate();
    if (bad != null) throw ValidationException(bad);
  }

  Future<Investment> getInvestment(String id) =>
      (db.select(db.investments)..where((i) => i.id.equals(id))).getSingle();

  /// Replaces every editable field (null clears an optional one).
  Future<void> updateInvestment(
    String id, {
    required String name,
    String? accountId,
    DateTime? startDate,
    int? expectedGrowthBps,
    int? currentValueMinor,
    double? units,
    int? buyPriceMinor,
    int? sipMinor,
    bool recurring = false,
    String? cycle,
    int everyN = 1,
    int? weekday,
    int? monthDay,
    String? timeOfDay,
    int? installments,
    DateTime? endDate,
    String note = '',
  }) async {
    if (name.trim().isEmpty) throw ValidationException('Give it a name');
    _checkSchedule(
      recurring: recurring,
      cycle: cycle,
      everyN: everyN,
      weekday: weekday,
      monthDay: monthDay,
      timeOfDay: timeOfDay,
      installments: installments,
      endDate: endDate,
      startDate: startDate,
    );
    final cur = await getInvestment(id);
    final valueChanged = currentValueMinor != cur.currentValueMinor;
    await db
        .update(db.investments)
        .replace(
          cur.copyWith(
            name: name.trim(),
            accountId: Value(accountId),
            startDate: Value(startDate == null ? null : Dates.str(startDate)),
            expectedGrowthBps: Value(expectedGrowthBps),
            currentValueMinor: Value(currentValueMinor),
            valueUpdatedOn: Value(
              currentValueMinor == null
                  ? null
                  : (valueChanged ? Dates.str(today) : cur.valueUpdatedOn),
            ),
            units: Value(units),
            buyPriceMinor: Value(buyPriceMinor),
            sipMinor: Value(sipMinor),
            recurring: recurring,
            cycle: Value(recurring ? cycle : null),
            everyN: recurring ? everyN : 1,
            weekday: Value(recurring ? weekday : null),
            monthDay: Value(recurring ? monthDay : null),
            timeOfDay: Value(recurring ? timeOfDay : null),
            installments: Value(recurring ? installments : null),
            endDate: Value(
              recurring && endDate != null ? Dates.str(endDate) : null,
            ),
            note: note,
            hlc: clock.next(),
          ),
        );
  }

  Future<void> setCurrentValue(String id, int? valueMinor) async {
    final cur = await getInvestment(id);
    await db
        .update(db.investments)
        .replace(
          cur.copyWith(
            currentValueMinor: Value(valueMinor),
            valueUpdatedOn: Value(valueMinor == null ? null : Dates.str(today)),
            hlc: clock.next(),
          ),
        );
  }

  /// Deletes the investment, its entries and every ledger leg they posted.
  Future<void> deleteInvestment(String id) async {
    await db.transaction(() async {
      final inv = await getInvestment(id);
      final ts = _iso;
      for (final e in await _entries(id, includeDeleted: true)) {
        if (e.deletedAt == null) {
          await db
              .update(db.investmentEntries)
              .replace(e.copyWith(deletedAt: Value(ts), hlc: clock.next()));
        }
      }
      await db
          .update(db.investments)
          .replace(inv.copyWith(deletedAt: Value(ts), hlc: clock.next()));
      await reconcileInvestment(id);
    });
  }

  // ───────────────────────── entries ─────────────────────────
  Future<List<InvestmentEntry>> _entries(
    String id, {
    bool includeDeleted = false,
  }) =>
      (db.select(db.investmentEntries)
            ..where(
              (e) =>
                  e.investmentId.equals(id) &
                  (includeDeleted
                      ? const Constant(true)
                      : e.deletedAt.isNull()),
            )
            ..orderBy([
              (e) => OrderingTerm.asc(e.date),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  Future<List<InvestmentEntry>> investmentEntries(String id) => _entries(id);

  /// [type]: contribute | withdraw | dividend | payout.
  /// [periodKey]: index of the scheduled instalment (0-based) this pays.
  Future<String> addInvestmentEntry(
    String investmentId, {
    required String type,
    required int amountMinor,
    DateTime? date,
    int? periodKey,
    bool postToBalance = true,
    String note = '',
  }) async {
    if (!{'contribute', 'withdraw', 'dividend', 'payout'}.contains(type)) {
      throw ValidationException('Unknown entry type');
    }
    if (amountMinor <= 0) throw ValidationException('Amount must be positive');
    return db.transaction(() async {
      final inv = await getInvestment(investmentId);
      if (inv.deletedAt != null) {
        throw ValidationException('Investment was deleted');
      }
      if (periodKey != null && (type == 'contribute' || type == 'dividend')) {
        final dup =
            await (db.select(db.investmentEntries)..where(
                  (e) =>
                      e.investmentId.equals(investmentId) &
                      e.type.equals(type) &
                      e.periodKey.equals(periodKey) &
                      e.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (dup != null) {
          throw ValidationException('That month already has an entry');
        }
      }
      final id = Repo.newId('ie_');
      await db
          .into(db.investmentEntries)
          .insert(
            InvestmentEntriesCompanion.insert(
              id: id,
              investmentId: investmentId,
              type: type,
              amountMinor: amountMinor,
              date: Dates.str(date ?? today),
              hlc: clock.next(),
              periodKey: Value(periodKey),
              postToBalance: Value(postToBalance),
              note: Value(note),
            ),
          );
      await reconcileInvestment(investmentId);
      return id;
    });
  }

  Future<void> deleteInvestmentEntry(String entryId) async {
    await db.transaction(() async {
      final e = await (db.select(
        db.investmentEntries,
      )..where((x) => x.id.equals(entryId))).getSingle();
      await db
          .update(db.investmentEntries)
          .replace(e.copyWith(deletedAt: Value(_iso), hlc: clock.next()));
      await reconcileInvestment(e.investmentId);
    });
  }

  // ───────────────────────── ledger legs ─────────────────────────
  /// Idempotent: one ledger row per entry, only while both the global rule
  /// and the entry's own flag say it should move the balance.
  Future<void> reconcileInvestment(String investmentId) async {
    final inv = await getInvestment(investmentId);
    final globalOn = await investReducesBalance;
    final entries = await _entries(investmentId, includeDeleted: true);
    final account = inv.accountId ?? await defaultAccountId();
    for (final e in entries) {
      final ref = 'inv:${e.id}';
      final wanted =
          globalOn &&
          e.deletedAt == null &&
          inv.deletedAt == null &&
          e.postToBalance;
      final type = e.type == 'contribute' ? 'debit' : 'credit';
      final cur =
          await (db.select(db.transactions)..where(
                (t) => t.sourceRef.equals(ref) & t.source.equals('invest'),
              ))
              .getSingleOrNull();
      if (wanted) {
        final same =
            cur != null &&
            cur.deletedAt == null &&
            cur.type == type &&
            cur.amountMinor == e.amountMinor &&
            cur.date == e.date &&
            cur.accountId == account &&
            cur.merchant == inv.name;
        if (same) continue;
        await db
            .into(db.transactions)
            .insertOnConflictUpdate(
              TransactionsCompanion.insert(
                id: 'led:$ref',
                type: type,
                amountMinor: e.amountMinor,
                accountId: account,
                date: e.date,
                hlc: clock.next(),
                merchant: Value(inv.name),
                note: Value(switch (e.type) {
                  'contribute' => 'Invested in ${inv.name}',
                  'withdraw' => 'Withdrawn from ${inv.name}',
                  'dividend' => 'Dividend from ${inv.name}',
                  _ => 'Chit payout: ${inv.name}',
                }),
                source: const Value('invest'),
                sourceRef: Value(ref),
                deletedAt: const Value(null),
              ),
            );
      } else if (cur != null && cur.deletedAt == null) {
        await db
            .into(db.transactions)
            .insertOnConflictUpdate(
              cur
                  .toCompanion(true)
                  .copyWith(deletedAt: Value(_iso), hlc: Value(clock.next())),
            );
      }
    }
  }

  Future<void> reconcileAllInvestments() async {
    for (final i in await db.select(db.investments).get()) {
      await reconcileInvestment(i.id);
    }
  }

  // ───────────────────────── summaries ─────────────────────────
  Future<List<Investment>> investments() =>
      (db.select(db.investments)
            ..where((i) => i.deletedAt.isNull())
            ..orderBy([(i) => OrderingTerm.desc(i.hlc)]))
          .get();

  Future<InvestSummary> investSummary(Investment inv) async {
    final entries = await _entries(inv.id);
    int sum(String t) =>
        entries.where((e) => e.type == t).fold(0, (a, e) => a + e.amountMinor);
    final contributed = sum('contribute');
    final withdrawn = sum('withdraw') + sum('payout');
    final dividends = sum('dividend');
    final entered = inv.currentValueMinor;
    final asOf = today;
    final rate = inv.expectedGrowthBps == null
        ? null
        : inv.expectedGrowthBps! / 10000.0;
    final projected = rate == null || contributed == 0
        ? null
        : projectedValue(
            [
              for (final e in entries)
                if (e.type == 'contribute')
                  (date: Dates.parse(e.date), amountMinor: e.amountMinor),
            ],
            rate,
            asOf,
          );
    // With no value entered, show what is still invested (not a made-up gain).
    final value =
        entered ?? (contributed - withdrawn - dividends).clamp(0, 1 << 62);
    final flows = <Flow>[
      for (final e in entries)
        Flow(
          Dates.parse(e.date),
          (e.type == 'contribute' ? -1 : 1) * e.amountMinor / 100.0,
        ),
      if (entered != null && entered > 0) Flow(asOf, entered / 100.0),
    ];
    return InvestSummary(
      inv: inv,
      entries: entries,
      contributed: contributed,
      withdrawn: withdrawn,
      dividends: dividends,
      currentValue: value,
      valueIsEstimate: entered == null,
      projected: projected,
      xirrRate: entered == null ? null : xirr(flows),
    );
  }

  Future<List<InvestSummary>> investSummaries() async => [
    for (final i in await investments()) await investSummary(i),
  ];

  InvestTotals investTotals(List<InvestSummary> list) {
    final c = list.fold<int>(0, (a, s) => a + s.contributed);
    final v = list.fold<int>(0, (a, s) => a + s.currentValue);
    final g = list.fold<int>(0, (a, s) => a + s.gain);
    return InvestTotals(c, v, g);
  }
}

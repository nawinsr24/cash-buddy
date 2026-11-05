import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/grade.dart';
import 'db.dart';
import 'budget_repo.dart';
import 'invest_repo.dart';
import 'repo.dart';

class MonthTitle {
  final String month; // YYYY-MM
  final TitleId id;
  const MonthTitle(this.month, this.id);
  int get year => int.parse(month.substring(0, 4));
  int get monthNo => int.parse(month.substring(5, 7));
}

class RecurringBill {
  final String merchant;
  final int amountMinor;
  final DateTime next;
  const RecurringBill(this.merchant, this.amountMinor, this.next);
}

class InsightsData {
  final int spentSoFar, projected, dailyAvg, lastMonthSpending;
  final String? topCategory;
  final int topCategoryMinor;
  final int netWorth;
  final List<RecurringBill> bills;
  final int daysLeft;
  const InsightsData({
    required this.spentSoFar,
    required this.projected,
    required this.dailyAvg,
    required this.lastMonthSpending,
    required this.topCategory,
    required this.topCategoryMinor,
    required this.netWorth,
    required this.bills,
    required this.daysLeft,
  });

  /// Projected spend against last month's total, in percent (null: no basis).
  int? get vsLastMonthPct => lastMonthSpending <= 0
      ? null
      : ((projected - lastMonthSpending) * 100 / lastMonthSpending).round();
}

const _healthWords = [
  'health',
  'medic',
  'pharm',
  'doctor',
  'hospital',
  'clinic',
  'dental',
  'dentist',
  'diagnos',
];

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

extension InsightsRepo on Repo {
  Future<bool> get roastMode async =>
      (await getSetting('roastMode') ?? '1') == '1';

  DateRange _monthRange(int y, int m) =>
      DateRange(Dates.day(y, m, 1), Dates.day(y, m, Dates.daysInMonth(y, m)));

  Future<int> _sumType(String type, DateRange r) async {
    final row = await db
        .customSelect(
          "SELECT COALESCE(SUM(amount_minor),0) AS s FROM transactions WHERE type = ? AND source NOT IN ('debt','invest') AND deleted_at IS NULL AND date BETWEEN ? AND ?",
          variables: [Variable(type), Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .getSingle();
    return row.read<int>('s');
  }

  /// Everything the grade and the title need for calendar month [y]-[m].
  Future<MonthStats> monthStats(int y, int m) async {
    final r = _monthRange(y, m);
    final today = this.today;
    final asOf = r.end.isAfter(today) ? today : r.end;
    final elapsed = today.isBefore(r.start)
        ? 0
        : (asOf.difference(r.start).inDays + 1);
    final income = await _sumType('credit', r);
    final spending = await _sumType('debit', r);

    final inv = await db
        .customSelect(
          '''SELECT COALESCE(SUM(e.amount_minor),0) AS s FROM investment_entries e
             JOIN investments i ON i.id = e.investment_id
             WHERE e.type='contribute' AND e.deleted_at IS NULL AND i.deleted_at IS NULL
               AND e.date BETWEEN ? AND ?''',
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.investmentEntries, db.investments},
        )
        .getSingle();

    final act = await db
        .customSelect(
          "SELECT COUNT(*) AS n, COUNT(DISTINCT date) AS d FROM transactions WHERE deleted_at IS NULL AND source IN ('manual','sms') AND date BETWEEN ? AND ?",
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .getSingle();

    final cats = await db
        .customSelect(
          '''SELECT COALESCE(p.name, c.name) AS cname, SUM(t.amount_minor) AS s
             FROM transactions t
             LEFT JOIN categories c ON c.id = t.category_id
             LEFT JOIN categories p ON p.id = c.parent_id
             WHERE t.type='debit' AND t.source NOT IN ('debt','invest')
               AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ?
               AND c.id IS NOT NULL
             GROUP BY COALESCE(p.id, c.id) ORDER BY s DESC LIMIT 1''',
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions, db.categories},
        )
        .get();
    final top = cats.isEmpty ? null : cats.first.read<String>('cname');
    final topSum = cats.isEmpty ? 0 : cats.first.read<int>('s');

    // health care: the Health category, or words in the merchant / note
    final health = await db
        .customSelect(
          '''SELECT COALESCE(SUM(t.amount_minor),0) AS s, COUNT(*) AS n
             FROM transactions t
             LEFT JOIN categories c ON c.id = t.category_id
             LEFT JOIN categories p ON p.id = c.parent_id
             WHERE t.type='debit' AND t.source NOT IN ('debt','invest')
               AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ?
               AND ('''
          "${_healthWords.map((w) => "LOWER(COALESCE(p.name,'')||' '||COALESCE(c.name,'')||' '||COALESCE(t.merchant,'')||' '||COALESCE(t.note,'')) LIKE '%$w%'").join(' OR ')}"
          ')',
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions, db.categories},
        )
        .getSingle();

    // overdue: unpaid recurring instalments + liabilities past their due date
    var overdue = 0;
    for (final i in await investments()) {
      final sch = i.schedule;
      if (sch == null) continue;
      final paid = {
        for (final e in await investmentEntries(i.id))
          if (e.type == 'contribute' && e.periodKey != null) e.periodKey!,
      };
      final due = sch.dueCount(asOf);
      var late = 0;
      for (var k = 0; k < due; k++) {
        if (!paid.contains(k)) late++;
      }
      overdue += late > 3 ? 3 : late;
    }
    final liab = await debtSummaries(direction: 'liability', asOf: asOf);
    var liabilities = 0;
    for (final s in liab) {
      liabilities += s.state.outstanding;
      final due = s.debt.dueOn;
      if (due != null &&
          Dates.parse(due).isBefore(asOf) &&
          s.state.outstanding > 0) {
        overdue++;
      }
    }
    final paidRow = await db
        .customSelect(
          '''SELECT COALESCE(SUM(ev.amount_minor),0) AS s FROM debt_events ev
             JOIN debts d ON d.id = ev.debt_id
             WHERE d.direction='liability' AND ev.type='repayment'
               AND ev.deleted_at IS NULL AND d.deleted_at IS NULL
               AND ev.date BETWEEN ? AND ?''',
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.debtEvents, db.debts},
        )
        .getSingle();

    // previous three months
    var prevSum = 0, prevCount = 0;
    var prevOver = false;
    for (var k = 1; k <= 3; k++) {
      final pm = Dates.addMonths(Dates.day(y, m, 1), -k);
      final pr = _monthRange(pm.year, pm.month);
      final s = await _sumType('debit', pr);
      if (s > 0) {
        prevSum += s;
        prevCount++;
      }
      if (k == 1) {
        final inc = await _sumType('credit', pr);
        prevOver = inc > 0 && s > inc;
      }
    }

    return MonthStats(
      income: income,
      spending: spending,
      invested: inv.read<int>('s'),
      prevAvgSpending: prevCount == 0 ? 0 : (prevSum / prevCount).round(),
      prevMonthOverspent: prevOver,
      txnCount: act.read<int>('n'),
      activeDays: act.read<int>('d'),
      topCategory: top,
      topShareBps: spending <= 0 ? 0 : (topSum * 10000 / spending).round(),
      overdueCount: overdue,
      liabilities: liabilities,
      paidToLiabilities: paidRow.read<int>('s'),
      daysInMonth: r.days,
      daysElapsed: elapsed.clamp(0, r.days),
      healthSpending: health.read<int>('s'),
      healthCount: health.read<int>('n'),
      budgetMinor: await budgetFor(y, m),
    );
  }

  // ───────────────────────── monthly titles ─────────────────────────
  /// Stores the title for each finished month (last 12) that has entries and
  /// no title yet. Stored once, so a month's title never changes afterwards.
  Future<void> ensureMonthTitles() async {
    final now = today;
    for (var k = 1; k <= 12; k++) {
      final d = Dates.addMonths(Dates.day(now.year, now.month, 1), -k);
      final key = monthKey(d.year, d.month);
      if (await getSetting('title_$key') != null) continue;
      // cheap check first: months with no entries need no full calculation
      final r = _monthRange(d.year, d.month);
      final any = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM transactions WHERE deleted_at IS NULL AND date BETWEEN ? AND ?',
            variables: [Variable(r.startStr), Variable(r.endStr)],
            readsFrom: {db.transactions},
          )
          .getSingle();
      if (any.read<int>('n') == 0) continue;
      final s = await monthStats(d.year, d.month);
      if (s.txnCount == 0 && s.spending == 0 && s.income == 0) continue;
      await setSetting('title_$key', pickTitle(s).name);
    }
  }

  Future<List<MonthTitle>> titleHistory() async {
    final rows = await (db.select(
      db.settings,
    )..where((s) => s.key.like('title_%'))).get();
    final out = <MonthTitle>[];
    for (final r in rows) {
      final id = TitleId.values.where((t) => t.name == r.value).firstOrNull;
      if (id != null) out.add(MonthTitle(r.key.substring(6), id));
    }
    out.sort((a, b) => b.month.compareTo(a.month));
    return out;
  }

  /// Last month's title while it is fresh (first 7 days) and not dismissed.
  Future<MonthTitle?> bannerTitle() async {
    final now = today;
    if (now.day > 7) return null;
    final prev = Dates.addMonths(Dates.day(now.year, now.month, 1), -1);
    final key = monthKey(prev.year, prev.month);
    if (await getSetting('titleBannerDismissed') == key) return null;
    await ensureMonthTitles();
    final v = await getSetting('title_$key');
    final id = TitleId.values.where((t) => t.name == v).firstOrNull;
    return id == null ? null : MonthTitle(key, id);
  }

  Future<void> dismissTitleBanner(String month) =>
      setSetting('titleBannerDismissed', month);

  // ───────────────────────── dashboard insights ─────────────────────────
  Future<InsightsData> insights() async {
    final now = today;
    final s = await monthStats(now.year, now.month);
    final prev = Dates.addMonths(Dates.day(now.year, now.month, 1), -1);
    final last = await _sumType('debit', _monthRange(prev.year, prev.month));
    final elapsed = s.daysElapsed < 1 ? 1 : s.daysElapsed;

    final inv = await investSummaries();
    final rec = await debtSummaries(direction: 'receivable');
    final lia = await debtSummaries(direction: 'liability');
    final worth =
        await totalBalance() +
        inv.fold<int>(0, (a, i) => a + i.currentValue) +
        rec.fold<int>(0, (a, d) => a + d.state.outstanding) -
        lia.fold<int>(0, (a, d) => a + d.state.outstanding);

    return InsightsData(
      spentSoFar: s.spending,
      projected: s.projectedSpending,
      dailyAvg: (s.spending / elapsed).round(),
      lastMonthSpending: last,
      topCategory: s.topCategory,
      topCategoryMinor: s.topCategory == null
          ? 0
          : (s.spending * s.topShareBps / 10000).round(),
      netWorth: worth,
      bills: await _recurringBills(now),
      daysLeft: s.daysInMonth - s.daysElapsed,
    );
  }

  /// Merchants charged a similar amount in at least two of the last three
  /// months, with the next expected date.
  Future<List<RecurringBill>> _recurringBills(DateTime today) async {
    final from = Dates.addMonths(Dates.day(today.year, today.month, 1), -3);
    final rows =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.type.equals('debit') &
                  t.deletedAt.isNull() &
                  t.merchant.isNotNull() &
                  t.source.isIn(['manual', 'sms']) &
                  t.date.isBiggerOrEqualValue(Dates.str(from)),
            ))
            .get();
    final byMerchant = <String, List<Transaction>>{};
    for (final t in rows) {
      final m = (t.merchant ?? '').trim().toLowerCase();
      if (m.isEmpty) continue;
      byMerchant.putIfAbsent(m, () => []).add(t);
    }
    final out = <RecurringBill>[];
    for (final e in byMerchant.entries) {
      final list = e.value;
      final months = {for (final t in list) t.date.substring(0, 7)};
      if (months.length < 2) continue;
      final amounts = list.map((t) => t.amountMinor).toList()..sort();
      final mid = amounts[amounts.length ~/ 2];
      final similar = list
          .where((t) => (t.amountMinor - mid).abs() <= mid * 0.05)
          .toList();
      if ({for (final t in similar) t.date.substring(0, 7)}.length < 2) {
        continue;
      }
      final days = similar.map((t) => Dates.parse(t.date).day).toList()..sort();
      final day = days[days.length ~/ 2];
      var next = Dates.day(
        today.year,
        today.month,
        day > Dates.daysInMonth(today.year, today.month)
            ? Dates.daysInMonth(today.year, today.month)
            : day,
      );
      if (next.isBefore(today)) {
        final n = Dates.addMonths(Dates.day(today.year, today.month, 1), 1);
        next = Dates.day(
          n.year,
          n.month,
          day > Dates.daysInMonth(n.year, n.month)
              ? Dates.daysInMonth(n.year, n.month)
              : day,
        );
      }
      final name = similar.first.merchant!.trim();
      out.add(RecurringBill(name, mid, next));
    }
    out.sort((a, b) => a.next.compareTo(b.next));
    return out.take(4).toList();
  }

  // ───────────────────────── live title ─────────────────────────
  /// The title you hold today (provisional until the month ends). Decided
  /// once per day, so it moves daily rather than flickering with every entry.
  /// [previous] is the title you held before it last changed.
  Future<({TitleId id, TitleId? previous, bool settled})> liveTitle() async {
    final now = today;
    final todayKey = Dates.str(now);
    TitleId? parse(String? v) =>
        TitleId.values.where((t) => t.name == v).firstOrNull;
    final raw = (await getSetting('liveTitle'))?.split('|');
    if (raw != null && raw.length == 3 && raw[0] == todayKey) {
      final id = parse(raw[1]);
      if (id != null) {
        return (id: id, previous: parse(raw[2]), settled: false);
      }
    }
    final s = await monthStats(now.year, now.month);
    final fresh = liveTitleFor(s);
    final old = raw != null && raw.length == 3 ? parse(raw[1]) : null;
    final oldPrev = raw != null && raw.length == 3 ? parse(raw[2]) : null;
    // remember what it was before it changed
    final previous = old == null ? null : (old != fresh ? old : oldPrev);
    await setSetting(
      'liveTitle',
      '$todayKey|${fresh.name}|${previous?.name ?? ''}',
    );
    return (id: fresh, previous: previous, settled: false);
  }

  // ───────────────────────── month-end celebration ─────────────────────────
  /// Last month's title, once, the first time the app opens in a new month.
  Future<MonthTitle?> celebrationDue() async {
    final now = today;
    final prev = Dates.addMonths(Dates.day(now.year, now.month, 1), -1);
    final key = monthKey(prev.year, prev.month);
    if (await getSetting('titleCelebrated') == key) return null;
    await ensureMonthTitles();
    final v = await getSetting('title_$key');
    final id = TitleId.values.where((t) => t.name == v).firstOrNull;
    return id == null ? null : MonthTitle(key, id);
  }

  Future<void> markCelebrated(String month) async {
    await setSetting('titleCelebrated', month);
    await setSetting('titleBannerDismissed', month);
  }

  /// This finished month against the one before it; null for a first month.
  Future<
    ({
      List<CompareRow> rows,
      TitleId? previousTitle,
      int score,
      int previousScore,
    })?
  >
  comparisonFor(MonthTitle t) async {
    final cur = await monthStats(t.year, t.monthNo);
    final pm = Dates.addMonths(Dates.day(t.year, t.monthNo, 1), -1);
    final prev = await monthStats(pm.year, pm.month);
    if (prev.txnCount == 0 && prev.spending == 0 && prev.income == 0) {
      return null;
    }
    final cs = computeGrade(cur).score;
    final ps = computeGrade(prev).score;
    final v = await getSetting('title_${monthKey(pm.year, pm.month)}');
    return (
      rows: compareMonths(cur, prev, curScore: cs, prevScore: ps),
      previousTitle: TitleId.values.where((x) => x.name == v).firstOrNull,
      score: cs,
      previousScore: ps,
    );
  }

  /// Plus Score of each recent month that has entries, oldest first
  /// (the current month last, as it stands so far).
  Future<List<({String month, int score})>> scoreHistory({
    int months = 12,
  }) async {
    final now = today;
    final out = <({String month, int score})>[];
    for (var k = months - 1; k >= 0; k--) {
      final d = Dates.addMonths(Dates.day(now.year, now.month, 1), -k);
      final s = await monthStats(d.year, d.month);
      if (s.txnCount == 0 && s.spending == 0 && s.income == 0) continue;
      out.add((month: monthKey(d.year, d.month), score: computeGrade(s).score));
    }
    return out;
  }
}

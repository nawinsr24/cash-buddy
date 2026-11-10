import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/budget.dart';
import '../domain/dates.dart';
import 'insights_repo.dart' show monthKey;
import 'db.dart';
import 'repo.dart';

/// Monthly budget, stored in the synced `budget_items` table (see db.dart),
/// so it follows the user to a new phone through Drive.
extension BudgetRepo on Repo {
  String get _bNow => now().toUtc().toIso8601String();

  Future<BudgetItem?> _item(String id) => (db.select(
    db.budgetItems,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<void> _putItem(
    String id,
    String kind, {
    String key = '',
    required int amount,
    int spent = 0,
  }) => db
      .into(db.budgetItems)
      .insertOnConflictUpdate(
        BudgetItemsCompanion.insert(
          id: id,
          kind: kind,
          hlc: clock.next(),
          key: Value(key),
          amountMinor: Value(amount),
          spentMinor: Value(spent),
          deletedAt: const Value(null),
        ),
      );

  Future<void> _dropItem(String id) async {
    final cur = await _item(id);
    if (cur == null) return;
    await db
        .into(db.budgetItems)
        .insertOnConflictUpdate(
          cur
              .toCompanion(true)
              .copyWith(deletedAt: Value(_bNow), hlc: Value(clock.next())),
        );
  }

  /// One-time move of a budget saved by an older version (device settings)
  /// into the synced table.
  Future<void> migrateBudgetSettings() async {
    if (await getSetting('budgetMigrated') == '1') return;
    final base = int.tryParse(await getSetting('budgetMinor') ?? '');
    if (base != null) await _putItem('base', 'base', amount: base);
    final rows = await db.select(db.settings).get();
    for (final r in rows) {
      if (r.key.startsWith('budget_') && r.key.length == 14) {
        final m = int.tryParse(r.value);
        final month = r.key.substring(7);
        if (m != null) {
          await _putItem('month:$month', 'month', key: month, amount: m);
        }
      } else if (r.key.startsWith('budgetResult_')) {
        final month = r.key.substring(13);
        final p = r.value.split('|');
        if (p.length == 2) {
          await _putItem(
            'result:$month',
            'result',
            key: month,
            amount: int.parse(p[0]),
            spent: int.parse(p[1]),
          );
        }
      }
    }
    final since = await getSetting('budgetSince');
    if (since != null) await _putItem('since', 'since', key: since, amount: 0);
    final splitRaw = await getSetting('budgetSplit');
    if (splitRaw != null && splitRaw.isNotEmpty) {
      try {
        for (final e
            in (jsonDecode(splitRaw) as Map<String, dynamic>).entries) {
          await _putItem(
            'split:${e.key}',
            'split',
            key: e.key,
            amount: (e.value as num).toInt(),
          );
        }
      } catch (_) {}
    }
    await setSetting('budgetMigrated', '1');
  }

  /// 'overall' (one amount) or 'category' (an amount per category; the total
  /// is their sum). Existing budgets stay 'overall'.
  Future<String> budgetMode() async =>
      (await _item('mode'))?.key == 'category' ? 'category' : 'overall';

  Future<void> setBudgetMode(String mode) async {
    if (mode == 'category') {
      await _putItem('mode', 'mode', key: 'category', amount: 0);
    } else {
      // keep today's total as the one overall amount
      final now = today;
      final total = await budgetFor(now.year, now.month);
      await _putItem('mode', 'mode', key: 'overall', amount: 0);
      if (total != null && total > 0) {
        await _putItem('base', 'base', amount: total);
      }
    }
  }

  Future<int?> budgetFor(int y, int m) async {
    if (await budgetMode() == 'category') {
      final sum = (await budgetSplits(month: monthKey(y, m))).values
          .fold<int>(0, (a, b) => a + b);
      return sum > 0 ? sum : null;
    }
    final over = await _item('month:${monthKey(y, m)}');
    if (over != null) return over.amountMinor;
    return (await _item('base'))?.amountMinor;
  }

  /// Saves a budget split by category. For every month, or only for [month]
  /// (then that month has its own list and other months are untouched).
  Future<void> saveCategoryBudget(
    Map<String, int> amounts, {
    DateTime? month,
  }) async {
    final clean = {
      for (final e in amounts.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (clean.isEmpty) {
      throw ValidationException('Enter an amount for at least one category');
    }
    await _putItem('mode', 'mode', key: 'category', amount: 0);
    if (month == null) {
      for (final id in (await budgetSplits()).keys) {
        if (!clean.containsKey(id)) await _dropItem('split:$id');
      }
      for (final e in clean.entries) {
        await _putItem('split:${e.key}', 'split', key: e.key, amount: e.value);
      }
    } else {
      final mk = monthKey(month.year, month.month);
      for (final r in await _monthSplitRows(mk)) {
        if (!clean.containsKey(r.key.split('|').last)) await _dropItem(r.id);
      }
      for (final e in clean.entries) {
        await _putItem(
          'msplit:$mk|${e.key}',
          'msplit',
          key: '$mk|${e.key}',
          amount: e.value,
        );
      }
    }
    final t = month ?? today;
    if (await _item('since') == null) {
      await _putItem(
        'since',
        'since',
        key: monthKey(t.year, t.month),
        amount: 0,
      );
    }
  }

  Future<List<BudgetItem>> _monthSplitRows(String mk) async =>
      (await (db.select(db.budgetItems)
                ..where((t) => t.kind.equals('msplit') & t.deletedAt.isNull()))
              .get())
          .where((r) => r.key.startsWith('$mk|'))
          .toList();

  /// Whether [month] has its own category amounts.
  Future<bool> hasMonthCategoryBudget(String mk) async =>
      (await _monthSplitRows(mk)).isNotEmpty;

  /// Sets the budget for every month, or only for [month] when given.
  Future<void> setBudget(int? minor, {DateTime? month}) async {
    if (minor != null && minor <= 0) {
      throw ValidationException('Budget must be more than zero');
    }
    if (month != null) {
      final key = monthKey(month.year, month.month);
      if (minor == null) {
        await _dropItem('month:$key');
      } else {
        await _putItem('month:$key', 'month', key: key, amount: minor);
      }
    } else if (minor == null) {
      await _dropItem('base');
    } else {
      await _putItem('base', 'base', amount: minor);
    }
    if (minor != null && await _item('since') == null) {
      final t = month ?? today;
      await _putItem(
        'since',
        'since',
        key: monthKey(t.year, t.month),
        amount: 0,
      );
    }
  }

  /// Category amounts for [month] ("YYYY-MM"): that month's own list when it
  /// has one, else the amounts that repeat every month.
  Future<Map<String, int>> budgetSplits({String? month}) async {
    if (month != null) {
      final own = await _monthSplitRows(month);
      if (own.isNotEmpty) {
        return {for (final r in own) r.key.split('|').last: r.amountMinor};
      }
    }
    final rows = await (db.select(
      db.budgetItems,
    )..where((t) => t.kind.equals('split') & t.deletedAt.isNull())).get();
    return {for (final r in rows) r.key: r.amountMinor};
  }

  /// Allocates [minor] to a main category (null or 0 removes it).
  Future<void> setBudgetSplit(String categoryId, int? minor) async {
    if (minor == null || minor <= 0) {
      await _dropItem('split:$categoryId');
    } else {
      await _putItem(
        'split:$categoryId',
        'split',
        key: categoryId,
        amount: minor,
      );
    }
  }

  Future<Map<String, int>> _spentByMainCategory(DateRange r) async {
    final rows = await db
        .customSelect(
          '''SELECT COALESCE(p.id, c.id, '_none') AS cid, SUM(t.amount_minor) AS s
             FROM transactions t
             LEFT JOIN categories c ON c.id = t.category_id
             LEFT JOIN categories p ON p.id = c.parent_id
             WHERE t.type='debit' AND t.source NOT IN ('debt','invest')
               AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ?
             GROUP BY COALESCE(p.id, c.id, '_none')''',
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions, db.categories},
        )
        .get();
    return {for (final x in rows) x.read<String>('cid'): x.read<int>('s')};
  }

  /// null when no budget is set for that month.
  Future<BudgetStatus?> budgetStatus(int y, int m) async {
    final budget = await budgetFor(y, m);
    if (budget == null) return null;
    final r = DateRange(
      Dates.day(y, m, 1),
      Dates.day(y, m, Dates.daysInMonth(y, m)),
    );
    final now = today;
    final elapsed = now.isBefore(r.start)
        ? 0
        : (now.isAfter(r.end) ? r.days : now.difference(r.start).inDays + 1);
    final byCat = await _spentByMainCategory(r);
    final spent = byCat.values.fold<int>(0, (a, b) => a + b);
    final splits = await budgetSplits(month: monthKey(y, m));
    final cats = {for (final c in await categories(kind: 'debit')) c.id: c};
    final rows = <SplitRow>[];
    var inSplits = 0;
    for (final e in splits.entries) {
      final c = cats[e.key];
      if (c == null) continue; // category was removed
      final s = byCat[e.key] ?? 0;
      inSplits += s;
      rows.add(
        SplitRow(
          id: c.id,
          name: c.name,
          colorValue: c.colorValue,
          allocated: e.value,
          spent: s,
        ),
      );
    }
    rows.sort((a, b) => b.allocated.compareTo(a.allocated));
    // everything outside the splits, so the rows always add up to the total
    final rest = spent - inSplits;
    if (rows.isNotEmpty || rest > 0) {
      rows.add(
        SplitRow(
          id: '_else',
          name: 'Everything else',
          colorValue: 0xFF64748B,
          allocated: 0,
          spent: rest,
        ),
      );
    }
    return BudgetStatus(
      year: y,
      month: m,
      budget: budget,
      spent: spent,
      monthOnly:
          await _item('month:${monthKey(y, m)}') != null ||
          await hasMonthCategoryBudget(monthKey(y, m)),
      splits: rows,
      daysInMonth: r.days,
      daysElapsed: elapsed,
    );
  }

  /// Freezes the result of each finished month since the budget began, so
  /// later edits to the budget never rewrite history.
  Future<void> ensureBudgetResults() async {
    final since = (await _item('since'))?.key;
    if (since == null) return;
    final now = today;
    for (var k = 1; k <= 12; k++) {
      final d = Dates.addMonths(Dates.day(now.year, now.month, 1), -k);
      final key = monthKey(d.year, d.month);
      if (key.compareTo(since) < 0) continue;
      if (await _item('result:$key') != null) continue;
      final s = await budgetStatus(d.year, d.month);
      if (s == null) continue;
      await _putItem(
        'result:$key',
        'result',
        key: key,
        amount: s.budget,
        spent: s.spent,
      );
    }
  }

  /// Finished months, newest first.
  Future<List<BudgetMonth>> budgetHistory() async {
    await ensureBudgetResults();
    final rows = await (db.select(
      db.budgetItems,
    )..where((t) => t.kind.equals('result') & t.deletedAt.isNull())).get();
    final out = [
      for (final r in rows) BudgetMonth(r.key, r.amountMinor, r.spentMinor),
    ];
    out.sort((a, b) => b.month.compareTo(a.month));
    return out;
  }

  /// Cumulative spending for each day of the month so far (index 0 = day 1).
  Future<List<int>> budgetDaily(int y, int m) async {
    final r = DateRange(
      Dates.day(y, m, 1),
      Dates.day(y, m, Dates.daysInMonth(y, m)),
    );
    final now = today;
    final last = now.isBefore(r.start)
        ? 0
        : (now.isAfter(r.end) ? r.days : now.difference(r.start).inDays + 1);
    final rows = await db
        .customSelect(
          "SELECT date AS d, SUM(amount_minor) AS s FROM transactions WHERE type='debit' AND source NOT IN ('debt','invest') AND deleted_at IS NULL AND date BETWEEN ? AND ? GROUP BY date",
          variables: [Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .get();
    final byDay = {for (final x in rows) x.read<String>('d'): x.read<int>('s')};
    var run = 0;
    final out = <int>[];
    for (var i = 0; i < last; i++) {
      run += byDay[Dates.str(r.start.add(Duration(days: i)))] ?? 0;
      out.add(run);
    }
    return out;
  }

  /// All 12 months of [year]: what was spent against the budget of that
  /// month (frozen result when the month is finished).
  Future<List<BudgetYearMonth>> budgetYear(int year) async {
    await ensureBudgetResults();
    final now = today;
    final out = <BudgetYearMonth>[];
    for (var m = 1; m <= 12; m++) {
      final future = year > now.year || (year == now.year && m > now.month);
      final current = year == now.year && m == now.month;
      if (future) {
        out.add(
          BudgetYearMonth(
            month: m,
            spent: 0,
            budget: await budgetFor(year, m),
            future: true,
          ),
        );
        continue;
      }
      final frozen = await _item('result:${monthKey(year, m)}');
      if (frozen != null && !current) {
        out.add(
          BudgetYearMonth(
            month: m,
            spent: frozen.spentMinor,
            budget: frozen.amountMinor,
          ),
        );
        continue;
      }
      final r = DateRange(
        Dates.day(year, m, 1),
        Dates.day(year, m, Dates.daysInMonth(year, m)),
      );
      final byCat = await _spentByMainCategory(r);
      final since = (await _item('since'))?.key;
      final tracked = since != null && monthKey(year, m).compareTo(since) >= 0;
      out.add(
        BudgetYearMonth(
          month: m,
          spent: byCat.values.fold<int>(0, (a, b) => a + b),
          budget: tracked || current ? await budgetFor(year, m) : null,
          current: current,
        ),
      );
    }
    return out;
  }
}

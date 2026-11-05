import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/budget.dart';
import '../domain/dates.dart';
import 'insights_repo.dart' show monthKey;
import 'repo.dart';

/// Monthly budget kept in device settings:
///  * `budgetMinor`          the amount that applies to every month
///  * `budget_YYYY-MM`       a one-month override
///  * `budgetSplit`          JSON {categoryId: allocatedMinor}
///  * `budgetSince`          first month a budget existed (history starts here)
///  * `budgetResult_YYYY-MM` frozen "budget|spent" of a finished month
extension BudgetRepo on Repo {
  Future<int?> budgetFor(int y, int m) async {
    final over = int.tryParse(
      await getSetting('budget_${monthKey(y, m)}') ?? '',
    );
    if (over != null) return over;
    return int.tryParse(await getSetting('budgetMinor') ?? '');
  }

  /// Sets the budget for every month, or only for [month] when given.
  Future<void> setBudget(int? minor, {DateTime? month}) async {
    if (minor != null && minor <= 0) {
      throw ValidationException('Budget must be more than zero');
    }
    if (month != null) {
      final key = 'budget_${monthKey(month.year, month.month)}';
      if (minor == null) {
        await db.customStatement('DELETE FROM settings WHERE key = ?', [key]);
      } else {
        await setSetting(key, '$minor');
      }
    } else if (minor == null) {
      await db.customStatement(
        "DELETE FROM settings WHERE key = 'budgetMinor'",
      );
    } else {
      await setSetting('budgetMinor', '$minor');
    }
    if (minor != null && await getSetting('budgetSince') == null) {
      final t = month ?? today;
      await setSetting('budgetSince', monthKey(t.year, t.month));
    }
  }

  Future<Map<String, int>> budgetSplits() async {
    final raw = await getSetting('budgetSplit');
    if (raw == null || raw.isEmpty) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Allocates [minor] to a main category (null or 0 removes it).
  Future<void> setBudgetSplit(String categoryId, int? minor) async {
    final m = await budgetSplits();
    if (minor == null || minor <= 0) {
      m.remove(categoryId);
    } else {
      m[categoryId] = minor;
    }
    await setSetting('budgetSplit', jsonEncode(m));
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
    final splits = await budgetSplits();
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
      monthOnly: await getSetting('budget_${monthKey(y, m)}') != null,
      splits: rows,
      daysInMonth: r.days,
      daysElapsed: elapsed,
    );
  }

  /// Freezes the result of each finished month since the budget began, so
  /// later edits to the budget never rewrite history.
  Future<void> ensureBudgetResults() async {
    final since = await getSetting('budgetSince');
    if (since == null) return;
    final now = today;
    for (var k = 1; k <= 12; k++) {
      final d = Dates.addMonths(Dates.day(now.year, now.month, 1), -k);
      final key = monthKey(d.year, d.month);
      if (key.compareTo(since) < 0) continue;
      if (await getSetting('budgetResult_$key') != null) continue;
      final s = await budgetStatus(d.year, d.month);
      if (s == null) continue;
      await setSetting('budgetResult_$key', '${s.budget}|${s.spent}');
    }
  }

  /// Finished months, newest first.
  Future<List<BudgetMonth>> budgetHistory() async {
    await ensureBudgetResults();
    final rows = await (db.select(
      db.settings,
    )..where((s) => s.key.like('budgetResult_%'))).get();
    final out = <BudgetMonth>[];
    for (final r in rows) {
      final p = r.value.split('|');
      if (p.length != 2) continue;
      out.add(
        BudgetMonth(r.key.substring(13), int.parse(p[0]), int.parse(p[1])),
      );
    }
    out.sort((a, b) => b.month.compareTo(a.month));
    return out;
  }
}

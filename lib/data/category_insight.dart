import 'package:drift/drift.dart';

import '../domain/dates.dart';
import 'repo.dart';

/// Everything the "tap a category" page shows.
class CategoryInsight {
  final String name;
  final String? parentName;
  final int total, prevTotal, count, allSpending;
  final int days;
  final List<({String label, int minor})> monthly; // oldest first
  final List<CatSlice> subs;
  final List<({String date, String title, int minor})> top;
  const CategoryInsight({
    required this.name,
    required this.parentName,
    required this.total,
    required this.prevTotal,
    required this.count,
    required this.allSpending,
    required this.days,
    required this.monthly,
    required this.subs,
    required this.top,
  });

  int get perDay => days <= 0 ? 0 : (total / days).round();
  int get perMonth => (perDay * 30);
  int get avgPerEntry => count == 0 ? 0 : (total / count).round();
  double get sharePct => allSpending <= 0 ? 0 : total * 100 / allSpending;

  /// Change against the previous period of the same length (null = no history).
  double? get changePct =>
      prevTotal <= 0 ? null : (total - prevTotal) * 100 / prevTotal;
}

extension CategoryInsightRepo on Repo {
  Future<CategoryInsight> categoryInsight(
    String categoryId,
    DateRange r, {
    String type = 'debit',
  }) async {
    final cat = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    final parent = cat?.parentId == null
        ? null
        : await (db.select(
            db.categories,
          )..where((c) => c.id.equals(cat!.parentId!))).getSingleOrNull();
    final children = await (db.select(
      db.categories,
    )..where((c) => c.parentId.equals(categoryId))).get();
    final ids = [categoryId, ...children.map((c) => c.id)];
    final marks = List.filled(ids.length, '?').join(',');
    final base =
        "t.type = ? AND t.source NOT IN ('debt','invest') AND t.deleted_at IS NULL";

    Future<(int, int)> sum(DateRange x) async {
      final row = await db
          .customSelect(
            'SELECT COALESCE(SUM(t.amount_minor),0) AS s, COUNT(*) AS n '
            'FROM transactions t WHERE $base AND t.category_id IN ($marks) '
            'AND t.date BETWEEN ? AND ?',
            variables: [
              Variable(type),
              for (final i in ids) Variable(i),
              Variable(x.startStr),
              Variable(x.endStr),
            ],
            readsFrom: {db.transactions},
          )
          .getSingle();
      return (row.read<int>('s'), row.read<int>('n'));
    }

    final (total, count) = await sum(r);
    final (prevTotal, _) = await sum(r.previous);

    final allRow = await db
        .customSelect(
          'SELECT COALESCE(SUM(t.amount_minor),0) AS s FROM transactions t '
          'WHERE $base AND t.date BETWEEN ? AND ?',
          variables: [Variable(type), Variable(r.startStr), Variable(r.endStr)],
          readsFrom: {db.transactions},
        )
        .getSingle();

    // last six calendar months ending with the month of the range's end
    final monthly = <({String label, int minor})>[];
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (var k = 5; k >= 0; k--) {
      final m = Dates.addMonths(Dates.day(r.end.year, r.end.month, 1), -k);
      final mr = DateRange(
        Dates.day(m.year, m.month, 1),
        Dates.day(m.year, m.month + 1, 0),
      );
      final (s, _) = await sum(mr);
      monthly.add((label: names[m.month - 1], minor: s));
    }

    // sub-category split (only meaningful for a main category)
    final subs = <CatSlice>[];
    if (children.isNotEmpty) {
      final rows = await db
          .customSelect(
            'SELECT c.id AS cid, c.name AS cname, c.color_value AS color, '
            'SUM(t.amount_minor) AS s FROM transactions t '
            'JOIN categories c ON c.id = t.category_id '
            'WHERE $base AND t.category_id IN ($marks) '
            'AND t.date BETWEEN ? AND ? GROUP BY c.id ORDER BY s DESC',
            variables: [
              Variable(type),
              for (final i in ids) Variable(i),
              Variable(r.startStr),
              Variable(r.endStr),
            ],
            readsFrom: {db.transactions, db.categories},
          )
          .get();
      for (final x in rows) {
        final id = x.read<String>('cid');
        subs.add(
          CatSlice(
            id,
            id == categoryId
                ? 'Other ${cat?.name ?? ''}'
                : x.read<String>('cname'),
            x.read<int>('color'),
            x.read<int>('s'),
            parentName: cat?.name,
          ),
        );
      }
    }

    final topRows = await db
        .customSelect(
          'SELECT t.date AS d, COALESCE(NULLIF(t.merchant,\'\'), NULLIF(t.note,\'\'), c.name) AS title, '
          't.amount_minor AS a FROM transactions t '
          'LEFT JOIN categories c ON c.id = t.category_id '
          'WHERE $base AND t.category_id IN ($marks) AND t.date BETWEEN ? AND ? '
          'ORDER BY t.amount_minor DESC LIMIT 5',
          variables: [
            Variable(type),
            for (final i in ids) Variable(i),
            Variable(r.startStr),
            Variable(r.endStr),
          ],
          readsFrom: {db.transactions, db.categories},
        )
        .get();

    return CategoryInsight(
      name: cat?.name ?? 'Category',
      parentName: parent?.name,
      total: total,
      prevTotal: prevTotal,
      count: count,
      allSpending: allRow.read<int>('s'),
      days: r.days,
      monthly: monthly,
      subs: subs,
      top: [
        for (final x in topRows)
          (
            date: x.read<String>('d'),
            title: x.read<String?>('title') ?? '',
            minor: x.read<int>('a'),
          ),
      ],
    );
  }
}

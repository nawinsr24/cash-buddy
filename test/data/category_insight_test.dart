import 'package:cash_buddy/data/category_insight.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test(
    'category insight: totals, share, subs, trend and biggest expenses add up',
    () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      await r.addTransaction(
        type: 'debit',
        amountMinor: 50000,
        categoryId: 'cat_health_medicines',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 150000,
        categoryId: 'cat_health_doctor_visit',
        merchant: 'Dr Rao',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 100000,
        categoryId: 'cat_food_groceries',
      );
      final range = DateRange.thisMonth(e.clockNow);
      final x = await r.categoryInsight('cat_health', range);
      expect(x.total, 200000);
      expect(x.count, 2);
      expect(x.allSpending, 300000);
      expect(x.sharePct.round(), 67);
      expect(x.subs.map((s) => s.totalMinor).toList(), [150000, 50000]);
      expect(x.top.first.title, 'Dr Rao');
      expect(x.avgPerEntry, 100000);
      expect(x.monthly.length, 6);
      expect(x.monthly.last.minor, 200000);
      // a sub-category on its own
      final y = await r.categoryInsight('cat_health_medicines', range);
      expect(y.total, 50000);
      expect(y.parentName, 'Health');
      // sub-category view of the dashboard
      final d = await r.dashboard(range);
      expect(d.spendingBySub.length, 3);
      expect(d.spendingByCategory.length, 2);
    },
  );
}

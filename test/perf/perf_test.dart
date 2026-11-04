import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

void main() {
  test('100k transactions: dashboard, balances and search stay fast', () async {
    final e = await newEnv(accountMode: 'split', opening: 1000000);
    final r = e.repo;
    // bulk insert with raw SQL (the repo API is one-row-at-a-time by design)
    await e.db.transaction(() async {
      await e.db.customStatement('''
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 100000)
        INSERT INTO transactions (id, type, amount_minor, account_id, category_id, payment_method, date, note, source, hlc)
        SELECT 'p'||i, CASE WHEN i % 5 = 0 THEN 'credit' ELSE 'debit' END, 100 + (i * 37) % 90000,
               CASE WHEN i % 2 = 0 THEN 'acc_cash' ELSE 'acc_bank' END,
               CASE i % 4 WHEN 0 THEN 'cat_food_coffee' WHEN 1 THEN 'cat_bills_rent' WHEN 2 THEN 'cat_entertainment_movies' ELSE 'cat_salary' END,
               CASE WHEN i % 3 = 0 THEN 'cash' ELSE 'card' END,
               date('2026-11-04', '-' || (i % 700) || ' days'), 'note '||i, 'manual', '000000000000001-0000-x'
        FROM n''');
    });
    final sw = Stopwatch()..start();
    final d = await r.dashboard(DateRange.thisMonth(e.clockNow));
    sw.stop();
    // ignore: avoid_print
    print('dashboard over 100k rows: ${sw.elapsedMilliseconds} ms');
    expect(d.spending + d.income, greaterThan(0));
    expect(sw.elapsedMilliseconds, lessThan(300));
    sw
      ..reset()
      ..start();
    await r.balances();
    final hits = await r.searchTransactions(
      const TxnFilter(query: 'note 99999'),
    );
    sw.stop();
    // ignore: avoid_print
    print('balances + search: ${sw.elapsedMilliseconds} ms');
    expect(hits, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}

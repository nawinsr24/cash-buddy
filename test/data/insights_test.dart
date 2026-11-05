import 'package:cash_buddy/data/insights_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/grade.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  liveAndCelebration();
  // newEnv clock: 4 Nov 2026
  test('monthStats counts income, spending, invested, categories', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    final d = Dates.day(2026, 10, 5);
    await r.addTransaction(
      type: 'credit',
      amountMinor: 5000000,
      categoryId: 'cat_salary',
      date: d,
    );
    for (var i = 0; i < 12; i++) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 100000,
        categoryId: 'cat_food_dining',
        date: Dates.day(2026, 10, 1 + i),
      );
    }
    final inv = await r.createInvestment(kind: 'mutual_fund', name: 'F');
    await r.addInvestmentEntry(
      inv,
      type: 'contribute',
      amountMinor: 400000,
      date: d,
    );
    final s = await r.monthStats(2026, 10);
    expect(s.income, 5000000);
    expect(s.spending, 1200000);
    expect(s.invested, 400000);
    expect(s.txnCount, 13);
    expect(s.activeDays, 12);
    expect(s.topCategory, 'Food');
    expect(s.topShareBps, 10000);
    expect(s.complete, isTrue);
    // invest legs never count as spending
    expect(s.spending, isNot(1600000));
  });

  test('title is stored once for a finished month and never changes', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    await r.addTransaction(
      type: 'credit',
      amountMinor: 5000000,
      categoryId: 'cat_salary',
      date: Dates.day(2026, 10, 2),
    );
    for (var i = 0; i < 12; i++) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 700000,
        date: Dates.day(2026, 10, 3 + i),
      );
    }
    await r.ensureMonthTitles();
    var hist = await r.titleHistory();
    expect(hist.single.month, '2026-10');
    expect(hist.single.id, TitleId.overdraftArtist);
    // data edited afterwards: the stored title stays
    await r.addTransaction(
      type: 'credit',
      amountMinor: 99000000,
      date: Dates.day(2026, 10, 20),
    );
    await r.ensureMonthTitles();
    hist = await r.titleHistory();
    expect(hist.single.id, TitleId.overdraftArtist);
  });

  test('banner: shows in the first 7 days, until dismissed', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    for (var i = 0; i < 12; i++) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 1000,
        date: Dates.day(2026, 10, 1 + i),
      );
    }
    final b = await r.bannerTitle();
    expect(b, isNotNull);
    expect(b!.month, '2026-10');
    await r.dismissTitleBanner(b.month);
    expect(await r.bannerTitle(), isNull);
  });

  test(
    'banner is hidden after day 7 and for a month with no entries',
    () async {
      final e = await newEnv();
      expect(await e.repo.bannerTitle(), isNull); // nothing last month
      final late = await newEnv(now: DateTime(2026, 11, 12, 10));
      await late.repo.addTransaction(
        type: 'debit',
        amountMinor: 1000,
        date: Dates.day(2026, 10, 2),
      );
      expect(await late.repo.bannerTitle(), isNull);
      expect((await late.repo.titleHistory()).length, 0);
    },
  );

  test('roast mode defaults on and can be switched off', () async {
    final e = await newEnv();
    expect(await e.repo.roastMode, isTrue);
    await e.repo.setSetting('roastMode', '0');
    expect(await e.repo.roastMode, isFalse);
  });

  test('insights: forecast, net worth and recurring bills', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    // Netflix 3 months in a row, same amount, around the 10th
    for (final m in [8, 9, 10]) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 64900,
        merchant: 'Netflix',
        date: Dates.day(2026, m, 10),
      );
    }
    await r.addTransaction(
      type: 'debit',
      amountMinor: 30000,
      merchant: 'Cafe',
      date: Dates.day(2026, 11, 2),
    );
    final inv = await r.createInvestment(
      kind: 'stock',
      name: 'TCS',
      currentValueMinor: 500000,
    );
    await r.addInvestmentEntry(
      inv,
      type: 'contribute',
      amountMinor: 400000,
      date: Dates.day(2026, 11, 1),
    );
    final x = await r.insights();
    expect(x.spentSoFar, 30000);
    expect(x.projected, greaterThan(x.spentSoFar)); // 4 of 30 days elapsed
    expect(x.bills.single.merchant, 'Netflix');
    expect(x.bills.single.next, Dates.day(2026, 11, 10));
    // balance (10,000 - 3 x 649 - 300 - 4,000) + investment value 5,000
    expect(x.netWorth, 1000000 - 3 * 64900 - 30000 - 400000 + 500000);
    expect(x.daysLeft, 26);
  });

  test('overdue instalments feed the stats', () async {
    final e = await newEnv();
    await e.repo.createInvestment(
      kind: 'custom',
      name: 'SIP',
      startDate: DateTime.utc(2026, 9, 1),
      recurring: true,
      cycle: 'monthly',
      installments: 12,
    );
    final s = await e.repo.monthStats(2026, 11);
    expect(s.overdueCount, 3); // capped at 3 per plan
  });

  test('health spending is found by category and by merchant words, never from invest', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    final d = Dates.day(2026, 10, 5);
    await r.addTransaction(
      type: 'debit',
      amountMinor: 120000,
      categoryId: 'cat_health',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 45000,
      merchant: 'Apollo Pharmacy',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 80000,
      note: 'Dr. visit - clinic fee',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 999000,
      merchant: 'Swiggy',
      date: d,
    ); // not health
    final inv = await r.createInvestment(
      kind: 'custom',
      name: 'Health savings fund',
    );
    await r.addInvestmentEntry(
      inv,
      type: 'contribute',
      amountMinor: 500000,
      date: d,
    );
    final s = await r.monthStats(2026, 10);
    expect(s.healthSpending, 245000);
    expect(s.healthCount, 3);
    expect(s.spending, 1244000);
  });
}

void liveAndCelebration() {
  test(
    'live title is "fresh" in the first week, then follows the month',
    () async {
      final e = await newEnv(opening: 10000000, now: DateTime(2026, 11, 3, 10));
      await e.repo.addTransaction(
        type: 'credit',
        amountMinor: 5000000,
        categoryId: 'cat_salary',
        date: Dates.day(2026, 11, 1),
      );
      for (var i = 0; i < 12; i++) {
        await e.repo.addTransaction(
          type: 'debit',
          amountMinor: 20000,
          date: Dates.day(2026, 11, 1 + (i % 3)),
        );
      }
      final early = await e.repo.liveTitle();
      expect(early.id, TitleId.freshVictim);
      e.clockNow = DateTime(2026, 11, 12, 10);
      final later = await e.repo.liveTitle();
      expect(later.id, isNot(TitleId.freshVictim));
      expect(later.previous, TitleId.freshVictim); // shows the movement
    },
  );

  test('live title is decided once per day', () async {
    final e = await newEnv(opening: 10000000, now: DateTime(2026, 11, 15, 10));
    await e.repo.addTransaction(
      type: 'credit',
      amountMinor: 5000000,
      categoryId: 'cat_salary',
      date: Dates.day(2026, 11, 1),
    );
    for (var i = 0; i < 12; i++) {
      await e.repo.addTransaction(
        type: 'debit',
        amountMinor: 10000,
        date: Dates.day(2026, 11, 1 + i),
      );
    }
    final a = await e.repo.liveTitle();
    // a huge overspend later the same day does not flip it until tomorrow
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 9000000,
      date: Dates.day(2026, 11, 15),
    );
    final b = await e.repo.liveTitle();
    expect(b.id, a.id);
    e.clockNow = DateTime(2026, 11, 16, 10);
    final c = await e.repo.liveTitle();
    expect(c.id, TitleId.overdraftArtist);
    expect(c.previous, a.id);
  });

  test(
    'celebration shows once per month, and only when last month has a title',
    () async {
      final e = await newEnv(opening: 10000000);
      expect(await e.repo.celebrationDue(), isNull); // nothing last month
      for (var i = 0; i < 12; i++) {
        await e.repo.addTransaction(
          type: 'debit',
          amountMinor: 1000,
          date: Dates.day(2026, 10, 1 + i),
        );
      }
      final due = await e.repo.celebrationDue();
      expect(due, isNotNull);
      expect(due!.month, '2026-10');
      await e.repo.markCelebrated(due.month);
      expect(await e.repo.celebrationDue(), isNull);
      expect(await e.repo.bannerTitle(), isNull); // banner is dismissed with it
    },
  );

  test('comparison with the month before; none for a first month', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    // September: spent a lot
    await r.addTransaction(
      type: 'credit',
      amountMinor: 5000000,
      categoryId: 'cat_salary',
      date: Dates.day(2026, 9, 1),
    );
    for (var i = 0; i < 12; i++) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 300000,
        date: Dates.day(2026, 9, 2 + i),
      );
    }
    // October: spent less, invested
    await r.addTransaction(
      type: 'credit',
      amountMinor: 5000000,
      categoryId: 'cat_salary',
      date: Dates.day(2026, 10, 1),
    );
    for (var i = 0; i < 12; i++) {
      await r.addTransaction(
        type: 'debit',
        amountMinor: 100000,
        date: Dates.day(2026, 10, 2 + i),
      );
    }
    final inv = await r.createInvestment(kind: 'mutual_fund', name: 'F');
    await r.addInvestmentEntry(
      inv,
      type: 'contribute',
      amountMinor: 800000,
      date: Dates.day(2026, 10, 5),
    );
    await r.ensureMonthTitles();
    final oct = (await r.titleHistory()).firstWhere(
      (t) => t.month == '2026-10',
    );
    final c = (await r.comparisonFor(oct))!;
    expect(c.score, greaterThan(c.previousScore));
    final spent = c.rows.firstWhere((x) => x.label == 'Spent');
    expect(spent.better, isTrue); // lower spending is better
    expect(spent.trend, -1); // and the number really went down
    final saved = c.rows.firstWhere((x) => x.label == 'Saved');
    expect(saved.better, isTrue);
    expect(c.rows.any((x) => x.label == 'Invested'), isTrue);
    final sep = (await r.titleHistory()).firstWhere(
      (t) => t.month == '2026-09',
    );
    expect(await r.comparisonFor(sep), isNull); // no August data
  });
}

import 'dart:math';

import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test(
    'onboarding seeds categories with two debit levels and credit presets',
    () async {
      final e = await newEnv();
      final credit = await e.repo.categories(kind: 'credit');
      expect(
        credit.map((c) => c.name),
        containsAll(['Salary', 'Cash Received']),
      );
      final debit = await e.repo.categories(kind: 'debit');
      final ent = debit.firstWhere((c) => c.name == 'Entertainment');
      final movies = debit.firstWhere((c) => c.name == 'Movies');
      expect(movies.parentId, ent.id);
      expect(await e.repo.isOnboarded, isTrue);
    },
  );

  test(
    'balance = opening + credits - debits, updated on add/edit/delete/restore',
    () async {
      final e = await newEnv(opening: 100000);
      final r = e.repo;
      expect(await r.totalBalance(), 100000);
      final salary = await r.addTransaction(
        type: 'credit',
        amountMinor: 500000,
        categoryId: 'cat_salary',
      );
      final food = await r.addTransaction(
        type: 'debit',
        amountMinor: 25000,
        categoryId: 'cat_food',
      );
      expect(await r.totalBalance(), 100000 + 500000 - 25000);
      await r.updateTransaction(food, amountMinor: 30000);
      expect(await r.totalBalance(), 100000 + 500000 - 30000);
      await r.updateTransaction(food, type: 'credit');
      expect(await r.totalBalance(), 100000 + 500000 + 30000);
      await r.deleteTransaction(salary);
      expect(await r.totalBalance(), 100000 + 30000);
      await r.restoreTransaction(salary);
      expect(await r.totalBalance(), 100000 + 500000 + 30000);
    },
  );

  test('validation', () async {
    final e = await newEnv();
    expect(
      () => e.repo.addTransaction(type: 'debit', amountMinor: 0),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => e.repo.addTransaction(type: 'debit', amountMinor: -5),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => e.repo.addTransaction(type: 'transfer', amountMinor: 5),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => e.repo.addTransaction(type: 'bogus', amountMinor: 5),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'split mode: transfers move money but are not income or spending',
    () async {
      final e = await newEnv(accountMode: 'split', opening: 50000);
      final r = e.repo;
      await r.addTransaction(
        type: 'transfer',
        amountMinor: 20000,
        accountId: 'acc_cash',
        toAccountId: 'acc_bank',
      );
      final b = await r.balances();
      expect(b['acc_cash'], 30000);
      expect(b['acc_bank'], 20000);
      expect(await r.totalBalance(), 50000);
      final d = await r.dashboard(DateRange.thisMonth(e.clockNow));
      expect(d.spending, 0);
      expect(d.income, 0);
    },
  );

  test(
    'Combined -> Split -> Combined preserves total and history (lossless)',
    () async {
      final e = await newEnv(opening: 70000);
      final r = e.repo;
      await r.addTransaction(type: 'debit', amountMinor: 10000);
      final total = await r.totalBalance();
      await r.setAccountMode('split');
      expect(await r.totalBalance(), total);
      final names = (await r.accounts()).map((a) => a.name);
      expect(names, containsAll(['Cash', 'Bank']));
      await r.addTransaction(
        type: 'debit',
        amountMinor: 5000,
        accountId: 'acc_cash',
      );
      await r.setAccountMode('combined');
      expect(await r.totalBalance(), total - 5000);
      await r.setAccountMode('split');
      expect((await r.accounts()).length, 2); // no duplicates
      expect(await r.totalBalance(), total - 5000);
    },
  );

  test('search and filters', () async {
    final e = await newEnv();
    final r = e.repo;
    await r.addTransaction(
      type: 'debit',
      amountMinor: 12000,
      categoryId: 'cat_entertainment_movies',
      merchant: 'PVR',
      note: 'avengers',
      paymentMethod: 'card',
      date: Dates.day(2026, 11, 2),
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 8000,
      categoryId: 'cat_food_coffee',
      merchant: 'Starbucks',
      paymentMethod: 'cash',
      date: Dates.day(2026, 10, 20),
    );
    await r.addTransaction(
      type: 'credit',
      amountMinor: 900000,
      categoryId: 'cat_salary',
      date: Dates.day(2026, 11, 1),
    );
    Future<int> n(TxnFilter f) async => (await r.searchTransactions(f)).length;
    expect(await n(const TxnFilter()), 3);
    expect(await n(const TxnFilter(query: 'pvr')), 1);
    expect(await n(const TxnFilter(query: 'avengers')), 1);
    expect(await n(const TxnFilter(type: 'credit')), 1);
    expect(
      await n(const TxnFilter(categoryId: 'cat_entertainment')),
      1,
    ); // parent matches child
    expect(await n(const TxnFilter(paymentMethod: 'cash')), 1);
    expect(await n(TxnFilter(range: DateRange.thisMonth(e.clockNow))), 2);
    expect(await n(const TxnFilter(minMinor: 10000, maxMinor: 20000)), 1);
    expect(await n(const TxnFilter(query: '%')), 0); // wildcard is escaped
  });

  test('category rules: two levels, rename, reassign on delete', () async {
    final e = await newEnv();
    final r = e.repo;
    final sub = await r.addCategory(
      'Anime',
      'debit',
      parentId: 'cat_entertainment',
    );
    expect(
      () => r.addCategory('Deep', 'debit', parentId: sub),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => r.addCategory('X', 'credit', parentId: 'cat_entertainment'),
      throwsA(isA<ValidationException>()),
    );
    await r.updateCategory(sub, name: 'Anime & Manga', color: 0xFF112233);
    final c = (await r.categories()).firstWhere((x) => x.id == sub);
    expect(c.name, 'Anime & Manga');
    expect(c.colorValue, 0xFF112233);
    await r.addTransaction(type: 'debit', amountMinor: 100, categoryId: sub);
    expect(() => r.deleteCategory(sub), throwsA(isA<ValidationException>()));
    await r.deleteCategory(sub, reassignTo: 'cat_other');
    final t = (await r.searchTransactions(const TxnFilter())).single;
    expect(t.categoryId, 'cat_other');
    expect((await r.categories()).any((x) => x.id == sub), isFalse);
  });

  test(
    'dashboard: spending/income/breakdowns roll subcategories into the parent',
    () async {
      final e = await newEnv();
      final r = e.repo;
      final d = Dates.day(2026, 11, 3);
      await r.addTransaction(
        type: 'debit',
        amountMinor: 10000,
        categoryId: 'cat_entertainment_movies',
        date: d,
        paymentMethod: 'card',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 5000,
        categoryId: 'cat_entertainment_games',
        date: d,
        paymentMethod: 'cash',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 7000,
        categoryId: 'cat_food',
        date: d,
      );
      await r.addTransaction(
        type: 'credit',
        amountMinor: 100000,
        categoryId: 'cat_salary',
        date: d,
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 999,
        date: Dates.day(2026, 10, 3),
      ); // previous month
      final x = await r.dashboard(DateRange.thisMonth(e.clockNow));
      expect(x.spending, 22000);
      expect(x.income, 100000);
      expect(x.prevSpending, 999);
      final ent = x.spendingByCategory.firstWhere(
        (s) => s.name == 'Entertainment',
      );
      expect(ent.totalMinor, 15000);
      expect(
        x.spendingByCategory.map((s) => s.totalMinor).reduce((a, b) => a + b),
        x.spending,
      );
      expect(x.cardSpending, 10000);
      expect(x.cashSpending, 5000);
      expect(x.dailySpending['2026-11-03'], 22000);
    },
  );

  test('property: balances always equal an independent model after random operations', () async {
    final e = await newEnv(accountMode: 'split', opening: 123456);
    final r = e.repo;
    final rng = Random(7);
    final live = <String, (String type, int amt, String acc, String? to)>{};
    for (var i = 0; i < 300; i++) {
      final op = rng.nextInt(4);
      if (op < 2 || live.isEmpty) {
        final type = ['credit', 'debit', 'transfer'][rng.nextInt(3)];
        final acc = rng.nextBool() ? 'acc_cash' : 'acc_bank';
        final to = type == 'transfer'
            ? (acc == 'acc_cash' ? 'acc_bank' : 'acc_cash')
            : null;
        final amt = 1 + rng.nextInt(100000);
        final id = await r.addTransaction(
          type: type,
          amountMinor: amt,
          accountId: acc,
          toAccountId: to,
        );
        live[id] = (type, amt, acc, to);
      } else if (op == 2) {
        final id = live.keys.elementAt(rng.nextInt(live.length));
        await r.deleteTransaction(id);
        live.remove(id);
      } else {
        final id = live.keys.elementAt(rng.nextInt(live.length));
        final cur = live[id]!;
        final amt = 1 + rng.nextInt(100000);
        await r.updateTransaction(id, amountMinor: amt);
        live[id] = (cur.$1, amt, cur.$3, cur.$4);
      }
    }
    var cash = 123456, bank = 0;
    void apply(String acc, int v) => acc == 'acc_cash' ? cash += v : bank += v;
    for (final t in live.values) {
      switch (t.$1) {
        case 'credit':
          apply(t.$3, t.$2);
        case 'debit':
          apply(t.$3, -t.$2);
        case 'transfer':
          apply(t.$3, -t.$2);
          apply(t.$4!, t.$2);
      }
    }
    final b = await r.balances();
    expect(b['acc_cash'], cash);
    expect(b['acc_bank'], bank);
    expect(await r.checkInvariants(), isEmpty);
  });
}

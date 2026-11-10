import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/budget.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> spend(Repo r, int amount, String cat, {int day = 2}) => r
    .addTransaction(
      type: 'debit',
      amountMinor: amount,
      categoryId: cat,
      date: Dates.day(2026, 11, day),
    )
    .then((_) {});

void main() {
  // newEnv clock: 4 Nov 2026
  test('state: strictly under, exactly equal, over', () {
    expect(budgetState(99, 100), BudgetState.under);
    expect(budgetState(100, 100), BudgetState.exact);
    expect(budgetState(101, 100), BudgetState.over);
    expect(budgetState(0, 100), BudgetState.under);
  });

  test('no budget set: no status', () async {
    final e = await newEnv();
    expect(await e.repo.budgetStatus(2026, 11), isNull);
  });

  test('budget applies to every month and can be overridden for one', () async {
    final e = await newEnv();
    await e.repo.setBudget(3000000);
    expect(await e.repo.budgetFor(2026, 11), 3000000);
    expect(await e.repo.budgetFor(2027, 3), 3000000);
    await e.repo.setBudget(4000000, month: DateTime(2026, 12));
    expect(await e.repo.budgetFor(2026, 12), 4000000);
    expect(await e.repo.budgetFor(2027, 1), 3000000);
    await e.repo.setBudget(null, month: DateTime(2026, 12));
    expect(await e.repo.budgetFor(2026, 12), 3000000);
    expect(() => e.repo.setBudget(0), throwsA(isA<ValidationException>()));
  });

  test(
    'spent counts expenses only: not debt principal, not investments',
    () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      await r.setBudget(1000000);
      await spend(r, 300000, 'cat_food_groceries');
      final inv = await r.createInvestment(kind: 'stock', name: 'X');
      await r.addInvestmentEntry(
        inv,
        type: 'contribute',
        amountMinor: 500000,
        date: Dates.day(2026, 11, 2),
      );
      await r.createDebt(
        direction: 'receivable',
        counterparty: 'R',
        principalMinor: 200000,
        issuedOn: Dates.day(2026, 11, 2),
      );
      final s = (await r.budgetStatus(2026, 11))!;
      expect(s.spent, 300000);
      expect(s.state, BudgetState.under);
      expect(s.remaining, 700000);
    },
  );

  test('exactly on budget, then over', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    await r.setBudget(500000);
    await spend(r, 500000, 'cat_food_groceries');
    var s = (await r.budgetStatus(2026, 11))!;
    expect(s.state, BudgetState.exact);
    expect(s.remaining, 0);
    await spend(r, 100, 'cat_food_groceries');
    s = (await r.budgetStatus(2026, 11))!;
    expect(s.state, BudgetState.over);
    expect(s.remaining, -100);
  });

  test(
    'allocated for movies but spent on health is fine while overall holds',
    () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      await r.setBudget(1000000);
      await r.setBudgetSplit('cat_entertainment', 200000);
      await r.setBudgetSplit('cat_health', 100000);
      await spend(r, 0 + 1, 'cat_entertainment_movies'); // barely used
      await spend(r, 350000, 'cat_health'); // far over its split
      final s = (await r.budgetStatus(2026, 11))!;
      expect(s.state, BudgetState.under); // overall is what matters
      final health = s.splits.firstWhere((x) => x.id == 'cat_health');
      expect(health.state, BudgetState.over);
      final ent = s.splits.firstWhere((x) => x.id == 'cat_entertainment');
      expect(ent.state, BudgetState.under);
      expect(s.splitsOffButFine, isTrue);
      // rows always add up to the total spent
      expect(s.splits.fold<int>(0, (a, x) => a + x.spent), s.spent);
    },
  );

  test('subcategory spending rolls into its main category split', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    await r.setBudget(1000000);
    await r.setBudgetSplit('cat_food', 300000);
    await spend(r, 100000, 'cat_food_groceries');
    await spend(r, 50000, 'cat_food_dining');
    await spend(r, 70000, 'cat_transport_fuel');
    final s = (await r.budgetStatus(2026, 11))!;
    expect(s.splits.firstWhere((x) => x.id == 'cat_food').spent, 150000);
    expect(s.splits.firstWhere((x) => x.isElse).spent, 70000);
    expect(s.unallocated, 700000);
    expect(s.overAllocated, isFalse);
  });

  test('over-allocation is flagged and removing a split works', () async {
    final e = await newEnv();
    final r = e.repo;
    await r.setBudget(100000);
    await r.setBudgetSplit('cat_food', 80000);
    await r.setBudgetSplit('cat_transport', 80000);
    expect((await r.budgetStatus(2026, 11))!.overAllocated, isTrue);
    await r.setBudgetSplit('cat_transport', null);
    expect((await r.budgetStatus(2026, 11))!.overAllocated, isFalse);
    expect((await r.budgetSplits()).keys, ['cat_food']);
  });

  test('safe per day, projection and days left', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    await r.setBudget(3000000);
    await spend(r, 600000, 'cat_food_groceries', day: 1);
    final s = (await r.budgetStatus(2026, 11))!;
    expect(s.daysElapsed, 4);
    expect(s.daysLeft, 26);
    expect(s.safePerDay, (2400000 / 26).floor());
    expect(s.projected, (600000 * 30 / 4).round()); // 4,50,000
  });

  test(
    'finished months are frozen: later budget edits do not rewrite them',
    () async {
      final e = await newEnv(opening: 10000000);
      final r = e.repo;
      // budget began in October
      e.clockNow = DateTime(2026, 10, 10, 10);
      await r.setBudget(1000000);
      await r.addTransaction(
        type: 'debit',
        amountMinor: 900000,
        categoryId: 'cat_food_groceries',
        date: Dates.day(2026, 10, 5),
      );
      e.clockNow = DateTime(2026, 11, 4, 10);
      var h = await r.budgetHistory();
      expect(h.single.month, '2026-10');
      expect(h.single.state, BudgetState.under);
      await r.setBudget(500000); // would make October "over" if recomputed
      h = await r.budgetHistory();
      expect(h.single.budget, 1000000);
      expect(h.single.state, BudgetState.under);
    },
  );

  test('history starts when the budget was first set', () async {
    final e = await newEnv();
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 5000,
      date: Dates.day(2026, 9, 5),
    );
    await e.repo.setBudget(100000); // set in November
    expect(await e.repo.budgetHistory(), isEmpty);
  });

  test('headline wording covers all three states in both tones', () {
    BudgetStatus st(int spent) => BudgetStatus(
      year: 2026,
      month: 11,
      budget: 100000,
      spent: spent,
      monthOnly: false,
      splits: const [],
      daysInMonth: 30,
      daysElapsed: 30,
    );
    for (final spent in [50000, 100000, 150000]) {
      for (final roast in [true, false]) {
        final t = budgetHeadline(st(spent), roast: roast);
        expect(t, isNotEmpty);
        expect(t.contains('\$'), isFalse);
      }
    }
    expect(budgetHeadline(st(100000), roast: false), contains('Exactly'));
  });

  test(
    'a budget saved by an older version moves into the synced table once',
    () async {
      final e = await newEnv();
      final r = e.repo;
      await r.setSetting('budgetMinor', '2500000');
      await r.setSetting('budget_2026-12', '3000000');
      await r.setSetting('budgetSplit', '{"cat_food": 500000}');
      await r.setSetting('budgetSince', '2026-10');
      await r.setSetting('budgetResult_2026-10', '2500000|2100000');
      await r.migrateBudgetSettings();
      expect(await r.budgetFor(2026, 11), 2500000);
      expect(await r.budgetFor(2026, 12), 3000000);
      expect(await r.budgetSplits(), {'cat_food': 500000});
      final h = await r.budgetHistory();
      expect(h.single.month, '2026-10');
      expect(h.single.spent, 2100000);
      // running it again changes nothing
      await r.setBudget(1, month: DateTime(2027, 1));
      await r.migrateBudgetSettings();
      expect(await r.budgetFor(2027, 1), 1);
    },
  );

  test('daily series is cumulative and stops today', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    await spend(r, 100000, 'cat_food_groceries', day: 1);
    await spend(r, 50000, 'cat_food_groceries', day: 3);
    final d = await r.budgetDaily(2026, 11);
    expect(d, [100000, 100000, 150000, 150000]); // 4 days elapsed (clock 4 Nov)
  });

  test('year view: months before the budget have no budget, finished ones are frozen', () async {
    final e = await newEnv(opening: 10000000);
    final r = e.repo;
    e.clockNow = DateTime(2026, 9, 10, 10);
    await r.setBudget(1000000);
    await r.addTransaction(
      type: 'debit',
      amountMinor: 1500000,
      categoryId: 'cat_food_groceries',
      date: Dates.day(2026, 9, 5),
    );
    e.clockNow = DateTime(2026, 11, 4, 10);
    await r.addTransaction(
      type: 'debit',
      amountMinor: 300000,
      categoryId: 'cat_food_groceries',
      date: Dates.day(2026, 11, 2),
    );
    final y = await r.budgetYear(2026);
    expect(y.length, 12);
    expect(y[7].budget, isNull); // August: before the budget began
    expect(y[8].budget, 1000000); // September: finished, frozen
    expect(y[8].spent, 1500000);
    expect(y[8].state, BudgetState.over);
    expect(y[10].current, isTrue); // November
    expect(y[10].spent, 300000);
    expect(y[10].state, BudgetState.under);
    expect(y[11].future, isTrue);
    expect(y[11].state, isNull);
  });

  group('budget by category', () {
    test(
      'total is the sum of the categories and repeats every month',
      () async {
        final e = await newEnv();
        expect(await e.repo.budgetMode(), 'overall');
        await e.repo.saveCategoryBudget({
          'cat_food': 800000,
          'cat_transport': 200000,
          'cat_shopping': 0,
        });
        expect(await e.repo.budgetMode(), 'category');
        expect(await e.repo.budgetFor(2026, 11), 1000000);
        expect(await e.repo.budgetFor(2026, 12), 1000000);
        final st = await e.repo.budgetStatus(2026, 11);
        expect(st!.budget, 1000000);
        expect(st.monthOnly, isFalse);
      },
    );

    test('only this month: other months keep the repeating amounts', () async {
      final e = await newEnv();
      await e.repo.saveCategoryBudget({'cat_food': 800000});
      await e.repo.saveCategoryBudget({
        'cat_food': 500000,
        'cat_transport': 100000,
      }, month: DateTime(2026, 11, 1));
      expect(await e.repo.budgetFor(2026, 11), 600000);
      expect(await e.repo.budgetFor(2026, 12), 800000);
      expect((await e.repo.budgetStatus(2026, 11))!.monthOnly, isTrue);
      expect((await e.repo.budgetStatus(2026, 12))!.monthOnly, isFalse);
    });

    test(
      'switching to overall keeps the current total as the amount',
      () async {
        final e = await newEnv();
        await e.repo.saveCategoryBudget({
          'cat_food': 800000,
          'cat_transport': 200000,
        });
        await e.repo.setBudgetMode('overall');
        expect(await e.repo.budgetMode(), 'overall');
        expect(await e.repo.budgetFor(2026, 11), 1000000);
      },
    );

    test('an old overall budget stays overall and unchanged', () async {
      final e = await newEnv();
      await e.repo.setBudget(3500000);
      expect(await e.repo.budgetMode(), 'overall');
      expect(await e.repo.budgetFor(2026, 11), 3500000);
    });

    test('needs at least one amount', () async {
      final e = await newEnv();
      expect(
        () => e.repo.saveCategoryBudget({'cat_food': 0}),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}

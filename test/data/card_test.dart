import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/data/insights_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// newEnv clock: 4 Nov 2026, one account holding the opening money
Future<(TestEnv, String, String)> env() async {
  final e = await newEnv(opening: 10000000); // ₹1,00,000
  final bank = (await e.repo.accounts()).first.id;
  final card = await e.repo.addCard(
    name: 'HDFC Regalia',
    last4: '1234',
    limitMinor: 20000000,
    dueDay: 25,
    interestBps: 350,
    graceDays: 0,
  );
  return (e, bank, card);
}

Future<void> swipe(Repo r, String card, int amt, {DateTime? date}) => r
    .addTransaction(
      type: 'debit',
      amountMinor: amt,
      accountId: card,
      categoryId: 'cat_food_dining',
      date: date,
    )
    .then((_) {});

void main() {
  test(
    'a card is kept apart from your accounts and your total balance',
    () async {
      final (e, bank, card) = await env();
      expect((await e.repo.accounts()).map((a) => a.id), isNot(contains(card)));
      expect((await e.repo.cards()).single.id, card);
      final before = await e.repo.totalBalance();
      await swipe(e.repo, card, 250000);
      expect(
        await e.repo.totalBalance(),
        before,
        reason: 'a swipe is not money out yet',
      );
      final s = (await e.repo.cardStatuses()).single;
      expect(s.owed, 250000);
      expect(s.used, closeTo(0.0125, 1e-9));
      expect((await e.repo.balances())[bank], 10000000);
    },
  );

  test(
    'paying the bill reduces your balance and clears what is owed',
    () async {
      final (e, bank, card) = await env();
      await swipe(e.repo, card, 250000);
      await e.repo.payCardBill(
        cardId: card,
        amountMinor: 250000,
        fromAccountId: bank,
      );
      expect(await e.repo.totalBalance(), 10000000 - 250000);
      expect((await e.repo.cardStatuses()).single.owed, 0);
    },
  );

  test('a part payment leaves the rest owed', () async {
    final (e, bank, card) = await env();
    await swipe(e.repo, card, 250000);
    await e.repo.payCardBill(
      cardId: card,
      amountMinor: 100000,
      fromAccountId: bank,
    );
    expect((await e.repo.cardStatuses()).single.owed, 150000);
    expect(await e.repo.totalBalance(), 10000000 - 100000);
  });

  test(
    'paying more than owed records the extra as interest spending',
    () async {
      final (e, bank, card) = await env();
      await swipe(e.repo, card, 250000);
      await e.repo.payCardBill(
        cardId: card,
        amountMinor: 262000,
        fromAccountId: bank,
      );
      final s = (await e.repo.cardStatuses()).single;
      expect(s.owed, 0, reason: 'the card never goes into credit');
      expect(await e.repo.totalBalance(), 10000000 - 262000);
      final extra = (await e.repo.searchTransactions(const TxnFilter()))
          .where((t) => t.categoryId == 'cat_interest_paid')
          .toList();
      expect(extra.single.amountMinor, 12000);
    },
  );

  test('a refund to the card lowers what is owed', () async {
    final (e, _, card) = await env();
    await swipe(e.repo, card, 250000);
    await e.repo.addTransaction(
      type: 'credit',
      amountMinor: 50000,
      accountId: card,
    );
    expect((await e.repo.cardStatuses()).single.owed, 200000);
  });

  test('an amount already owed when the card is added', () async {
    final e = await newEnv(opening: 1000000);
    await e.repo.addCard(name: 'Old', owedMinor: 700000, dueDay: 10);
    expect((await e.repo.cardStatuses()).single.owed, 700000);
    expect(await e.repo.totalBalance(), 1000000);
  });

  group('budget', () {
    Future<void> setup(TestEnv e) => e.repo.setBudget(5000000);

    test(
      'default: card spends wait, the payment counts in the month paid',
      () async {
        final (e, bank, card) = await env();
        await setup(e);
        await e.repo.addTransaction(
          type: 'debit',
          amountMinor: 100000,
          accountId: bank,
          categoryId: 'cat_food_dining',
        );
        await swipe(e.repo, card, 300000);
        expect((await e.repo.budgetStatus(2026, 11))!.spent, 100000);
        await e.repo.payCardBill(
          cardId: card,
          amountMinor: 300000,
          fromAccountId: bank,
        );
        expect((await e.repo.budgetStatus(2026, 11))!.spent, 400000);
        expect((await e.repo.budgetDaily(2026, 11)).last, 400000);
      },
    );

    test('swipe mode: card spends count at once and the payment does not count again', () async {
      final (e, bank, card) = await env();
      await setup(e);
      await e.repo.setCardBudgetMode('swipe');
      await swipe(e.repo, card, 300000);
      expect((await e.repo.budgetStatus(2026, 11))!.spent, 300000);
      await e.repo.payCardBill(
        cardId: card,
        amountMinor: 300000,
        fromAccountId: bank,
      );
      expect((await e.repo.budgetStatus(2026, 11))!.spent, 300000);
    });

    test('the warning says what the budget would be after the bills', () async {
      final (e, _, card) = await env();
      await setup(e);
      await swipe(e.repo, card, 1200000, date: Dates.day(2026, 11, 2));
      final w = (await e.repo.cardWarning())!;
      expect(w.due, 1200000); // due on the 25th, this month
      expect(w.left, 5000000);
      expect(w.after, 3800000);
    });

    test(
      'no warning in swipe mode, without a budget, or when nothing is due',
      () async {
        final (e, _, card) = await env();
        expect(await e.repo.cardWarning(), isNull); // no budget
        await setup(e);
        expect(await e.repo.cardWarning(), isNull); // nothing owed
        await swipe(e.repo, card, 100000);
        await e.repo.setCardBudgetMode('swipe');
        expect(await e.repo.cardWarning(), isNull);
      },
    );
  });

  test(
    'card spends count as spending in the analysis, the payment does not',
    () async {
      final (e, bank, card) = await env();
      await swipe(e.repo, card, 300000);
      await e.repo.payCardBill(
        cardId: card,
        amountMinor: 300000,
        fromAccountId: bank,
      );
      final s = await e.repo.monthStats(2026, 11);
      expect(s.spending, 300000, reason: 'counted once, at the swipe');
    },
  );

  test('interest is estimated from the bill that was due', () async {
    final (e, _, card) = await env();
    // spent before the 25 Oct due date, still unpaid on 4 Nov (10 days late)
    await swipe(e.repo, card, 1000000, date: Dates.day(2026, 10, 10));
    // a new spend after the due date does not attract interest yet
    await swipe(e.repo, card, 500000, date: Dates.day(2026, 11, 1));
    final s = (await e.repo.cardStatuses()).single;
    expect(s.owed, 1500000);
    expect(s.interest, 11667);
    expect(s.overdue, isTrue);
    expect(s.toPay, 1511667);
    // paying the old bill stops the interest
    final bank = (await e.repo.accounts()).first.id;
    await e.repo.payCardBill(
      cardId: card,
      amountMinor: 1000000,
      fromAccountId: bank,
    );
    final after = (await e.repo.cardStatuses()).single;
    expect(after.interest, 0);
    expect(after.owed, 500000);
  });

  test('a bank alert with the card digits goes to that card', () async {
    final (e, bank, card) = await env();
    expect((await e.repo.accountForSms('1234'))!.id, card);
    expect((await e.repo.accountForSms('9999'))!.id, bank);
    expect((await e.repo.accountForSms(null))!.id, bank);
  });

  test('card input is checked', () async {
    final e = await newEnv();
    expect(
      () => e.repo.addCard(name: ' '),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => e.repo.addCard(name: 'x', dueDay: 32),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => e.repo.payCardBill(cardId: 'x', amountMinor: 0, fromAccountId: 'y'),
      throwsA(isA<ValidationException>()),
    );
  });
}

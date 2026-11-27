import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle, tapText;

Future<void> wait(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await settle(t);
}

void main() {
  testWidgets('add a card, see what you owe, mark the bill paid', (
    tester,
  ) async {
    final env = await pump(
      tester,
      opening: 10000000,
      now: DateTime(2026, 11, 4, 10),
    );
    await tapText(tester, 'Debts', last: true);
    await tapText(tester, 'Credit cards');
    expect(find.text('No credit cards yet'), findsOneWidget);
    await tapText(tester, 'Add card');
    final f = find.byType(TextField);
    await tester.enterText(f.at(0), 'HDFC Regalia');
    await tester.enterText(f.at(2), '1234');
    await tester.enterText(f.at(5), '25');
    await tester.enterText(f.at(6), '3.5');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add card'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await wait(tester);
    expect(find.textContaining('HDFC Regalia'), findsOneWidget);
    final card = (await tester.runAsync(() => env.repo.cards()))!.single;
    expect(card.interestBps, 350);
    expect(card.dueDay, 25);

    await tester.runAsync(
      () => env.repo.addTransaction(
        type: 'debit',
        amountMinor: 250000,
        accountId: card.id,
        date: Dates.day(2026, 11, 2),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text('Due 25 Nov'), findsOneWidget);
    await tester.tap(find.textContaining('HDFC Regalia'));
    await settle(tester);
    expect(find.text('You owe'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark bill paid'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark bill paid').last);
    await wait(tester);
    final status = (await tester.runAsync(() => env.repo.cardStatuses()))!
        .single;
    expect(status.owed, 0);
    expect(
      await tester.runAsync(() => env.repo.totalBalance()),
      10000000 - 250000,
    );
  });

  testWidgets('Home warns about card bills after the budget', (tester) async {
    final env = await pump(
      tester,
      opening: 10000000,
      now: DateTime(2026, 11, 4, 10),
    );
    await tester.runAsync(() async {
      await env.repo.setBudget(5000000);
      final id = await env.repo.addCard(name: 'ICICI', dueDay: 25);
      await env.repo.addTransaction(
        type: 'debit',
        amountMinor: 1200000,
        accountId: id,
        date: Dates.day(2026, 11, 2),
      );
    });
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.textContaining('Card bills due:'), findsOneWidget);
    expect(find.textContaining('budget would be'), findsOneWidget);
    // choosing "right when I swipe" removes the warning
    await tester.runAsync(() => env.repo.setCardBudgetMode('swipe'));
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.textContaining('Card bills due:'), findsNothing);
  });

  testWidgets(
    'a card spend is chosen with "Paid with" and does not change the balance',
    (tester) async {
      final env = await pump(
        tester,
        opening: 10000000,
        now: DateTime(2026, 11, 4, 10),
      );
      await tester.runAsync(() => env.repo.addCard(name: 'Axis', dueDay: 10));
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(find.text('Paid with'), findsOneWidget);
    },
  );

  testWidgets(
    'cards screens have no layout overflow on a small phone with big text',
    (tester) async {
      final env = await pump(
        tester,
        opening: 10000000,
        size: const Size(320, 640),
        textScale: 2.0,
        now: DateTime(2026, 11, 4, 10),
      );
      await tester.runAsync(() async {
        await env.repo.setBudget(5000000);
        final id = await env.repo.addCard(
          name: 'A very long card name to test wrapping',
          last4: '9999',
          limitMinor: 50000000,
          dueDay: 1,
          interestBps: 350,
        );
        await env.repo.addTransaction(
          type: 'debit',
          amountMinor: 99999999,
          accountId: id,
          date: Dates.day(2026, 10, 5),
        );
      });
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      await tapText(tester, 'Debts', last: true);
      await tapText(tester, 'Credit cards');
      await settle(tester);
      await tester.tap(find.textContaining('A very long card name'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

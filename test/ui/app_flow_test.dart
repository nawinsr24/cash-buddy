import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

Future<TestEnv> pump(
  WidgetTester tester, {
  bool onboarded = true,
  String accountMode = 'combined',
  int opening = 0,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Brightness? brightness,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  if (brightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  late TestEnv env;
  await tester.runAsync(() async {
    env = await newEnv(
      accountMode: accountMode,
      opening: opening,
      now: DateTime.now(),
    );
    if (!onboarded) {
      await env.db.delete(env.db.settings).go();
      await env.db.delete(env.db.accounts).go();
      await env.db.delete(env.db.categories).go();
    }
  });
  addTearDown(() => tester.runAsync(() => env.db.close()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repoProvider.overrideWithValue(env.repo)],
      child: const CashBuddyApp(),
    ),
  );
  await settle(tester);
  return env;
}

/// Drift streams resolve on real async, so give the event loop a turn.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'expected to find "$text"');
  await tester.tap(last ? f.last : f.first, warnIfMissed: false);
  await settle(tester);
}

void main() {
  testWidgets(
    'onboarding: explicit choices, then lands on dashboard with opening balance',
    (tester) async {
      await pump(tester, onboarded: false);
      expect(find.text('Where should your data live?'), findsOneWidget);
      // Continue is disabled until a choice is made (nothing silently pre-selected)
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tapText(tester, 'Offline Mode');
      await tapText(tester, 'Continue');
      expect(find.text('How do you track your money?'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tapText(tester, 'Combined account');
      await tapText(tester, 'Continue');
      expect(find.text('Cash vs card?'), findsOneWidget);
      await tapText(tester, 'Continue');
      await tester.enterText(find.byType(TextField).first, '5000');
      await tapText(tester, 'Start using Cash Buddy');
      expect(find.text('Total balance'), findsOneWidget);
      expect(find.text('₹5,000.00'), findsWidgets);
    },
  );

  testWidgets('dashboard shows the four pillars and defaults to This month', (
    tester,
  ) async {
    await pump(tester, opening: 100000);
    for (final t in [
      'Total Spending',
      'Total Income',
      'Incoming Debts',
      'Liabilities',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'This month'),
    );
    expect(chip.selected, isTrue);
    expect(find.text('₹1,000.00'), findsWidgets);
  });

  testWidgets('adding a transaction updates balance and Total Spending', (
    tester,
  ) async {
    final env = await pump(tester, opening: 100000);
    await tapText(tester, 'Add');
    await tester.enterText(find.byType(TextField).first, '250.50');
    await tapText(tester, 'Add', last: true);
    await settle(tester);
    expect(find.text('₹749.50'), findsWidgets); // balance 1000 - 250.50
    expect(find.text('₹250.50'), findsWidgets); // spending pillar
    final bal = await tester.runAsync(() => env.repo.totalBalance());
    expect(bal, 74950);
  });

  testWidgets('invalid amount is rejected with a message', (tester) async {
    await pump(tester);
    await tapText(tester, 'Add');
    await tapText(tester, 'Add', last: true);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('transactions tab: search filters the list', (tester) async {
    final env = await pump(tester);
    await tester.runAsync(() async {
      await env.repo.addTransaction(
        type: 'debit',
        amountMinor: 1200,
        merchant: 'PVR Cinemas',
        note: 'movie night',
      );
      await env.repo.addTransaction(
        type: 'debit',
        amountMinor: 800,
        merchant: 'Starbucks',
        note: 'coffee',
      );
    });
    await tapText(tester, 'Activity', last: true);
    expect(find.text('movie night'), findsOneWidget);
    expect(find.text('coffee'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'pvr');
    await settle(tester);
    expect(find.text('movie night'), findsOneWidget);
    expect(find.text('coffee'), findsNothing);
  });

  testWidgets(
    'debts: lend, then record a partial payment from the detail screen',
    (tester) async {
      final env = await pump(tester, opening: 1000000);
      late String id;
      await tester.runAsync(() async {
        id = await env.repo.createDebt(
          direction: 'receivable',
          counterparty: 'Ravi',
          principalMinor: 200000,
          issuedOn: Dates.today(),
        );
      });
      await tapText(tester, 'Debts', last: true);
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.text('₹2,000.00'), findsWidgets);
      await tapText(tester, 'Ravi');
      await tapText(tester, 'Record payment received');
      await tester.enterText(find.byType(TextField).first, '500');
      await tapText(tester, 'Save');
      await settle(tester);
      final st = await tester.runAsync(() => env.repo.debtState(id));
      expect(st!.outstanding, 150000);
      expect(find.text('₹1,500.00'), findsWidgets);
      // overpayment shows an error and changes nothing
      await tapText(tester, 'Record payment received');
      await tester.enterText(find.byType(TextField).first, '9999');
      await tapText(tester, 'Save');
      expect(find.textContaining('more than is outstanding'), findsOneWidget);
      expect(
        (await tester.runAsync(() => env.repo.debtState(id)))!.outstanding,
        150000,
      );
    },
  );

  testWidgets('SMS inbox: confirm adds the transaction, discard does not', (
    tester,
  ) async {
    final env = await pump(tester, opening: 100000);
    await tester.runAsync(() async {
      await env.repo.setSetting('smsEnabled', '1');
      await env.repo.ingestSms([
        (
          sender: 'VM-HDFCBK',
          body: 'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
          receivedAt: DateTime.now(),
        ),
        (
          sender: 'VM-HDFCBK',
          body: 'Rs.70.00 debited from a/c XX1234 on 03-11-26 at UBER. Ref 9000022222',
          receivedAt: DateTime.now(),
        ),
      ], SmsParser());
    });
    await settle(tester);
    expect(
      find.textContaining('2 detected transactions to review'),
      findsOneWidget,
    );
    await tapText(tester, 'Inbox', last: true);
    expect(find.text('SWIGGY'), findsOneWidget);
    await tester.tap(find.text('Review & add').first, warnIfMissed: false);
    await settle(tester);
    // the form opens pre-filled; nothing is added until the user saves
    expect(find.text('Review detected transaction'), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => env.repo.searchTransactions(const TxnFilter()),
      ))!.length,
      0,
    );
    await tapText(tester, 'Add transaction');
    await settle(tester);
    await tester.tap(find.text('Discard').first, warnIfMissed: false);
    await settle(tester);
    final txns = await tester.runAsync(
      () => env.repo.searchTransactions(const TxnFilter()),
    );
    expect(txns!.length, 1);
    expect(await tester.runAsync(() => env.repo.pendingSmsCount()), 0);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('settings: switch to split accounts keeps total balance', (
    tester,
  ) async {
    final env = await pump(tester, opening: 250000);
    await tapText(tester, 'Settings', last: true);
    expect(find.text('Combined account'), findsOneWidget);
    await tester.tap(
      find.byType(Switch).at(1),
      warnIfMissed: false,
    ); // account mode switch
    await settle(tester);
    expect(find.text('Split accounts'), findsOneWidget);
    expect(await tester.runAsync(() => env.repo.totalBalance()), 250000);
  });

  testWidgets('follows system dark mode live', (tester) async {
    await pump(tester, brightness: Brightness.dark);
    final ctx = tester.element(find.text('Total balance'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let AnimatedTheme finish
    expect(
      Theme.of(tester.element(find.text('Total balance'))).brightness,
      Brightness.light,
    );
  });

  for (final c in [
    ('small phone + 2x text', const Size(320, 568), 2.0),
    ('large phone + 1.3x text', const Size(430, 932), 1.3),
    ('tablet', const Size(820, 1180), 1.0),
  ]) {
    testWidgets('no layout overflow: ${c.$1}', (tester) async {
      final env = await pump(
        tester,
        size: c.$2,
        textScale: c.$3,
        opening: 123456789,
      );
      await tester.runAsync(() async {
        await env.repo.addTransaction(
          type: 'debit',
          amountMinor: 98765432,
          categoryId: 'cat_entertainment_movies',
          note: 'A very long note that should truncate nicely without overflowing anything',
        );
        await env.repo.createDebt(
          direction: 'liability',
          counterparty: 'Someone With A Rather Long Name',
          principalMinor: 5000000,
          issuedOn: Dates.today(),
        );
      });
      await settle(tester);
      expect(tester.takeException(), isNull);
      for (final tab in ['Activity', 'Debts', 'Settings', 'Home']) {
        await tapText(tester, tab, last: true);
        expect(tester.takeException(), isNull, reason: 'overflow on $tab');
      }
      await tapText(tester, 'Home', last: true);
      await tester.scrollUntilVisible(
        find.text('Total Spending'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(tester, 'Total Spending');
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow on spending detail',
      );
    });
  }

  testWidgets('semantics: pillars are announced with value and are tappable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final env = await pump(tester);
    await tester.runAsync(
      () => env.repo.addTransaction(type: 'debit', amountMinor: 12300),
    );
    await settle(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Total Spending ₹123\.00.*Tap for details'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}

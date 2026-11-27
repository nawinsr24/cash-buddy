import 'package:cash_buddy/domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle, tapText;

void main() {
  tearDown(Money.configure);

  testWidgets('the currency starts as the Indian rupee, even on a US phone', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await pump(tester, onboarded: false);
    expect(find.textContaining('Indian Rupee'), findsOneWidget);
    expect(Money.code, 'INR');
    // there is no tone question anywhere in setup
    expect(find.textContaining('talk to you'), findsNothing);
  });

  testWidgets('first-run budget step: By category lists the categories', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await pump(tester, onboarded: false);
    await tapText(tester, 'Continue'); // language and currency
    await tapText(tester, 'Keep on this phone only');
    await tapText(tester, 'Continue');
    await tapText(tester, 'One balance');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue'); // bank alerts
    await tapText(tester, 'Continue'); // balance
    await tapText(tester, 'Skip'); // reminder -> budget
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle(tester);
    await tapText(tester, 'By category');
    await settle(tester);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Home & Kitchen'), findsOneWidget);
    expect(find.text('Personal Care'), findsOneWidget);
    expect(find.text('Kids'), findsOneWidget);
  });

  testWidgets('Debts opens on Credit cards first', (tester) async {
    await pump(tester);
    await tapText(tester, 'Debts', last: true);
    expect(find.text('No credit cards yet'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add card'),
      findsOneWidget,
    );
  });
}

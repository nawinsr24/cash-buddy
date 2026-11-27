import 'package:cash_buddy/data/loan_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle, tapText;
import 'cards_test.dart' show wait;

void main() {
  testWidgets('add a loan, pay an EMI, look at preclosing', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await pump(tester, opening: 100000000);
    Future<void> press(Finder f) async {
      await tester.ensureVisible(f);
      await settle(tester);
      await tester.tap(f);
      await wait(tester);
    }

    await tapText(tester, 'Debts', last: true);
    await tapText(tester, 'Liabilities');
    await press(find.text('Add EMI loan'));
    for (final (field, text) in [
      ('Lender', 'HDFC'),
      ('Amount still outstanding', '500000'),
      ('Yearly interest rate %', '9'),
      ('Months left', '60'),
      ('EMI day of month', '5'),
    ]) {
      final f = find.byKey(ValueKey(field));
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await settle(tester);
    }
    expect(find.textContaining('10,379.18'), findsOneWidget);
    await press(find.widgetWithText(FilledButton, 'Save'));
    final loan = (await tester.runAsync(() => env.repo.loanStatuses()))!.single;
    expect(loan.emi, 1037918);

    await tester.pump(const Duration(seconds: 2));
    await press(find.text('HDFC'));
    await press(find.widgetWithText(FilledButton, 'EMI paid'));
    await press(find.widgetWithText(FilledButton, 'Record payment'));
    final paid = (await tester.runAsync(() => env.repo.loanStatuses()))!.single;
    expect(paid.owed, 49337082);

    await tester.pump(const Duration(seconds: 2));
    await press(find.text('Preclose'));
    expect(find.text('Total to pay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

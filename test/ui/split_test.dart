import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle, tapText;
import 'cards_test.dart' show wait;

void main() {
  testWidgets('split a bill from Add, see it in Receivables', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await pump(tester, opening: 500000);
    await tapText(tester, 'Add');
    final toggle = find.text('Split with others');
    await tester.ensureVisible(toggle);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(toggle);
    await settle(tester);
    final name = find.byKey(const ValueKey('split-name-0'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Ravi');
    await settle(tester);
    expect(find.textContaining('Ravi ₹500'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Add');
    await tester.ensureVisible(save);
    await settle(tester);
    await tester.tap(save);
    await wait(tester);
    final debts = (await tester.runAsync(() => env.repo.debts()))!;
    expect(debts.single.counterparty, 'Ravi');
    expect(debts.single.principalMinor, 50000);
    expect(await tester.runAsync(() => env.repo.totalBalance()), 400000);
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Debts', last: true);
    await tapText(tester, 'Receivables');
    expect(find.text('Split expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

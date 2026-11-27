import 'package:cash_buddy/data/budget_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle;
import 'cards_test.dart' show wait;

void main() {
  testWidgets('Home shows today and explains it', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await pump(tester, opening: 10000000);
    expect(find.text('Safe to spend today'), findsNothing);
    await tester.runAsync(() => env.repo.setBudget(3000000));
    await tester.pump(const Duration(seconds: 2));
    await wait(tester);
    await tester.tap(find.text('Safe to spend today'));
    await settle(tester);
    expect(find.text('How this is worked out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/features/shell.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle;

void main() {
  testWidgets('a database write must not rebuild the whole app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late TestEnv env;
    await tester.runAsync(() async => env = await newEnv());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repoProvider.overrideWithValue(env.repo)],
        child: const CashBuddyApp(),
      ),
    );
    await settle(tester);
    final before = tester.state<ShellState>(find.byType(Shell));
    var spinners = 0;
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => env.repo.setSetting('x', '$i'));
      // look at every frame while the settings reload
      for (var f = 0; f < 6; f++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(Shell).evaluate().isEmpty) spinners++;
      }
    }
    final after = tester.state<ShellState>(find.byType(Shell));
    // ignore: avoid_print
    print(
      'frames without the app: $spinners, same Shell: ${identical(before, after)}',
    );
    expect(identical(before, after), isTrue, reason: 'Shell was recreated');
    expect(spinners, 0, reason: 'the whole app was replaced by a spinner');
  });
}

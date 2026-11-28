import 'package:cash_buddy/features/access_gate.dart';
import 'package:cash_buddy/platform/access.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle, tapText;

void main() {
  testWidgets('a saved block shows the blocked screen', (tester) async {
    late TestEnv env;
    await tester.runAsync(() async {
      env = await newEnv();
      await env.repo.setSetting('accessBlocked', '1');
    });
    addTearDown(() => tester.runAsync(() => env.db.close()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          accessProvider.overrideWithValue(
            Access(
              env.repo,
              config: const AccessConfig('https://example.test', 'AAAA'),
              fetch: (_) async => throw Exception('offline'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const AccessGate(child: Text('the app')),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Access has been turned off'), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('nothing is sent until the box is ticked', (tester) async {
    late TestEnv env;
    await tester.runAsync(() async => env = await newEnv());
    addTearDown(() => tester.runAsync(() => env.db.close()));
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          accessProvider.overrideWithValue(
            Access(
              env.repo,
              config: const AccessConfig('https://example.test', 'AAAA'),
              fetch: (_) async {
                calls++;
                throw Exception('offline');
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const AccessGate(child: Text('the app')),
        ),
      ),
    );
    await settle(tester);
    expect(calls, 0);
    // the button does nothing without the tick
    await tapText(tester, 'Continue');
    expect(calls, 0);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tapText(tester, 'Continue');
    expect(find.text('the app'), findsOneWidget);
    expect(calls, 1);
  });
}

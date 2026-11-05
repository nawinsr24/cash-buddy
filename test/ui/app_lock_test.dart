import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/platform/app_lock.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle;

class FakeAuth implements Authenticator {
  bool result = false;
  int calls = 0;
  @override
  Future<bool> get available async => true;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}

void main() {
  testWidgets(
    'app lock: content hidden until authenticated; wrong auth keeps it locked',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final auth = FakeAuth();
      late TestEnv env;
      await tester.runAsync(() async {
        env = await newEnv(opening: 12345);
        await env.repo.setSetting('appLock', '1');
      });
      addTearDown(() => tester.runAsync(() => env.db.close()));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(env.repo),
            authenticatorProvider.overrideWithValue(auth),
          ],
          child: const CashBuddyApp(),
        ),
      );
      await settle(tester);
      expect(find.text('Cash++ is locked'), findsOneWidget);
      expect(
        find.text('TOTAL BALANCE'),
        findsNothing,
      ); // nothing leaks behind the lock
      expect(auth.calls, greaterThan(0));
      // failed auth: still locked
      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(find.text('Cash++ is locked'), findsOneWidget);
      // successful auth: unlocked
      auth.result = true;
      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
    },
  );

  testWidgets('app lock off: no prompt, straight to the app', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final auth = FakeAuth();
    late TestEnv env;
    await tester.runAsync(() async => env = await newEnv());
    addTearDown(() => tester.runAsync(() => env.db.close()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          authenticatorProvider.overrideWithValue(auth),
        ],
        child: const CashBuddyApp(),
      ),
    );
    await settle(tester);
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(auth.calls, 0);
  });
}

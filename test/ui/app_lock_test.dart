import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/platform/app_lock.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle;

class FakeAuth extends Authenticator {
  bool result = false;
  bool throwOnce = false; // like local_auth 3: a cancel can throw
  int calls = 0;
  int stops = 0;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<bool> get available async => true;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    if (throwOnce) {
      throwOnce = false;
      throw StateError('user cancelled');
    }
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

  testWidgets('cancelling the prompt never leaves a dead Unlock button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final auth = FakeAuth()..throwOnce = true; // first prompt: cancelled/throws
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
    final first = auth.calls;
    // the automatic prompt asked once and does not loop
    await settle(tester);
    expect(auth.calls, first);
    // Unlock opens a fresh prompt, and a good answer unlocks
    auth.result = true;
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(auth.stops, greaterThan(0));
    expect(auth.calls, first + 1);
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
  });
}

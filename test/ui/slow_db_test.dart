import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/platform/app_lock.dart';
import 'package:cash_buddy/features/shell.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

/// A real phone's database answers a few milliseconds later than the
/// in-memory test one. That gap is enough to expose UI that swaps to a
/// spinner whenever settings reload.
class SlowRepo extends Repo {
  SlowRepo(Repo base) : super(base.db, base.clock, now: base.now);
  @override
  Future<String?> getSetting(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return super.getSetting(key);
  }
}

class _AllowAuth extends Authenticator {
  int calls = 0;
  @override
  Future<bool> get available async => true;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return true;
  }
}

void main() {
  testWidgets('a settings write on a slow database never tears the app down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late SlowRepo repo;
    late TestEnv env;
    await tester.runAsync(() async {
      env = await newEnv();
      repo = SlowRepo(env.repo);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repoProvider.overrideWithValue(repo)],
        child: const CashBuddyApp(),
      ),
    );
    // wait for the first load (each setting read is deliberately slow)
    for (var i = 0; i < 60 && find.byType(Shell).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    final before = tester.state<ShellState>(find.byType(Shell));
    var framesWithoutApp = 0;
    for (var w = 0; w < 4; w++) {
      await tester.runAsync(() => repo.setSetting('probe', '$w'));
      for (var f = 0; f < 12; f++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(Shell).evaluate().isEmpty) framesWithoutApp++;
      }
    }
    final after = tester.state<ShellState>(find.byType(Shell));
    // ignore: avoid_print
    print(
      'frames without the app: $framesWithoutApp, same Shell: ${identical(before, after)}',
    );
    expect(framesWithoutApp, 0, reason: 'the app was replaced by a spinner');
    expect(identical(before, after), isTrue, reason: 'Shell was recreated');
    // let the deliberately slow reads finish before the test ends
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets(
    'App lock: data changes on a slow database never lock the app again',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late SlowRepo repo;
      await tester.runAsync(() async {
        final env = await newEnv();
        await env.repo.setSetting('appLock', '1');
        repo = SlowRepo(env.repo);
      });
      final auth = _AllowAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(repo),
            authenticatorProvider.overrideWithValue(auth),
          ],
          child: const CashBuddyApp(),
        ),
      );
      for (var i = 0; i < 14; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(Shell), findsOneWidget); // unlocked once
      expect(auth.calls, 1);
      for (var w = 0; w < 6; w++) {
        await tester.runAsync(() => repo.setSetting('probe', '$w'));
        for (var f = 0; f < 10; f++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      expect(find.text('Cash++ is locked'), findsNothing);
      expect(auth.calls, 1, reason: 'asked for the password again');
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}

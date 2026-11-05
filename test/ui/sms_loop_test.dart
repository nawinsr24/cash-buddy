import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

/// Emulates the Android SMS channel and checks the app settles instead of
/// looping when the SMS assistant is on.
void main() {
  testWidgets('android + SMS on: the app settles (no scan / write loop)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String, int>{};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('cash_buddy/sms'),
      (call) async {
        calls[call.method] = (calls[call.method] ?? 0) + 1;
        switch (call.method) {
          case 'hasPermission':
          case 'requestPermission':
            return true;
          case 'readInbox':
            return [
              {
                'address': 'VM-HDFCBK',
                'body': 'Rs.500.00 debited from a/c XX1234 on 05-11-26 at SWIGGY. Ref 9000011111',
                'date': DateTime(2026, 11, 5, 9).millisecondsSinceEpoch,
              },
            ];
          default:
            return null;
        }
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('cash_buddy/sms'),
        null,
      ),
    );

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late TestEnv env;
    await tester.runAsync(() async {
      env = await newEnv(now: DateTime(2026, 11, 5, 10));
      await env.repo.setSetting('smsEnabled', '1');
    });
    var writes = 0;
    final sub = env.repo.changes.listen((_) => writes++);
    addTearDown(sub.cancel);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repoProvider.overrideWithValue(env.repo)],
        child: const CashBuddyApp(),
      ),
    );
    // let the first scan finish, then watch ~6 quiet seconds
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    final writesAfterStart = writes;
    final callsAfterStart = Map.of(calls);
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    // ignore: avoid_print
    print('after start: writes=$writesAfterStart calls=$callsAfterStart');
    // ignore: avoid_print
    print('after +6s:   writes=$writes calls=$calls');
    debugDefaultTargetPlatformOverride = null;
    expect(
      writes,
      writesAfterStart,
      reason: 'database keeps changing on its own',
    );
    expect(
      calls['readInbox'],
      callsAfterStart['readInbox'],
      reason: 'scanning on its own',
    );
    expect(calls['setSecure'], callsAfterStart['setSecure']);
  });
}

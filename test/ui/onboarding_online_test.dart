import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/drive_remote.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:cash_buddy/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cash_buddy/sync/vault.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show finishWizard, settle, tapText;

/// Fresh install: the Online choice must ask for Google sign-in right there.
Future<TestEnv> pumpFresh(WidgetTester tester, SignInFn signIn) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  late TestEnv env;
  late Vault vault;
  await tester.runAsync(() async {
    vault = await testVault();
    env = await newEnv(device: 'devB');
    await env.db.delete(env.db.settings).go();
    await env.db.delete(env.db.accounts).go();
    await env.db.delete(env.db.categories).go();
  });
  addTearDown(() => tester.runAsync(() => env.db.close()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(env.repo),
        syncServiceProvider.overrideWith((ref) {
          final s = SyncService(env.repo, signIn: signIn, vault: vault);
          ref.onDispose(s.dispose);
          return s;
        }),
      ],
      child: const CashBuddyApp(),
    ),
  );
  await settle(tester);
  await tapText(tester, 'Continue'); // language and currency
  return env;
}

void main() {
  testWidgets(
    'Online choice asks for Google sign-in at setup, then continues',
    (tester) async {
      final remote = InMemoryRemote();
      var asked = 0;
      final env = await pumpFresh(tester, () async {
        asked++;
        return (remote: remote, email: 'me@gmail.com');
      });
      await tapText(tester, 'Back up to Google Drive');
      expect(find.text('Continue with Google'), findsOneWidget);
      await tapText(tester, 'Continue with Google');
      await settle(tester);
      expect(asked, 1);
      expect(find.text('How do you track your money?'), findsOneWidget);
      await tapText(tester, 'One balance');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue'); // bank messages
      await tester.enterText(find.byType(TextField).first, '1000');
      await finishWizard(tester);
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(await tester.runAsync(() => env.repo.dataMode), 'online');
      expect(await tester.runAsync(() => env.repo.isOnboarded), isTrue);
      // the first sync went out
      expect(remote.files.keys.any((k) => k.startsWith('seg/')), isTrue);
    },
  );

  testWidgets(
    'failed or cancelled sign-in explains why and offers Offline Mode',
    (tester) async {
      final env = await pumpFresh(tester, () async {
        throw DriveSignInException('Google sign-in is not set up.');
      });
      await tapText(tester, 'Back up to Google Drive');
      await tapText(tester, 'Continue with Google');
      await settle(tester);
      expect(find.text('Could not sign in'), findsOneWidget);
      expect(find.text('Google sign-in is not set up.'), findsOneWidget);
      await tapText(tester, 'Keep on this phone');
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Where should your data live?'), findsOneWidget);
      // nothing was switched on behind the user's back
      expect(await tester.runAsync(() => env.repo.dataMode), 'offline');
    },
  );

  testWidgets('cancelling the Google screen keeps the user on the choice', (
    tester,
  ) async {
    await pumpFresh(tester, () async => null);
    await tapText(tester, 'Back up to Google Drive');
    await tapText(tester, 'Continue with Google');
    await settle(tester);
    expect(find.text('Could not sign in'), findsOneWidget);
    await tapText(tester, 'Try again');
    expect(find.text('Where should your data live?'), findsOneWidget);
  });

  testWidgets('existing Drive data can be restored, skipping the wizard', (
    tester,
  ) async {
    // another phone already saved data to Drive
    final remote = InMemoryRemote();
    late TestEnv a;
    await tester.runAsync(() async {
      a = await newEnv(device: 'devA', accountMode: 'split', opening: 500000);
      await a.repo.addTransaction(
        type: 'debit',
        amountMinor: 12300,
        note: 'restored coffee',
        accountId: 'acc_cash',
      );
      final r = await SyncEngine(a.repo, remote, 'devA').sync();
      expect(r.ok, isTrue);
    });
    addTearDown(() => tester.runAsync(() => a.db.close()));
    final env = await pumpFresh(
      tester,
      () async => (remote: remote, email: 'me@gmail.com'),
    );
    await tapText(tester, 'Back up to Google Drive');
    await tapText(tester, 'Continue with Google');
    await settle(tester);
    expect(find.text('Found your Cash++ data'), findsOneWidget);
    await tapText(tester, 'Restore');
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(await tester.runAsync(() => env.repo.isOnboarded), isTrue);
    expect(await tester.runAsync(() => env.repo.dataMode), 'online');
    expect(await tester.runAsync(() => env.repo.accountMode), 'split');
    expect(
      await tester.runAsync(() => env.repo.totalBalance()),
      500000 - 12300,
    );
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
  });

  testWidgets('"Start fresh" keeps the wizard going', (tester) async {
    final remote = InMemoryRemote();
    late TestEnv a;
    await tester.runAsync(() async {
      a = await newEnv(device: 'devA', opening: 1000);
      await SyncEngine(a.repo, remote, 'devA').sync();
    });
    addTearDown(() => tester.runAsync(() => a.db.close()));
    await pumpFresh(
      tester,
      () async => (remote: remote, email: 'me@gmail.com'),
    );
    await tapText(tester, 'Back up to Google Drive');
    await tapText(tester, 'Continue with Google');
    await settle(tester);
    await tapText(tester, 'Start fresh');
    expect(find.text('How do you track your money?'), findsOneWidget);
  });

  testWidgets('Offline Mode never asks for Google', (tester) async {
    var asked = 0;
    await pumpFresh(tester, () async {
      asked++;
      return null;
    });
    await tapText(tester, 'Keep on this phone only');
    await tapText(tester, 'Continue');
    expect(find.text('How do you track your money?'), findsOneWidget);
    expect(asked, 0);
  });
}

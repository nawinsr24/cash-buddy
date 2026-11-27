import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/features/account_tile.dart';
import 'package:cash_buddy/features/group.dart';
import 'package:cash_buddy/platform/access.dart';
import 'package:cash_buddy/platform/account.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle, tapText;
import 'cards_test.dart' show wait;

/// A server that accepts everything and has nothing waiting.
Future<(int, String)> _server(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
) async => (
  200,
  switch (url.pathSegments.last) {
    'fetch' || 'requests' => '[]',
    _ => '{}',
  },
);

void main() {
  testWidgets('create a group, set its budget, add and delete a spend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late TestEnv env;
    late GroupService service;
    await tester.runAsync(() async {
      env = await newEnv(opening: 1000000);
      await env.repo.setBudget(3000000);
      await env.repo.setSetting('accountEmail', 'a@example.com');
      await env.repo.setSetting('accountSession', '{}');
    });
    addTearDown(() => tester.runAsync(() => env.db.close()));
    service = GroupService(
      env.repo,
      secrets: MemorySecretStore(),
      server: Uri.parse('https://x.test/status'),
      send: _server,
    );
    final access = Access(
      env.repo,
      config: const AccessConfig('https://x.test/status', 'AAAA'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          accountProvider.overrideWithValue(Account(access)),
          groupServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const GroupPage(),
        ),
      ),
    );
    await wait(tester);

    await tapText(tester, 'Create a group');
    await tester.enterText(find.byType(TextField), 'Naveen');
    await tapText(tester, 'OK');
    await wait(tester);

    await tapText(tester, 'Tap to set a group budget');
    await tester.enterText(find.byType(TextField), '20000');
    await tapText(tester, 'OK');
    await wait(tester);
    expect(find.textContaining('left of'), findsOneWidget);

    await tapText(tester, 'Group spend');
    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await wait(tester);
    expect(find.text('Groceries'), findsOneWidget);

    // my share counts in my budget; my balance does not move
    var budget = await tester.runAsync(() => env.repo.budgetStatus(2026, 11));
    expect(budget!.spent, 150000);
    expect(await tester.runAsync(() => env.repo.totalBalance()), 1000000);

    await tapText(tester, 'Groceries');
    await tapText(tester, 'Delete');
    await wait(tester);
    expect(find.text('Deleted'), findsOneWidget);
    budget = await tester.runAsync(() => env.repo.budgetStatus(2026, 11));
    expect(budget!.spent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a server there is no group anywhere', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: GroupCard())),
      ),
    );
    expect(find.text('Shared group'), findsNothing);
  });
}

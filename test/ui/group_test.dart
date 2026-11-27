import 'package:cash_buddy/data/home_repo.dart';
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
import 'app_flow_test.dart' show tapText;
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
  testWidgets('starting home sharing', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late TestEnv env;
    late GroupService service;
    await tester.runAsync(() async {
      env = await newEnv(opening: 1000000);
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

    await tapText(tester, 'Start home sharing');
    await tester.enterText(find.byType(TextField), 'Naveen');
    await tapText(tester, 'OK');
    await wait(tester);
    expect(find.text('Naveen'), findsOneWidget);
    expect(find.text('Invite your partner'), findsOneWidget);
    expect(await tester.runAsync(() => env.repo.homeMember()), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a server there is no group anywhere', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: GroupCard())),
      ),
    );
    expect(find.text('Home sharing'), findsNothing);
  });
}

import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/home_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/features/group.dart';
import 'package:cash_buddy/features/home_budget.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle;
import 'cards_test.dart' show wait;

void main() {
  testWidgets('family budget with category amounts is saved for both', (
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
      env = await newEnv(opening: 100000);
      await env.repo.setSetting('accountSession', '{}');
      service = GroupService(
        env.repo,
        secrets: MemorySecretStore(),
        server: Uri.parse('https://x.test/'),
        send: (_, _, _, _) async => (200, '{}'),
      );
      await service.create('Naveen');
    });
    addTearDown(() => tester.runAsync(() => env.db.close()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          groupServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const HomeBudgetPage(),
        ),
      ),
    );
    await wait(tester);
    final food = find.byKey(const ValueKey('family-Food'));
    await tester.ensureVisible(food);
    await tester.enterText(food, '8000');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await wait(tester);
    final home = (await tester.runAsync(
      () => env.repo.homeSummary(DateRange.thisMonth(DateTime(2026, 11, 4))),
    ))!;
    // only categories given: the month is their sum
    expect(home.splits, {'Food': 800000});
    expect(home.budget, 800000);
    expect(tester.takeException(), isNull);
  });
}

import 'package:cash_buddy/features/account_tile.dart';
import 'package:cash_buddy/platform/access.dart';
import 'package:cash_buddy/platform/account.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle, tapText;

void main() {
  testWidgets('nothing is sent unless the user agrees', (tester) async {
    late TestEnv env;
    await tester.runAsync(() async => env = await newEnv());
    addTearDown(() => tester.runAsync(() => env.db.close()));
    var asked = 0;
    final account = Account(
      Access(env.repo, config: const AccessConfig('https://x.test', 'AAAA')),
      idToken: () async {
        asked++;
        return null;
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          accountProvider.overrideWithValue(account),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const Scaffold(body: AccountCard()),
        ),
      ),
    );
    await settle(tester);
    await tapText(tester, 'Sign in with Google');
    await tapText(tester, 'Continue'); // not ticked yet
    expect(asked, 0);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tapText(tester, 'Continue');
    expect(asked, 1);
    // once ticked, never asked again
    await tapText(tester, 'Sign in with Google');
    expect(find.byType(Checkbox), findsNothing);
    expect(asked, 2);
  });
}

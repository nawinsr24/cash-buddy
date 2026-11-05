import 'dart:io';

import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import '../screens/screenshots_test.dart' show loadFonts;
import 'app_flow_test.dart' show settle, tapText;

/// Text must stay readable in BOTH themes on the screens people look at most.
/// Uses Flutter's own WCAG contrast guideline on the rendered pixels.
void main() {
  // Pixel analysis depends on the machine's text rendering, so it is a local
  // check; theme_contrast_test.dart (exact colour pairs) runs everywhere.
  final onCi = Platform.environment['CI'] == 'true';
  for (final dark in [false, true]) {
    testWidgets(
      'contrast: key screens are readable in ${dark ? 'dark' : 'light'} mode',
      skip: onCi,
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.runAsync(loadFonts);
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        late TestEnv env;
        await tester.runAsync(() async {
          env = await newEnv(
            accountMode: 'split',
            opening: 8500000,
            now: DateTime(2026, 11, 5, 10),
          );
          await env.repo.addTransaction(
            type: 'debit',
            amountMinor: 245000,
            categoryId: 'cat_food_groceries',
            merchant: 'BigBasket',
          );
          await env.repo.addTransaction(
            type: 'debit',
            amountMinor: 320000,
            categoryId: 'cat_hobbies_cycling',
          );
          await env.repo.setBudget(3000000);
        });
        addTearDown(() => tester.runAsync(() => env.db.close()));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repoProvider.overrideWithValue(env.repo)],
            child: const CashBuddyApp(),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await settle(tester);
        }
        await tester.pump(const Duration(seconds: 2));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Home',
        );

        for (final tab in ['Activity', 'Debts', 'Invest', 'Settings']) {
          await tapText(tester, tab, last: true);
          await tester.pump(const Duration(seconds: 1));
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: tab,
          );
        }
        await tapText(tester, 'Home', last: true);
        await tester.pump(const Duration(seconds: 1));
        // Budget page
        await tapText(tester, 'BUDGET');
        await tester.pump(const Duration(seconds: 2));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Budget',
        );
        await tester.tap(find.byTooltip('Back'));
        await settle(tester);
        // Money Health page
        await tapText(tester, 'MONEY HEALTH');
        await tester.pump(const Duration(seconds: 2));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Money Health',
        );
        await tester.tap(find.byTooltip('Back'));
        await settle(tester);
        // Add sheet and the emoji category picker
        await tapText(tester, 'Add');
        await tester.pump(const Duration(seconds: 1));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Add sheet',
        );
        await tapText(tester, 'Uncategorised');
        await tester.pump(const Duration(seconds: 1));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Category picker',
        );
        handle.dispose();
      },
    );
  }
}

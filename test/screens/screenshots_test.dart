// Renders real screens to PNGs (build/screens/*.png) using the Roboto + Material
// Icons fonts from the Flutter SDK, so layout and design can be inspected
// without a simulator. Not a golden comparison: it just writes images.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:cash_buddy/features/settings.dart' show CategoriesPage;
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:cash_buddy/sync/sync_service.dart';
import 'package:cash_buddy/ui/art.dart';
import 'package:cash_buddy/ui/loaders.dart';
import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import '../ui/app_flow_test.dart' show settle, tapText;

Future<void> loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> b(String f) async =>
      ByteData.sublistView(await File('$dir/$f').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(b('Roboto-Regular.ttf'))
    ..addFont(b('Roboto-Medium.ttf'))
    ..addFont(b('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(b('MaterialIcons-Regular.otf'));
  await icons.load();
}

final _key = GlobalKey();

Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_key),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/screens/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  artGallery();
  loaderShot();
  for (final dark in [false, true]) {
    testWidgets('screens ${dark ? 'dark' : 'light'}', (tester) async {
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
      final now = DateTime(2026, 11, 5, 10);
      late TestEnv env;
      await tester.runAsync(() async {
        env = await newEnv(accountMode: 'split', opening: 8500000, now: now);
        final r = env.repo;
        await r.setSetting('smsEnabled', '1');
        final d = Dates.fromLocal(now);
        Future<void> t(
          String type,
          int amt,
          String cat,
          int ago,
          String note, {
          String? m,
          String? pm,
        }) => r
            .addTransaction(
              type: type,
              amountMinor: amt,
              categoryId: cat,
              date: d.subtract(Duration(days: ago)),
              note: note,
              merchant: m,
              paymentMethod: pm,
              accountId: pm == 'cash' ? 'acc_cash' : 'acc_bank',
            )
            .then((_) {});
        await t(
          'credit',
          9500000,
          'cat_salary',
          3,
          'October salary',
          m: 'DENOVO SYSTEMS',
        );
        await t('debit', 1850000, 'cat_bills_rent', 2, 'Rent', pm: 'card');
        await t(
          'debit',
          245000,
          'cat_food_groceries',
          1,
          'Weekly groceries',
          m: 'BigBasket',
          pm: 'card',
        );
        await t(
          'debit',
          85000,
          'cat_entertainment_movies',
          1,
          'Movie night',
          m: 'PVR',
          pm: 'card',
        );
        await t(
          'debit',
          32000,
          'cat_food_coffee',
          0,
          'Coffee',
          m: 'Starbucks',
          pm: 'cash',
        );
        await t('debit', 120000, 'cat_transport_fuel', 4, 'Petrol', pm: 'cash');
        await t(
          'debit',
          64900,
          'cat_entertainment_streaming',
          5,
          'Netflix',
          pm: 'card',
        );
        await t(
          'credit',
          150000,
          'cat_cash_received',
          6,
          'Cash from dad',
          pm: 'cash',
        );
        final a = await r.createDebt(
          direction: 'receivable',
          counterparty: 'Ravi Kumar',
          principalMinor: 2500000,
          issuedOn: d.subtract(const Duration(days: 100)),
          interestEnabled: true,
          rateBps: 150,
          accountId: 'acc_bank',
        );
        await r.addRepayment(
          a,
          500000,
          date: d.subtract(const Duration(days: 20)),
        );
        await r.createDebt(
          direction: 'receivable',
          counterparty: 'Meera',
          principalMinor: 800000,
          issuedOn: d.subtract(const Duration(days: 12)),
        );
        await r.createDebt(
          direction: 'liability',
          counterparty: 'HDFC Personal Loan',
          principalMinor: 6000000,
          issuedOn: d.subtract(const Duration(days: 200)),
          interestEnabled: true,
          rateBps: 100,
          interestType: 'compound',
          dueOn: d.add(const Duration(days: 30)),
          accountId: 'acc_bank',
        );
        final mf = await r.createInvestment(
          kind: 'mutual_fund',
          name: 'Nifty 50 Index Fund',
          sipMinor: 500000,
          expectedGrowthBps: 1200,
          currentValueMinor: 1620000,
        );
        for (var k = 0; k < 3; k++) {
          await r.addInvestmentEntry(
            mf,
            type: 'contribute',
            amountMinor: 500000,
            date: d.subtract(Duration(days: 60 - k * 28)),
          );
        }
        await r.createInvestment(
          kind: 'stock',
          name: 'TCS',
          units: 4,
          currentValueMinor: 1480000,
        );
        final chit = await r.createInvestment(
          kind: 'custom',
          name: 'Family Chit 2026',
          sipMinor: 800000,
          startDate: d.subtract(const Duration(days: 75)),
          recurring: true,
          cycle: 'monthly',
          installments: 12,
        );
        for (var k = 0; k < 2; k++) {
          await r.addInvestmentEntry(
            chit,
            type: 'contribute',
            amountMinor: 800000,
            periodKey: k,
            date: d.subtract(Duration(days: 75 - k * 30)),
          );
        }
        final weekly = await r.createInvestment(
          kind: 'custom',
          name: 'Gold savings',
          sipMinor: 50000,
          startDate: d.subtract(const Duration(days: 20)),
          recurring: true,
          cycle: 'weekly',
          weekday: 1,
        );
        await r.addInvestmentEntry(
          weekly,
          type: 'contribute',
          amountMinor: 50000,
          periodKey: 0,
        );
        // a monthly budget with splits; transport is over its split but the
        // overall budget still holds
        await r.setBudget(3000000);
        await r.setBudgetSplit('cat_food', 400000);
        await r.setBudgetSplit('cat_entertainment', 200000);
        await r.setBudgetSplit('cat_transport', 50000);
        await r.setBudgetSplit('cat_health', 100000);
        // the month before last, so the title comparison has something to compare
        await r.addTransaction(
          type: 'credit',
          amountMinor: 6500000,
          categoryId: 'cat_salary',
          date: Dates.day(2026, 9, 1),
          merchant: 'DENOVO SYSTEMS',
        );
        for (var i = 0; i < 12; i++) {
          await r.addTransaction(
            type: 'debit',
            amountMinor: 310000,
            categoryId: 'cat_food_dining',
            date: Dates.day(2026, 9, 2 + i * 2),
            merchant: 'Swiggy',
          );
        }
        // last month, so the monthly title and its banner have something to say
        await t(
          'credit',
          6500000,
          'cat_salary',
          33,
          'September salary',
          m: 'DENOVO SYSTEMS',
        );
        for (var i = 0; i < 12; i++) {
          await r.addTransaction(
            type: 'debit',
            amountMinor: i < 3 ? 180000 : 140000,
            categoryId: i < 3 ? 'cat_health' : 'cat_food_dining',
            date: Dates.day(2026, 10, 3 + i * 2),
            merchant: i < 3 ? 'Apollo Pharmacy' : 'Swiggy',
          );
        }
        await r.ingestSms([
          (
            sender: 'VM-HDFCBK',
            body:
                'Rs.1,299.00 debited from a/c XX1234 on ${d.day}-${d.month}-${d.year % 100} at AMAZON PAY. Ref 4093827123',
            receivedAt: now,
          ),
          (
            sender: 'AX-AXISBK',
            body:
                'INR 12000.00 credited to A/c XX9876 on ${d.day}-${d.month}-${d.year % 100} by UPI from RAHUL. Ref 7777777777',
            receivedAt: now,
          ),
        ], SmsParser());
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _key,
          child: ProviderScope(
            overrides: [repoProvider.overrideWithValue(env.repo)],
            child: const CashBuddyApp(),
          ),
        ),
      );
      await settle(tester);
      final p = dark ? 'dark' : 'light';
      // new month: the title celebration opens by itself, once
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(find.textContaining('YOU EARNED THIS TITLE'), findsOneWidget);
      await shot(tester, '$p-0-celebration');
      await settle(tester);
      await settle(tester);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
      await shot(tester, '$p-0b-celebration-compare');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await shot(tester, '$p-1-dashboard');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await shot(tester, '$p-2-dashboard-scrolled');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await shot(tester, '$p-2b-insights');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      await tapText(tester, 'PLUS SCORE');
      await shot(tester, '$p-2d-grade');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tapText(tester, 'BUDGET');
      await shot(tester, '$p-2e-budget');
      await tester.tap(find.text('Year'));
      await settle(tester);
      await shot(tester, '$p-2e2-budget-year');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await shot(tester, '$p-2f-budget-splits');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tapText(tester, 'Activity', last: true);
      await shot(tester, '$p-4-transactions');
      await tapText(tester, 'Debts', last: true);
      await shot(tester, '$p-5-debts');
      await tapText(tester, 'Invest', last: true);
      await shot(tester, '$p-6-invest');
      await tapText(tester, 'Family Chit 2026');
      await shot(tester, '$p-7-chit');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await shot(tester, '$p-8-chit-schedule');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tapText(tester, 'Home', last: true);
      await tapText(tester, '2 detected transactions to review');
      await shot(tester, '$p-9-inbox');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tapText(tester, 'Invest', last: true);
      await tapText(tester, 'Gold savings');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await shot(tester, '$p-12-weekly-plan');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tapText(tester, 'Settings', last: true);
      await shot(tester, '$p-10-settings');
      await tester.scrollUntilVisible(
        find.text('Trophy shelf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Trophy shelf'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await settle(tester);
      await tapText(tester, 'Trophy shelf');
      await shot(tester, '$p-13-trophies');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      // categories: sheet, emoji tiles, sub view, and the sent-home party
      await tapText(tester, 'Home', last: true);
      await tapText(tester, 'Add');
      await shot(tester, '$p-14-add-sheet');
      await tapText(tester, 'Uncategorised');
      await shot(tester, '$p-15-category-picker');
      await tester.ensureVisible(find.text('Hobbies').first);
      await tapText(tester, 'Hobbies');
      await shot(tester, '$p-16-category-subs');
      await tester.tap(find.byTooltip('Back to categories'));
      await settle(tester);
      await tester.ensureVisible(find.text('Sent Home').first);
      await tapText(tester, 'Sent Home');
      await tapText(tester, 'Parents');
      await tester.enterText(find.byType(TextField).first, '5000');
      await tapText(tester, 'Add', last: true);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 900));
      await shot(tester, '$p-17-home-celebration');
      await tester.tap(find.text('Home is proud of you'));
      await settle(tester);
      // the Categories page, opened directly
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(builder: (_) => const CategoriesPage()),
          );
      await settle(tester);
      await shot(tester, '$p-18-categories');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      // the new-investment form (recurring) and a schedule detail
      await tapText(tester, 'Invest', last: true);
      await tapText(tester, 'Add investment');
      await tapText(tester, 'Custom investment');
      await tapText(tester, 'Recurring');
      await tapText(tester, 'Weekly');
      await shot(tester, '$p-11-custom-form');
      await tester.runAsync(() => env.db.close());
    });
  }
}

/// Renders every illustration so the artwork can be checked without a device.
void artGallery() {
  testWidgets('art gallery', (tester) async {
    tester.view.physicalSize = const Size(780, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFF2F6BFF)),
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              children: [
                for (final a in Art.values)
                  Illustration(a, height: 170, animate: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await shot(tester, 'art-gallery');
  });
}

/// Renders the restore loader mid-way, so its look can be checked.
void loaderShot() {
  testWidgets('restore loader', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final progress = ValueNotifier(
      const SyncProgress(
        active: true,
        stage: SyncStage.downloading,
        done: 3,
        total: 8,
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: RestoreScreen(progress: progress),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'loader-restore');
    await tester.pumpWidget(const SizedBox());
  });
}

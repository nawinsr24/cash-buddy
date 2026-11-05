// Renders real screens to PNGs (build/screens/*.png) using the Roboto + Material
// Icons fonts from the Flutter SDK, so layout and design can be inspected
// without a simulator. Not a golden comparison: it just writes images.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/ui/art.dart';
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
      final now = DateTime.now();
      late TestEnv env;
      await tester.runAsync(() async {
        env = await newEnv(accountMode: 'split', opening: 8500000, now: now);
        final r = env.repo;
        await r.setSetting('smsEnabled', '1');
        final d = Dates.today();
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
      await shot(tester, '$p-1-dashboard');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await shot(tester, '$p-2-dashboard-scrolled');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pump(const Duration(seconds: 2)); // let the fling finish
      await tapText(tester, 'Total Spending');
      await shot(tester, '$p-3-spending-detail');
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

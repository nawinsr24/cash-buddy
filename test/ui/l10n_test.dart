import 'dart:io';

import 'package:cash_buddy/domain/money.dart';
import 'package:cash_buddy/l10n/l10n.dart';
import 'package:cash_buddy/l10n/strings_hi.dart';
import 'package:cash_buddy/l10n/strings_ta.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pump, settle;

void main() {
  tearDown(() {
    L10n.use('en');
    Money.configure();
  });

  test('English is first and unknown text falls back to English', () {
    expect(appLanguages.first.code, 'en');
    L10n.use('hi');
    expect(tr('Settings'), 'सेटिंग्स');
    expect(
      tr('A sentence nobody translated yet'),
      'A sentence nobody translated yet',
    );
    L10n.use('ta');
    expect(tr('Settings'), 'அமைப்புகள்');
    L10n.use('xx'); // unknown language: English
    expect(tr('Settings'), 'Settings');
  });

  test('both dictionaries cover the same texts, none empty', () {
    expect(stringsHi.keys.toSet(), stringsTa.keys.toSet());
    for (final m in [stringsHi, stringsTa]) {
      m.forEach((k, v) {
        expect(v.trim(), isNotEmpty, reason: k);
      });
    }
  });

  test('every translated text really appears in the app (no stale keys)', () {
    final source = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('lib/l10n/'))
          f.readAsStringSync(),
    ].join('\n');
    final missing = [
      for (final k in stringsHi.keys)
        if (!source.contains(k.replaceAll("'", "\\'"))) k,
    ];
    expect(missing, isEmpty);
  });

  testWidgets('switching to Hindi changes the screens and keeps ₹/INR', (
    tester,
  ) async {
    final env = await pump(tester);
    await tester.runAsync(() => env.repo.setSetting('language', 'hi'));
    await tester.pump();
    await settle(tester);
    expect(find.text('सेटिंग्स'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(Money.code, 'INR');
  });

  testWidgets('switching currency to USD changes how amounts are written', (
    tester,
  ) async {
    final env = await pump(tester, opening: 10000000);
    await tester.runAsync(() => env.repo.setSetting('currency', 'USD'));
    await tester.pump();
    await settle(tester);
    expect(find.text(r'$100,000.00'), findsWidgets);
    expect(find.text('₹1,00,000.00'), findsNothing);
  });
}

import 'dart:typed_data';

import 'package:cash_buddy/app.dart';
import 'package:cash_buddy/features/backup_actions.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/backup_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'app_flow_test.dart' show settle, tapText;
import 'cards_test.dart' show wait;

class _Files extends FileDialogs {
  Uint8List? file;
  @override
  Future<Uint8List?> open() async => file;
}

void main() {
  testWidgets('restore from Settings asks first, then replaces', (
    tester,
  ) async {
    final files = _Files();
    late TestEnv env;
    await tester.runAsync(() async {
      final other = await newEnv(opening: 777700);
      files.file = await buildBackup(other.repo);
      await other.db.close();
      env = await newEnv(opening: 100000);
    });
    addTearDown(() => tester.runAsync(() => env.db.close()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(env.repo),
          fileDialogsProvider.overrideWithValue(files),
        ],
        child: const CashBuddyApp(),
      ),
    );
    await settle(tester);
    await tapText(tester, 'Settings', last: true);
    final tile = find.text('Restore from a file');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);

    await tester.tap(tile);
    await settle(tester);
    await tapText(tester, 'Cancel');
    expect(await tester.runAsync(() => env.repo.totalBalance()), 100000);

    await tester.tap(tile);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await wait(tester);
    expect(await tester.runAsync(() => env.repo.totalBalance()), 777700);
    expect(tester.takeException(), isNull);
  });
}

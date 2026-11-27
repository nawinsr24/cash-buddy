import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/features/group.dart';
import 'package:cash_buddy/features/group_keeper.dart';
import 'package:cash_buddy/platform/push.dart';
import 'package:cash_buddy/providers.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'cards_test.dart' show wait;

class _Push extends Push {
  var asked = 0;
  @override
  Future<String?> token() async {
    asked++;
    return 'phone-token';
  }

  @override
  Stream<void> get nudges => const Stream.empty();
}

void main() {
  testWidgets('push is asked for only when in a group', (tester) async {
    final paths = <String>[];
    final push = _Push();
    late TestEnv env;
    await tester.runAsync(() async {
      env = await newEnv();
      await env.repo.setSetting('accountSession', '{}');
    });
    addTearDown(() => tester.runAsync(() => env.db.close()));
    final service = GroupService(
      env.repo,
      secrets: MemorySecretStore(),
      server: Uri.parse('https://x.test/status'),
      send: (_, url, _, _) async {
        final path = url.pathSegments.last;
        paths.add(path);
        return (200, path == 'fetch' || path == 'requests' ? '[]' : '{}');
      },
    );
    Future<void> openApp() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            repoProvider.overrideWithValue(env.repo),
            groupServiceProvider.overrideWithValue(service),
            pushProvider.overrideWithValue(push),
          ],
          child: const MaterialApp(home: GroupKeeper(child: Text('app'))),
        ),
      );
      await wait(tester);
    }

    await openApp();
    expect((push.asked, paths.length), (0, 0));

    await tester.runAsync(() => service.create('Naveen'));
    paths.clear();
    await openApp();
    expect(push.asked, 1);
    expect(paths.first, 'push');
    expect(paths, containsAll(['upload', 'fetch']));
  });
}

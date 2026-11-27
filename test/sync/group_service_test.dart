import 'dart:io';

import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/home_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/features/group_keeper.dart' show updateGroup;
import 'package:cash_buddy/platform/access.dart';
import 'package:cash_buddy/platform/diag.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:cash_buddy/sync/group/http_post_box.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

/// Two phones over the real post box code, against the server in
/// server/test/serve.js. Run by `npm test` in server/.
void main() {
  final url = Platform.environment['GROUP_URL'];
  final sessions = (Platform.environment['GROUP_SESSIONS'] ?? '').split(' ');

  test('create, invite, join, add, edit, see the same', () async {
    final seen = <String>[];
    Future<(int, String)> watch(
      String method,
      Uri u,
      Map<String, String> headers,
      String? body,
    ) async {
      if (body != null) seen.add(body);
      return sendHttp(method, u, headers, body);
    }

    Future<(TestEnv, GroupService, SecretStore)> phone(int i) async {
      final env = await newEnv(device: 'dev$i');
      addTearDown(() => env.db.close());
      await env.repo.setSetting('accountSession', sessions[i]);
      final secrets = MemorySecretStore();
      final group = GroupService(
        env.repo,
        secrets: secrets,
        server: Uri.parse('$url/'),
        send: watch,
      );
      return (env, group, secrets);
    }

    final (envA, a, secretsA) = await phone(0);
    final (_, b, _) = await phone(1);
    await a.create('Naveen');
    final code = await a.inviteCode();
    // mistyped, and well formed but with the wrong key
    for (final bad in ['x' * 43, 'A' * 43]) {
      await expectLater(
        b.join('${code.split('.').first}.$bad', 'Priya'),
        throwsA(isA<GroupProblem>()),
      );
    }
    await b.join(code, 'Priya');
    await a.change(
      (g) => g.add([
        {'kind': 'expense', 'amountMinor': 200000, 'note': 'SECRET-GROCERIES'},
      ]),
    );
    for (var i = 0; i < 2; i++) {
      await a.sync();
      await b.sync();
    }
    final ga = (await a.open())!, gb = (await b.open())!;
    expect(gb.total, 200000);
    expect(GroupService.ofKind(gb, 'member').length, 2);
    expect(ga.disk.notes.keys.toSet(), gb.disk.notes.keys.toSet());
    // the server only ever saw locked notes
    expect(seen.join(), isNot(contains('SECRET-GROCERIES')));
    expect(seen.join(), isNot(contains('Priya')));

    final id = GroupService.ofKind(gb, 'expense').single.id;
    await b.change((g) => g.edit(id, {'amountMinor': 250000}));
    await b.sync();
    // the app restarts: everything is read back from the database
    final again = GroupService(
      envA.repo,
      secrets: secretsA,
      server: Uri.parse('$url/'),
    );
    await again.sync();
    final restarted = (await again.open())!;
    expect(restarted.total, 250000);
    expect(restarted.history(id).length, 2);
    await b.leave();
    expect(await b.open(), isNull);
  }, skip: url == null ? 'needs the local server' : false);

  test('spends from before pairing reach the other phone', () async {
    Future<(TestEnv, GroupService)> phone(int i) async {
      final env = await newEnv(device: 'dev$i', opening: 1000000);
      addTearDown(() => env.db.close());
      await env.repo.setSetting('accountSession', sessions[i]);
      return (
        env,
        GroupService(
          env.repo,
          secrets: MemorySecretStore(),
          server: Uri.parse('$url/'),
        ),
      );
    }

    final (envA, a) = await phone(0);
    final (envB, b) = await phone(1);
    for (var n = 1; n <= 5; n++) {
      await envA.repo.addTransaction(type: 'debit', amountMinor: n * 100);
    }
    await a.create('Naveen');
    await envA.repo.chooseSharing(earlierToo: true);
    await updateGroup(a, envA.repo); // sent while still alone
    await b.join(await a.inviteCode(), 'Priya');
    await envB.repo.chooseSharing(earlierToo: true);
    await envB.repo.addTransaction(type: 'debit', amountMinor: 7);
    final month = DateRange.thisMonth(DateTime(2026, 11, 4));
    for (var i = 0; i < 2; i++) {
      await updateGroup(b, envB.repo);
      await updateGroup(a, envA.repo);
    }
    await updateGroup(b, envB.repo);
    expect((await envB.repo.homeSummary(month))!.sharedTotal, 1507);
    final log = Diag.instance.dump();
    expect(log, contains('home sync ok'));
    expect(log, contains('home join: accepted'));
    expect(log, isNot(contains('Priya')));
    expect((await envA.repo.homeSummary(month))!.sharedTotal, 1507);
  }, skip: url == null ? 'needs the local server' : false);

  test('no sign-in, no group', () async {
    final env = await newEnv();
    addTearDown(() => env.db.close());
    final group = GroupService(
      env.repo,
      secrets: MemorySecretStore(),
      server: Uri.parse('https://x.test/'),
    );
    await expectLater(group.create('N'), throwsA(isA<GroupProblem>()));
    expect(await group.open(), isNull);
    expect(Diag.instance.dump(), contains('home not signed in'));
    expect(Diag.instance.dump(), isNot(contains('N@')));
    expect(const AccessConfig('', '').enabled, isFalse);
  });
}

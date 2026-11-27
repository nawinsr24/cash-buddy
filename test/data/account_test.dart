import 'dart:convert';

import 'package:cash_buddy/platform/access.dart';
import 'package:cash_buddy/platform/account.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Access access;
  Uri? posted;
  String? sent;

  setUp(() async {
    env = await newEnv();
    addTearDown(() => env.db.close());
    access = Access(
      env.repo,
      config: const AccessConfig('https://x.test/status', 'AAAA'),
      fetch: (_) async => throw Exception('offline'),
    );
    posted = sent = null;
  });

  Account account({String? token = 'tok', int code = 200, bool down = false}) =>
      Account(
        access,
        idToken: () async => token,
        post: (url, body) async {
          if (down) throw Exception('down');
          posted = url;
          sent = body;
          return (
            code,
            jsonEncode({
              'email': 'a@example.com',
              'session': <String, Object>{},
            }),
          );
        },
      );

  test('sign-in sends the token with consent, and remembers who', () async {
    expect(await account().signIn(), isTrue);
    expect(posted.toString(), 'https://x.test/signin');
    expect((jsonDecode(sent!) as Map)['consent'], consentVersion);
    expect(await account().email, 'a@example.com');
    await account().signOut();
    expect(await account().email, '');
  });

  test('backing out sends nothing', () async {
    expect(await account(token: null).signIn(), isFalse);
    expect(sent, isNull);
  });

  test('refusal or no server leaves the user signed out', () async {
    for (final bad in [account(code: 401), account(down: true)]) {
      await expectLater(bad.signIn(), throwsA(isA<SignInProblem>()));
    }
    expect(await account().email, isNull);
  });
}

import 'dart:convert';

import 'package:cash_buddy/platform/access.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A stand-in server with its own signing key.
class _Server {
  final SimpleKeyPair key;
  final String publicKey;
  _Server(this.key, this.publicKey);

  static Future<_Server> create() async {
    final key = await Ed25519().newKeyPair();
    final public = await key.extractPublicKey();
    return _Server(key, base64Encode(public.bytes));
  }

  Future<String> reply(String device, String status, int issuedAt) async {
    final payload = jsonEncode({
      'device': device,
      'status': status,
      'issuedAt': issuedAt,
    });
    final sig = await Ed25519().sign(utf8.encode(payload), keyPair: key);
    return jsonEncode({
      'payload': payload,
      'signature': base64Encode(sig.bytes),
    });
  }
}

void main() {
  late TestEnv env;
  late _Server server;
  late Future<String> Function(String device) answer;
  late Access access;
  Access open() => Access(
    env.repo,
    config: AccessConfig('https://example.test/status', server.publicKey),
    fetch: (url) => answer(url.queryParameters['device']!),
    timeout: const Duration(milliseconds: 100),
  );

  setUp(() async {
    env = await newEnv();
    server = await _Server.create();
    access = open();
    addTearDown(() => env.db.close());
  });

  test('block, stay blocked offline and after restart, unblock', () async {
    answer = (d) => server.reply(d, 'blocked', 1);
    expect(await access.check(), isTrue);
    answer = (_) async => throw Exception('offline');
    expect(await access.check(), isTrue);
    expect(await open().isBlocked, isTrue); // a fresh start of the app
    answer = (d) => server.reply(d, 'active', 2);
    expect(await access.check(), isFalse);
  });

  test('a server that is down, slow or broken never blocks', () async {
    for (final bad in <Future<String> Function(String)>[
      (_) async => throw Exception('down'),
      (_) => Future.delayed(const Duration(seconds: 1), () => 'late'),
      (_) async => '<html>502</html>',
      (_) async => '{"status":"blocked"}',
    ]) {
      answer = bad;
      expect(await access.check(), isFalse);
    }
  });

  test('forged, misdirected and replayed replies are ignored', () async {
    final other = await _Server.create();
    answer = (d) => other.reply(d, 'blocked', 5);
    expect(await access.check(), isFalse);
    answer = (_) => server.reply('in_someone_else', 'blocked', 5);
    expect(await access.check(), isFalse);

    final oldActive = await server.reply(await access.installId(), 'active', 3);
    answer = (d) => server.reply(d, 'blocked', 9);
    expect(await access.check(), isTrue);
    answer = (_) async => oldActive;
    expect(await access.check(), isTrue);
  });

  test('without a server in the build, nothing happens', () async {
    final off = Access(
      env.repo,
      config: const AccessConfig('', ''),
      fetch: (_) => fail('must not call out'),
    );
    expect(await off.check(), isFalse);
    expect(await env.repo.getSetting('accessId'), isNull);
  });
}

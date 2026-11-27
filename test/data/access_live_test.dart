import 'dart:io';

import 'package:cash_buddy/platform/access.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The app's real code against a locally running server. Run by
/// `server/scripts/live_test.sh`; skipped otherwise.
void main() {
  final env_ = Platform.environment;
  final url = env_['LIVE_URL'], key = env_['LIVE_KEY'];
  final token = env_['LIVE_TOKEN'];

  test('register, block, stay blocked, unblock', () async {
    final env = await newEnv();
    addTearDown(() => env.db.close());
    final access = Access(env.repo, config: AccessConfig('$url/status', key!));
    expect(await access.check(), isFalse);
    expect(await env.repo.getSetting('accessSeen'), isNotNull);
    final id = await access.installId();

    Future<int> admin(String action, [String? bearer]) async {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('$url/admin/$action?device=$id'),
      );
      request.headers.set('authorization', 'Bearer ${bearer ?? token}');
      final response = await request.close();
      await response.drain<void>();
      client.close();
      return response.statusCode;
    }

    expect(await admin('block', 'wrong'), 401);
    expect(await access.check(), isFalse);
    expect(await admin('block'), 200);
    expect(await access.check(), isTrue);
    // server gone: the block stays
    final cut = Access(
      env.repo,
      config: AccessConfig('http://localhost:1/status', key),
    );
    expect(await cut.check(), isTrue);
    expect(await admin('unblock'), 200);
    expect(await access.check(), isFalse);
  }, skip: url == null ? 'needs the local server' : false);
}

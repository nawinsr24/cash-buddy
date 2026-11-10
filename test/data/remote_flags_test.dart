import 'package:cash_buddy/platform/features.dart';
import 'package:cash_buddy/platform/remote_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  test('the cloud switch turns SMS reading off and on', () async {
    final e = await newEnv();
    final off = MockClient(
      (_) async => http.Response('{"sms_reading":{"android":false}}', 200),
    );
    await refreshRemoteFlags(e.repo, client: off);
    expect(await e.repo.getSetting('flag_sms'), '0');
    expect(Features.smsReading(remoteFlag: false), isFalse);

    // asked again only after a day
    final on = MockClient(
      (_) async => http.Response('{"sms_reading":{"android":true}}', 200),
    );
    await refreshRemoteFlags(e.repo, client: on);
    expect(await e.repo.getSetting('flag_sms'), '0');
    await e.repo.setSetting('flagsAt', '2020-01-01T00:00:00Z');
    await refreshRemoteFlags(e.repo, client: on);
    expect(await e.repo.getSetting('flag_sms'), '1');
  });

  test('offline, errors and bad files keep the last answer', () async {
    final e = await newEnv();
    await e.repo.setSetting('flag_sms', '1');
    await refreshRemoteFlags(
      e.repo,
      client: MockClient((_) async => throw Exception('offline')),
    );
    await refreshRemoteFlags(
      e.repo,
      client: MockClient((_) async => http.Response('not json', 200)),
    );
    await e.repo.setSetting('flagsAt', '2020-01-01T00:00:00Z');
    await refreshRemoteFlags(
      e.repo,
      client: MockClient((_) async => http.Response('oops', 500)),
    );
    expect(await e.repo.getSetting('flag_sms'), '1');
  });
}

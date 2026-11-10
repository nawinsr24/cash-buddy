import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/repo.dart';

/// A tiny settings file on our own site that can switch features on or off
/// without a new release (for example SMS reading). Only the file is
/// downloaded: no user data is sent. The last answer is remembered, and if
/// the site cannot be reached the app keeps working with it.
const flagsUrl = 'https://nawinsr24.github.io/cash-buddy/app/flags.json';

/// Fetches the file at most once a day and stores what it says.
Future<void> refreshRemoteFlags(
  Repo repo, {
  http.Client? client,
  String url = flagsUrl,
}) async {
  try {
    final last = DateTime.tryParse(await repo.getSetting('flagsAt') ?? '');
    if (last != null && repo.now().difference(last).inHours < 24) return;
    final c = client ?? http.Client();
    final res = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return;
    final j = jsonDecode(res.body);
    if (j is! Map) return;
    final sms = j['sms_reading'];
    if (sms is Map && sms['android'] is bool) {
      await repo.setSetting('flag_sms', sms['android'] == true ? '1' : '0');
    }
    await repo.setSetting('flagsAt', repo.now().toUtc().toIso8601String());
  } catch (_) {
    // offline or a bad file: keep the last known answer
  }
}

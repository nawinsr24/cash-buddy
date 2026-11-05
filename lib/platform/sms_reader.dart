import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../domain/sms_parser.dart';
import 'diag.dart';

/// Android-only bridge to the on-device SMS inbox (see MainActivity.kt).
/// On iOS / web there is no inbox access, so every call reports "unsupported".
class SmsReader {
  SmsReader._();
  static final instance = SmsReader._();
  static const _ch = MethodChannel('cash_buddy/sms');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasPermission() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Shows the system permission dialog (no-op if already granted).
  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  bool? _autoDetectSent, _secureSent;

  /// Tells the native receiver whether it may alert on incoming transaction SMS.
  /// Only calls the phone when the value actually changed.
  Future<void> setAutoDetect(bool enabled) async {
    if (!supported || _autoDetectSent == enabled) return;
    _autoDetectSent = enabled;
    Diag.instance.log('native setAutoDetect($enabled)');
    try {
      await _ch.invokeMethod<void>('setAutoDetect', {'enabled': enabled});
    } on PlatformException {
      // non-fatal
    } on MissingPluginException {
      // non-fatal
    }
  }

  /// Android FLAG_SECURE: hides the app in recent apps and blocks screenshots.
  Future<void> setSecure(bool on) async {
    if (!supported || _secureSent == on) return;
    _secureSent = on;
    Diag.instance.log('native setSecure($on)');
    try {
      await _ch.invokeMethod<void>('setSecure', {'enabled': on});
    } on PlatformException {
      // non-fatal
    } on MissingPluginException {
      // non-fatal
    }
  }

  /// "inbox" if the app was opened from a transaction notification.
  Future<String?> consumeLaunchAction() async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<String>('consumeLaunchAction');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<List<({String sender, String body, DateTime receivedAt})>> readInbox({
    required DateTime since,
    int limit = 500,
  }) async {
    final rows = await _ch.invokeListMethod<Map>('readInbox', {
      'sinceMillis': since.millisecondsSinceEpoch,
      'limit': limit,
    });
    return [
      for (final r in rows ?? const <Map>[])
        (
          sender: (r['address'] as String?) ?? '',
          body: (r['body'] as String?) ?? '',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            (r['date'] as num).toInt(),
          ),
        ),
    ];
  }
}

class SmsScanResult {
  final int scanned, added, duplicates, ignored;
  final String? error;

  /// True when another scan was already running, so nothing was done.
  final bool busy;
  const SmsScanResult(
    this.scanned,
    this.added,
    this.duplicates,
    this.ignored, [
    this.error,
    this.busy = false,
  ]);
  bool get ok => error == null;
}

/// Reads recent inbox messages and queues transaction candidates for review.
/// Nothing is written to the ledger here; the user confirms each one.
///
/// The first scan only looks at today's messages (from local midnight), so a
/// fresh install does not dig up old history. Later scans pick up from the
/// previous scan, so after a few days away you see everything you missed.
bool _scanning = false;

Future<SmsScanResult> scanSmsInbox(
  Repo repo, {
  SmsReader? reader,
  Duration readTimeout = const Duration(seconds: 20),
}) async {
  if (_scanning) return const SmsScanResult(0, 0, 0, 0, null, true);
  _scanning = true;
  try {
    return await _scan(repo, reader, readTimeout);
  } finally {
    _scanning = false;
  }
}

Future<SmsScanResult> _scan(
  Repo repo,
  SmsReader? reader,
  Duration readTimeout,
) async {
  final r = reader ?? SmsReader.instance;
  final sw = Stopwatch()..start();
  Diag.instance.log('scan start');
  Future<SmsScanResult> done(SmsScanResult res) async {
    // Kept for the Diagnostics line in Settings, so a problem can be seen.
    Diag.instance.log(
      res.ok
          ? 'scan done: ${res.scanned} msgs, ${res.added} new, ${sw.elapsedMilliseconds} ms'
          : 'scan failed: ${res.error}',
    );
    try {
      await repo.setSetting(
        'lastScanInfo',
        res.ok
            ? '${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}: '
                  '${res.scanned} messages, ${res.added} new, ${sw.elapsedMilliseconds} ms'
            : '${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}: ${res.error}',
      );
    } catch (_) {}
    return res;
  }

  if (!await r.hasPermission()) {
    return done(const SmsScanResult(0, 0, 0, 0, 'SMS permission not granted'));
  }
  try {
    final last = int.tryParse(await repo.getSetting('smsLastScan') ?? '');
    final startedAt = DateTime.now();
    // overlap by a minute so a message arriving mid-scan is never skipped (dedup handles repeats)
    final since = last != null
        ? DateTime.fromMillisecondsSinceEpoch(last)
              .subtract(const Duration(minutes: 1))
        : DateTime(startedAt.year, startedAt.month, startedAt.day);
    // Never wait forever on the phone's SMS store: a stuck read must not
    // leave scanning blocked.
    final msgs = await r.readInbox(since: since).timeout(readTimeout);
    final res = await repo.ingestSms(msgs, SmsParser());
    await repo.setSetting('smsLastScan', '${startedAt.millisecondsSinceEpoch}');
    return await done(
      SmsScanResult(msgs.length, res.added, res.duplicates, res.rejected),
    );
  } on TimeoutException {
    return done(
      const SmsScanResult(
        0,
        0,
        0,
        0,
        'Reading messages took too long. Try again.',
      ),
    );
  } catch (e) {
    return done(SmsScanResult(0, 0, 0, 0, '$e'));
  }
}

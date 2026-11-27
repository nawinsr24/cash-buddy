/// Lets the admin switch an install off. The rules:
///  * the app never waits for the server and never blocks because it failed;
///  * only a reply signed with the server's key can block or unblock;
///  * a block is saved, so going offline or restarting does not lift it.
///
/// Inert unless the build names a server:
/// `--dart-define=ACCESS_URL=... --dart-define=ACCESS_KEY=<base64 Ed25519>`.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../data/repo.dart';

class AccessConfig {
  final String url, publicKey;
  const AccessConfig(this.url, this.publicKey);

  static const fromBuild = AccessConfig(
    String.fromEnvironment('ACCESS_URL'),
    String.fromEnvironment('ACCESS_KEY'),
  );

  bool get enabled => url.isNotEmpty && publicKey.isNotEmpty;
}

/// Returns the reply body, or throws.
typedef FetchReply = Future<String> Function(Uri url);

class Access {
  final Repo repo;
  final AccessConfig config;
  final FetchReply fetch;
  final Duration timeout;
  Access(
    this.repo, {
    this.config = AccessConfig.fromBuild,
    FetchReply? fetch,
    this.timeout = const Duration(seconds: 3),
  }) : fetch = fetch ?? _get;

  static Future<String> _get(Uri url) async {
    final r = await http.get(url);
    if (r.statusCode != 200) throw http.ClientException('${r.statusCode}');
    return r.body;
  }

  Future<bool> get isBlocked async =>
      await repo.getSetting('accessBlocked') == '1';

  /// This install's own ID. Settings stay on the phone and are never synced.
  Future<String> installId() async {
    var id = await repo.getSetting('accessId');
    if (id == null) {
      id = Repo.newId('in_');
      await repo.setSetting('accessId', id);
    }
    return id;
  }

  /// Asks the server once. Any trouble at all changes nothing.
  Future<bool> check() async {
    if (!config.enabled) return false;
    try {
      final id = await installId();
      final url = Uri.parse(config.url)
          .replace(queryParameters: {'device': id});
      await _apply(await fetch(url).timeout(timeout), id);
    } catch (_) {
      // server down, slow or talking nonsense
    }
    return isBlocked;
  }

  Future<void> _apply(String body, String id) async {
    final envelope = jsonDecode(body) as Map<String, dynamic>;
    final payload = envelope['payload'] as String;
    final genuine = await Ed25519().verify(
      utf8.encode(payload),
      signature: Signature(
        base64Decode(envelope['signature'] as String),
        publicKey: SimplePublicKey(
          base64Decode(config.publicKey),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!genuine) return;
    final reply = jsonDecode(payload) as Map<String, dynamic>;
    if (reply['device'] != id) return; // meant for another phone
    final status = reply['status'];
    if (status != 'active' && status != 'blocked') return;
    // An old reply replayed later must not undo a newer one.
    final issued = reply['issuedAt'] as int;
    final seen = int.tryParse(await repo.getSetting('accessSeen') ?? '') ?? 0;
    if (issued <= seen) return;
    await repo.setSetting('accessSeen', '$issued');
    await repo.setSetting('accessBlocked', status == 'blocked' ? '1' : '0');
  }
}

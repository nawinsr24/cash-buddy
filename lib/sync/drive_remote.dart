import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'sync_engine.dart';

/// Google Drive `appDataFolder` store (hidden, per-app, `drive.appdata` scope
/// only — the app can never see the user's other Drive files).
///
/// NOTE: requires an OAuth client configured in Google Cloud Console
/// (see docs/SETUP_GOOGLE_DRIVE.md). Not exercised by the automated tests,
/// which use [InMemoryRemote]; verify on a device before relying on it.
class DriveSignInException implements Exception {
  final String message;
  DriveSignInException(this.message);
  @override
  String toString() => message;
}

class DriveRemote implements RemoteStore {
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  final http.Client _client;
  late final drive.DriveApi _api = drive.DriveApi(_client);
  final Map<String, String> _ids = {};

  DriveRemote._(this._client);

  /// The Google OAuth *web* client ID (Google Cloud Console). Set at build
  /// time with --dart-define=GOOGLE_SERVER_CLIENT_ID=... ; without it Google
  /// sign-in cannot work on Android.
  /// Not a secret: it only names the app to Google. Can be overridden at
  /// build time with --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '725839010520-lhet238be54f4iadun9sd2qoug4i2fu6.apps.googleusercontent.com',
  );

  /// Google sign-in is wired for the Android app. The browser build has no
  /// sign-in set up, so Online Mode is reported as unavailable there.
  static bool get configured => !kIsWeb && serverClientId.isNotEmpty;

  static const notConfiguredMessage =
      'Google sign-in is not set up in this version of the app yet, so Online Mode cannot start. Your data stays safely on this phone in Offline Mode.';

  /// Interactive sign-in + scope grant. Returns null if the user cancels;
  /// throws a readable [DriveSignInException] for any other failure.
  static Future<DriveRemote?> signIn() async {
    if (!configured) throw DriveSignInException(notConfiguredMessage);
    final gs = GoogleSignIn.instance;
    try {
      await gs.initialize(serverClientId: serverClientId);
      final account = await gs.authenticate(scopeHint: [scope]);
      final authz = await account.authorizationClient.authorizeScopes([scope]);
      return DriveRemote._(_BearerClient(authz.accessToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw DriveSignInException(
        'Google sign-in failed (${e.code.name}). ${e.description ?? ''}'.trim(),
      );
    } catch (e) {
      throw DriveSignInException('Google sign-in failed: $e');
    }
  }

  /// Silent re-authentication on app start; null if the user must sign in again.
  static Future<DriveRemote?> restore() async {
    try {
      if (!configured) return null;
      final gs = GoogleSignIn.instance;
      await gs.initialize(serverClientId: serverClientId);
      final account = await gs.attemptLightweightAuthentication();
      if (account == null) return null;
      final authz = await account.authorizationClient.authorizationForScopes([
        scope,
      ]);
      return authz == null
          ? null
          : DriveRemote._(_BearerClient(authz.accessToken));
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() => GoogleSignIn.instance.signOut();

  @override
  Future<List<String>> list() async {
    final names = <String>[];
    String? token;
    do {
      final res = await _api.files.list(
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name)',
        pageSize: 1000,
        pageToken: token,
      );
      for (final f in res.files ?? const <drive.File>[]) {
        if (f.name != null && f.id != null) {
          _ids[f.name!] = f.id!;
          names.add(f.name!);
        }
      }
      token = res.nextPageToken;
    } while (token != null);
    return names;
  }

  @override
  Future<List<int>> read(String name) async {
    final id = _ids[name] ?? (await list(), _ids[name]).$2;
    if (id == null) throw StateError('Remote file missing: $name');
    final media = await _api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<void> write(String name, List<int> bytes) async {
    final meta = drive.File()
      ..name = name
      ..parents = ['appDataFolder'];
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final created = await _api.files.create(meta, uploadMedia: media);
    if (created.id != null) _ids[name] = created.id!;
  }
}

class _BearerClient extends http.BaseClient {
  final String token;
  final http.Client _inner = http.Client();
  _BearerClient(this.token);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }
}

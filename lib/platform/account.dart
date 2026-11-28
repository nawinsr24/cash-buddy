/// Signing in to the app's own server, needed only for group and server
/// features. Nothing is sent until the user agrees.
library;

import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../sync/drive_remote.dart';
import 'access.dart';
import 'diag.dart';
import 'google_identity.dart';

/// Raised with a message fit to show.
class SignInProblem implements Exception {
  final String message;
  SignInProblem(this.message);
  @override
  String toString() => message;
}

/// The consent text's version; the server refuses any other.
const consentVersion = 1;

/// A Google ID token, or null when the user backs out.
typedef GoogleIdToken = Future<String?> Function();

Future<String?> googleIdToken() async {
  if (!DriveRemote.configured) {
    throw SignInProblem('Google sign-in is not available in this version.');
  }
  try {
    final google = GoogleSignIn.instance;
    await google.initialize(serverClientId: DriveRemote.serverClientId);
    final account = await google.authenticate();
    return account.authentication.idToken;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    throw SignInProblem('Google sign-in failed. Please try again.');
  }
}

typedef PostJson = Future<(int, String)> Function(Uri url, String body);

class Account {
  final Access access;
  final GoogleIdToken idToken;
  final PostJson post;
  Account(this.access, {GoogleIdToken? idToken, PostJson? post})
    : idToken = idToken ?? googleIdToken,
      post = post ?? _post;

  static Future<(int, String)> _post(Uri url, String body) async {
    final r = await http
        .post(url, headers: {'content-type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    return (r.statusCode, r.body);
  }

  Future<String?> get email => access.repo.getSetting('accountEmail');

  /// Call only after the user has agreed. False when they back out of Google.
  /// [have] is the token from a sign-in just made, so Google is not asked
  /// twice.
  Future<bool> signIn({String? have}) async {
    final token = have ?? await idToken();
    if (token == null) return false;
    final device = await access.installId();
    final int status;
    final Map<String, dynamic> reply;
    try {
      final (code, body) = await post(
        Uri.parse(access.config.url).resolve('signin'),
        jsonEncode({
          'device': device,
          'idToken': token,
          'consent': consentVersion,
        }),
      );
      status = code;
      reply = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw SignInProblem('The server could not be reached. Try again later.');
    }
    Diag.instance.log('home sign-in: server code $status');
    if (status != 200) {
      throw SignInProblem('The server did not accept the sign-in.');
    }
    final repo = access.repo;
    final problem = await useGoogleAccount(repo, reply['email'] as String);
    if (problem != null) throw SignInProblem(problem);
    await repo.setSetting('accountEmail', reply['email'] as String);
    await repo.setSetting('accountSession', jsonEncode(reply['session']));
    await access.check();
    return true;
  }

  /// Renews the sign-in quietly while it is still good, so Google is not
  /// needed again every month. Any trouble leaves things as they are.
  Future<void> renew() async {
    try {
      final repo = access.repo;
      final raw = await repo.getSetting('accountSession') ?? '';
      if (raw.isEmpty) return;
      final claims =
          jsonDecode((jsonDecode(raw) as Map)['payload'] as String) as Map;
      final left = (claims['exp'] as int) - repo.now().millisecondsSinceEpoch;
      if (left > const Duration(days: 15).inMilliseconds) return;
      final (code, body) = await post(
        Uri.parse(access.config.url).resolve('renew'),
        jsonEncode({'session': jsonDecode(raw)}),
      );
      if (code == 200) {
        await repo.setSetting(
          'accountSession',
          jsonEncode((jsonDecode(body) as Map)['session']),
        );
      }
    } catch (_) {}
  }

  /// Forgets the sign-in on this phone. A block already in force stays.
  Future<void> signOut() async {
    await access.repo.setSetting('googleEmail', '');
    await access.repo.setSetting('accountEmail', '');
    await access.repo.setSetting('accountSession', '');
  }
}

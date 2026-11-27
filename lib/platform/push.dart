/// The "something new" nudge for the shared group. Firebase is only started
/// for people who are in a group; everyone else never contacts it.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class Push {
  const Push();

  /// This phone's address for nudges; null when push cannot be used (web, a
  /// build without Firebase settings, or no network).
  Future<String?> token() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      // The newer register() hands out an installation ID, which the server's
      // send call is not written for; the token still works.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('push unavailable: $e');
      return null;
    }
  }

  /// Fires when a nudge arrives while the app is open, or is tapped.
  Stream<void> get nudges async* {
    if (Firebase.apps.isEmpty) return;
    yield* FirebaseMessaging.onMessage;
  }
}

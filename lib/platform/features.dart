import 'sms_reader.dart';

/// Which optional capabilities this build has.
class Features {
  /// "sideload" (APK shared directly) or "play" (Google Play build). Set at
  /// build time with --dart-define=STORE=play. Both read bank alerts the same
  /// way (from notifications, never the SMS inbox).
  static const store = String.fromEnvironment(
    'STORE',
    defaultValue: 'sideload',
  );

  /// Reading bank alerts needs Android and the cloud switch (see
  /// remote_flags.dart) not turned off.
  static bool smsReading({required bool remoteFlag}) =>
      SmsReader.supported && remoteFlag;
}

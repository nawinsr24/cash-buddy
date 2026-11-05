import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local (on-device) reminder for the SMS review summary. Every call is
/// defensive: notification problems must never break the app.
class Notifications {
  Notifications._();
  static final instance = Notifications._();
  static const _id = 8001;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool get ready => _ready;

  /// Bumped when the user taps one of our notifications; the shell opens the Inbox.
  final ValueNotifier<int> openInboxRequests = ValueNotifier(0);

  /// Last init/schedule failure, shown to the user instead of failing silently.
  String? lastError;

  Future<void> init() async {
    if (kIsWeb) return; // no local notifications in the browser build
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload == 'inbox') openInboxRequests.value++;
        },
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if ((launch?.didNotificationLaunchApp ?? false) &&
          launch?.notificationResponse?.payload == 'inbox') {
        openInboxRequests.value++;
      }
    } catch (e) {
      debugPrint('Notifications init failed: $e');
      lastError = 'Notifications could not start: $e';
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A real daily reminder at [hour]:[minute]: it repeats every day on its
  /// own, even if the app is never opened again, and whether or not anything
  /// is waiting. [pending] only changes the wording.
  Future<void> scheduleReview(int hour, int minute, int pending) async {
    lastError = null;
    if (!_ready) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
        id: _id,
        title: 'Cash++',
        body: pending > 0
            ? '$pending transaction${pending == 1 ? ' is' : 's are'} waiting. Did you spend anything else today?'
            : 'Did you spend anything today? Add it in 10 seconds.',
        scheduledDate: at,
        payload: pending > 0 ? 'inbox' : 'home',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily reminder',
            channelDescription: 'A daily nudge to note your spending',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      try {
        await go(AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // "Alarms & reminders" not allowed: a slightly less exact alarm still repeats daily
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (e) {
      debugPrint('schedule failed: $e');
      lastError = 'Could not schedule the reminder: $e';
    }
  }

  /// Fires one notification immediately so the user can verify permission works.
  /// Returns null on success, otherwise a human-readable reason.
  Future<String?> testNow() async {
    if (!_ready) {
      return lastError ?? 'Notifications are not available on this device';
    }
    try {
      await _plugin.show(
        id: _id + 1,
        title: 'Cash++',
        body: 'Test: review reminders are working',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sms_review',
            'Transaction review',
            channelDescription:
                'Daily reminder to review detected transactions',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> cancelDailyReview() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}

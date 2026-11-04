import '../data/repo.dart';
import 'notifications.dart';

/// Re-schedules (or cancels) the daily review reminder from current settings
/// and the current number of pending items. Safe to call often.
Future<void> refreshReminder(Repo repo) async {
  final on =
      await repo.getSetting('smsEnabled') == '1' &&
      await repo.getSetting('reminderEnabled') == '1';
  if (!on) {
    await Notifications.instance.cancelDailyReview();
    return;
  }
  final t = (await repo.getSetting('reminderTime') ?? '08:00').split(':');
  await Notifications.instance.scheduleReview(
    int.parse(t[0]),
    int.parse(t[1]),
    await repo.pendingSmsCount(),
  );
}

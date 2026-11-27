import 'package:intl/intl.dart';

import '../data/card_repo.dart';
import '../data/repo.dart';
import '../domain/money.dart';
import 'notifications.dart';

/// Re-makes the credit card bill reminders: 3 days before each due date and
/// on the day, only for cards that owe something.
Future<void> refreshCardReminders(Repo repo) async {
  final n = Notifications.instance;
  await n.cancelCardDue();
  var slot = 0;
  for (final c in await repo.cardStatuses()) {
    final due = c.nextDue;
    if (due != null && c.toPay > 0 && slot < 30) {
      final amt = Money.format(c.toPay);
      final day = DateFormat('d MMM').format(due);
      await n.scheduleCardDue(
        slot * 2,
        '${c.name}: $amt is due on $day.',
        due.subtract(const Duration(days: 3)),
      );
      await n.scheduleCardDue(
        slot * 2 + 1,
        '${c.name}: $amt is due today.',
        due,
      );
    }
    slot++;
  }
}

/// Re-schedules (or cancels) the daily reminder from current settings. Safe to call often.
Future<void> refreshReminder(Repo repo) async {
  await refreshCardReminders(repo);
  final on = await repo.getSetting('reminderEnabled') == '1';
  if (!on) {
    await Notifications.instance.cancelDailyReview();
    return;
  }
  final t = (await repo.getSetting('reminderTime') ?? '08:00').split(':');
  await Notifications.instance.scheduleReview(
    int.parse(t[0]),
    int.parse(t[1]),
    await repo.getSetting('smsEnabled') == '1'
        ? await repo.pendingSmsCount()
        : 0,
  );
}

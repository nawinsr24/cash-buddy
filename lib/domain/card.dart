import 'dates.dart';
import 'money.dart';

/// Credit card rules. All amounts are minor units; dates are calendar days.

/// The given day of [month], clamped to the month's length (due day 31 in
/// February is the 28th or 29th).
DateTime _dueIn(int year, int month, int day) {
  final last = Dates.daysInMonth(year, month);
  return Dates.day(year, month, day > last ? last : day);
}

/// The most recent due date that is on or before [today].
DateTime latestDueDate(int dueDay, DateTime today) {
  final thisMonth = _dueIn(today.year, today.month, dueDay);
  if (!thisMonth.isAfter(today)) return thisMonth;
  final prev = Dates.addMonths(Dates.day(today.year, today.month, 1), -1);
  return _dueIn(prev.year, prev.month, dueDay);
}

/// The next due date on or after [today].
DateTime nextDueDate(int dueDay, DateTime today) {
  final thisMonth = _dueIn(today.year, today.month, dueDay);
  if (!thisMonth.isBefore(today)) return thisMonth;
  final next = Dates.addMonths(Dates.day(today.year, today.month, 1), 1);
  return _dueIn(next.year, next.month, dueDay);
}

/// Estimated interest on a bill that was not paid in time. Interest starts
/// [graceDays] after the due date. [rateBps] is a percentage x 100 per
/// [period] ('month' or 'year'). Simple interest, no compounding, and a
/// guide only: banks add their own fees and rounding.
int cardInterest({
  required int unpaidBill,
  required int rateBps,
  required String period,
  required int graceDays,
  required DateTime dueDate,
  required DateTime today,
}) {
  if (unpaidBill <= 0 || rateBps <= 0) return 0;
  final start = dueDate.add(Duration(days: graceDays));
  final days = today.difference(start).inDays;
  if (days <= 0) return 0;
  final perDay = rateBps / 10000 / (period == 'year' ? 365 : 30);
  return Money.divRoundHalfEven(
    (unpaidBill * perDay * days * 1000).round(),
    1000,
  );
}

/// What the Cards screen shows for one card.
class CardStatus {
  final String id, name;
  final String? bank, last4;
  final int owed; // spends not yet paid
  final int interest; // estimate, see [cardInterest]
  final int? limit;
  final DateTime? nextDue;
  final bool overdue;
  const CardStatus({
    required this.id,
    required this.name,
    this.bank,
    this.last4,
    required this.owed,
    required this.interest,
    this.limit,
    this.nextDue,
    this.overdue = false,
  });

  /// What it takes to clear the card today.
  int get toPay => owed + interest;

  /// Share of the limit in use, 0 to 1 (0 when no limit was entered).
  double get used =>
      limit == null || limit! <= 0 ? 0 : (owed / limit!).clamp(0.0, 1.0);
}

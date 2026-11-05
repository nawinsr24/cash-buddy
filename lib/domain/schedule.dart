import 'dates.dart';

/// Repeat rule for a recurring investment. This is the familiar calendar /
/// SIP-mandate model (the subset of iCalendar RRULE that matters here):
///
///  * [cycle]     FREQ      daily | weekly | monthly | yearly
///  * [every]     INTERVAL  every N cycles (2 + weekly = fortnightly)
///  * [weekday]   BYDAY     weekly only, 1 = Mon .. 7 = Sun
///  * [monthDay]  BYMONTHDAY monthly only, 1..31 (clamped to month end)
///  * [count]     COUNT     stop after N instalments
///  * [until]     UNTIL     stop after this date (inclusive)
///
/// With neither [count] nor [until] it never ends. Dates are calendar days
/// (UTC midnight, like the rest of the app); [timeOfDay] is only a label used
/// for daily reminders and never shifts a date.
class Schedule {
  final String cycle;
  final int every;
  final DateTime start;
  final int? weekday;
  final int? monthDay;
  final int? count;
  final DateTime? until;
  final String? timeOfDay; // HH:mm, optional, daily only

  const Schedule({
    required this.cycle,
    required this.start,
    this.every = 1,
    this.weekday,
    this.monthDay,
    this.count,
    this.until,
    this.timeOfDay,
  });

  static const cycles = ['daily', 'weekly', 'monthly', 'yearly'];

  /// Why this schedule is invalid, or null when it is fine.
  String? validate() {
    if (!cycles.contains(cycle)) return 'Pick how often it repeats';
    if (every < 1 || every > 999) return 'Repeat interval must be 1 or more';
    if (weekday != null && (weekday! < 1 || weekday! > 7)) {
      return 'Pick a weekday';
    }
    if (monthDay != null && (monthDay! < 1 || monthDay! > 31)) {
      return 'Day of month must be 1 to 31';
    }
    if (count != null && count! < 1) return 'Instalments must be 1 or more';
    if (until != null && until!.isBefore(start)) {
      return 'End date is before the start date';
    }
    return null;
  }

  bool get finite => count != null || until != null;

  /// The k-th (0-based) due date ignoring the end rule.
  DateTime _raw(int k) {
    switch (cycle) {
      case 'daily':
        return start.add(Duration(days: k * every));
      case 'weekly':
        final wd = weekday ?? start.weekday;
        final first = start.add(Duration(days: (wd - start.weekday + 7) % 7));
        return first.add(Duration(days: 7 * every * k));
      case 'monthly':
        final d = monthDay ?? start.day;
        // first occurrence on/after the start date, then step by whole months
        // from that anchor month (so a clamped 28 Feb never drifts later)
        var anchor = DateTime.utc(start.year, start.month, 1);
        final firstThisMonth = _clamp(anchor.year, anchor.month, d);
        if (firstThisMonth.isBefore(start)) {
          anchor = Dates.addMonths(anchor, 1);
        }
        final m = Dates.addMonths(anchor, k * every);
        return _clamp(m.year, m.month, d);
      default: // yearly
        return Dates.addMonths(start, 12 * every * k);
    }
  }

  static DateTime _clamp(int y, int m, int d) {
    final last = Dates.daysInMonth(y, m);
    return DateTime.utc(y, m, d > last ? last : d);
  }

  /// k-th due date, or null when past the end of the schedule.
  DateTime? at(int k) {
    if (k < 0) return null;
    if (count != null && k >= count!) return null;
    final d = _raw(k);
    if (until != null && d.isAfter(until!)) return null;
    return d;
  }

  /// Total instalments when the schedule is finite, otherwise null.
  int? get total {
    if (!finite) return null;
    if (until == null) return count;
    var n = 0;
    while (n < 20000 && at(n) != null) {
      n++;
    }
    return n;
  }

  /// How many instalments fall on or before [day].
  int dueCount(DateTime day) {
    var n = 0;
    while (n < 20000) {
      final d = at(n);
      if (d == null || d.isAfter(day)) break;
      n++;
    }
    return n;
  }

  /// Due dates from index [from], at most [limit], stopping at the end rule.
  List<DateTime> upcoming({int from = 0, int limit = 3}) {
    final out = <DateTime>[];
    for (var k = from; out.length < limit; k++) {
      final d = at(k);
      if (d == null) break;
      out.add(d);
    }
    return out;
  }

  /// Human summary, e.g. "Every month on the 5th".
  String describe() {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String ord(int n) {
      if (n >= 11 && n <= 13) return '${n}th';
      return switch (n % 10) {
        1 => '${n}st',
        2 => '${n}nd',
        3 => '${n}rd',
        _ => '${n}th',
      };
    }

    final n = every;
    final unit = switch (cycle) {
      'daily' => n == 1 ? 'day' : '$n days',
      'weekly' => n == 1 ? 'week' : '$n weeks',
      'monthly' => n == 1 ? 'month' : '$n months',
      _ => n == 1 ? 'year' : '$n years',
    };
    final where = switch (cycle) {
      'weekly' => ' on ${wd[(weekday ?? start.weekday) - 1]}',
      'monthly' => ' on the ${ord(monthDay ?? start.day)}',
      'daily' => timeOfDay == null ? '' : ' at $timeOfDay',
      _ => '',
    };
    return 'Every $unit$where';
  }
}

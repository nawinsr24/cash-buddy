/// Business dates are stored as `YYYY-MM-DD` strings (local calendar day).
/// Internally we use UTC midnight DateTimes so DST never shifts a day.
class Dates {
  Dates._();

  static DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

  static DateTime fromLocal(DateTime t) => DateTime.utc(t.year, t.month, t.day);

  static DateTime today() => fromLocal(DateTime.now());

  static String str(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime parse(String s) {
    final p = s.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static int daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  /// Adds whole months, clamping the day (Jan 31 + 1 month = Feb 28/29).
  /// Always computed from the anchor so clamping never accumulates.
  static DateTime addMonths(DateTime anchor, int months) {
    final total = anchor.year * 12 + (anchor.month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final d = anchor.day > daysInMonth(y, m) ? daysInMonth(y, m) : anchor.day;
    return DateTime.utc(y, m, d);
  }
}

/// Inclusive date range.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  String get startStr => Dates.str(start);
  String get endStr => Dates.str(end);
  int get days => end.difference(start).inDays + 1;

  /// The immediately preceding range of equal length (or previous calendar
  /// month if this range is exactly a calendar month).
  DateRange get previous {
    final isMonth =
        start.day == 1 &&
        end ==
            Dates.day(
              start.year,
              start.month,
              Dates.daysInMonth(start.year, start.month),
            );
    if (isMonth) {
      final ps = Dates.addMonths(start, -1);
      return DateRange(
        ps,
        Dates.day(ps.year, ps.month, Dates.daysInMonth(ps.year, ps.month)),
      );
    }
    final prevEnd = start.subtract(const Duration(days: 1));
    return DateRange(prevEnd.subtract(Duration(days: days - 1)), prevEnd);
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);

  static DateRange thisMonth([DateTime? now]) {
    final t = Dates.fromLocal(now ?? DateTime.now());
    return DateRange(
      Dates.day(t.year, t.month, 1),
      Dates.day(t.year, t.month, Dates.daysInMonth(t.year, t.month)),
    );
  }

  static DateRange lastMonth([DateTime? now]) {
    final t = thisMonth(now).start;
    final p = Dates.addMonths(t, -1);
    return DateRange(
      p,
      Dates.day(p.year, p.month, Dates.daysInMonth(p.year, p.month)),
    );
  }

  static DateRange lastDays(int n, [DateTime? now]) {
    final t = Dates.fromLocal(now ?? DateTime.now());
    return DateRange(t.subtract(Duration(days: n - 1)), t);
  }

  static DateRange thisQuarter([DateTime? now]) {
    final t = Dates.fromLocal(now ?? DateTime.now());
    final qStartMonth = ((t.month - 1) ~/ 3) * 3 + 1;
    final s = Dates.day(t.year, qStartMonth, 1);
    final e = Dates.addMonths(s, 3).subtract(const Duration(days: 1));
    return DateRange(s, e);
  }

  static DateRange thisYear([DateTime? now]) {
    final t = Dates.fromLocal(now ?? DateTime.now());
    return DateRange(Dates.day(t.year, 1, 1), Dates.day(t.year, 12, 31));
  }
}

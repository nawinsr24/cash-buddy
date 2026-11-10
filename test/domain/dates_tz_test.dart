import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

// Run under several timezones (see tool/check_timezones.sh): business dates
// are calendar days, so they must never move with the phone's timezone or
// with daylight-saving changes.
void main() {
  test('a local moment maps to the same calendar day at any hour', () {
    for (final h in [0, 1, 2, 3, 12, 22, 23]) {
      final d = Dates.fromLocal(DateTime(2026, 3, 8, h, 30));
      expect(Dates.str(d), '2026-03-08', reason: 'hour $h');
    }
  });

  test('months have the right length across daylight-saving changes', () {
    // US spring forward (Mar 8 2026), EU (Mar 29), US fall back (Nov 1)
    for (final m in [3, 10, 11]) {
      final r = DateRange(
        Dates.day(2026, m, 1),
        Dates.day(2026, m, Dates.daysInMonth(2026, m)),
      );
      expect(r.days, Dates.daysInMonth(2026, m));
    }
    expect(DateRange(Dates.day(2026, 3, 1), Dates.day(2026, 3, 31)).days, 31);
    expect(DateRange(Dates.day(2026, 11, 1), Dates.day(2026, 11, 30)).days, 30);
  });

  test('adding months and days never drifts by a day', () {
    final jan31 = Dates.day(2026, 1, 31);
    expect(Dates.str(Dates.addMonths(jan31, 1)), '2026-02-28');
    expect(Dates.str(Dates.addMonths(jan31, 2)), '2026-03-31');
    final start = Dates.day(2026, 3, 7);
    expect(Dates.str(start.add(const Duration(days: 2))), '2026-03-09');
    expect(
      Dates.str(Dates.day(2026, 11, 1).subtract(const Duration(days: 1))),
      '2026-10-31',
    );
  });

  test('parse and format round-trip', () {
    for (final s in ['2026-03-08', '2026-11-01', '2027-02-28']) {
      expect(Dates.str(Dates.parse(s)), s);
    }
  });
}

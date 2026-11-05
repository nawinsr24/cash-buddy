import 'package:cash_buddy/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  test('daily every day and every 3 days', () {
    final s = Schedule(cycle: 'daily', start: d(2026, 1, 30));
    expect(s.upcoming(limit: 3), [
      d(2026, 1, 30),
      d(2026, 1, 31),
      d(2026, 2, 1),
    ]);
    final t = Schedule(cycle: 'daily', every: 3, start: d(2026, 2, 27));
    expect(t.upcoming(limit: 3), [
      d(2026, 2, 27),
      d(2026, 3, 2),
      d(2026, 3, 5),
    ]);
  });

  test('weekly lands on the chosen weekday on/after the start', () {
    // 2026-11-05 is a Thursday; pick Monday (1)
    final s = Schedule(cycle: 'weekly', start: d(2026, 11, 5), weekday: 1);
    expect(s.upcoming(limit: 3), [
      d(2026, 11, 9),
      d(2026, 11, 16),
      d(2026, 11, 23),
    ]);
    // same weekday as start keeps the start date
    final t = Schedule(cycle: 'weekly', start: d(2026, 11, 5), weekday: 4);
    expect(t.at(0), d(2026, 11, 5));
    // fortnightly
    final f = Schedule(
      cycle: 'weekly',
      every: 2,
      start: d(2026, 11, 5),
      weekday: 4,
    );
    expect(f.upcoming(limit: 3), [
      d(2026, 11, 5),
      d(2026, 11, 19),
      d(2026, 12, 3),
    ]);
  });

  test('monthly: day-of-month, clamped to month end, never drifts', () {
    final s = Schedule(cycle: 'monthly', start: d(2026, 1, 31));
    expect(s.upcoming(limit: 4), [
      d(2026, 1, 31),
      d(2026, 2, 28),
      d(2026, 3, 31), // back to 31, not stuck on 28
      d(2026, 4, 30),
    ]);
    // chosen day earlier than the start day: first one is next month
    final t = Schedule(cycle: 'monthly', start: d(2026, 11, 20), monthDay: 5);
    expect(t.upcoming(limit: 2), [d(2026, 12, 5), d(2027, 1, 5)]);
    // chosen day later than the start day: first one is this month
    final u = Schedule(cycle: 'monthly', start: d(2026, 11, 3), monthDay: 5);
    expect(u.at(0), d(2026, 11, 5));
    // every 3 months (quarterly), across a year end
    final q = Schedule(cycle: 'monthly', every: 3, start: d(2026, 11, 10));
    expect(q.upcoming(limit: 3), [
      d(2026, 11, 10),
      d(2027, 2, 10),
      d(2027, 5, 10),
    ]);
  });

  test('yearly keeps the date, 29 Feb falls back to 28 Feb', () {
    final s = Schedule(cycle: 'yearly', start: d(2024, 2, 29));
    expect(s.upcoming(limit: 3), [
      d(2024, 2, 29),
      d(2025, 2, 28),
      d(2026, 2, 28),
    ]);
    final t = Schedule(cycle: 'yearly', start: d(2026, 4, 1));
    expect(t.at(2), d(2028, 4, 1));
  });

  test('count ends the schedule; total and due counts agree', () {
    final s = Schedule(cycle: 'monthly', start: d(2026, 1, 15), count: 12);
    expect(s.total, 12);
    expect(s.at(11), d(2026, 12, 15));
    expect(s.at(12), isNull);
    expect(s.dueCount(d(2026, 3, 14)), 2);
    expect(s.dueCount(d(2026, 3, 15)), 3);
    expect(s.dueCount(d(2030, 1, 1)), 12);
    expect(s.dueCount(d(2025, 12, 31)), 0);
  });

  test('until is inclusive; whichever of count/until comes first wins', () {
    final s = Schedule(
      cycle: 'weekly',
      start: d(2026, 11, 5),
      weekday: 4,
      until: d(2026, 11, 26),
    );
    expect(s.total, 4); // 5, 12, 19, 26
    final both = Schedule(
      cycle: 'daily',
      start: d(2026, 11, 1),
      count: 10,
      until: d(2026, 11, 4),
    );
    expect(both.total, 4);
    final other = Schedule(
      cycle: 'daily',
      start: d(2026, 11, 1),
      count: 2,
      until: d(2026, 12, 31),
    );
    expect(other.total, 2);
  });

  test('open-ended schedule has no total but still lists upcoming', () {
    final s = Schedule(cycle: 'monthly', start: d(2026, 11, 5));
    expect(s.finite, isFalse);
    expect(s.total, isNull);
    expect(s.upcoming(limit: 3).length, 3);
  });

  test('validation', () {
    expect(
      Schedule(cycle: 'hourly', start: d(2026, 1, 1)).validate(),
      isNotNull,
    );
    expect(
      Schedule(cycle: 'daily', start: d(2026, 1, 1), every: 0).validate(),
      isNotNull,
    );
    expect(
      Schedule(cycle: 'weekly', start: d(2026, 1, 1), weekday: 8).validate(),
      isNotNull,
    );
    expect(
      Schedule(cycle: 'monthly', start: d(2026, 1, 1), monthDay: 32).validate(),
      isNotNull,
    );
    expect(
      Schedule(
        cycle: 'daily',
        start: d(2026, 1, 5),
        until: d(2026, 1, 1),
      ).validate(),
      isNotNull,
    );
    expect(
      Schedule(cycle: 'daily', start: d(2026, 1, 1), count: 0).validate(),
      isNotNull,
    );
    expect(
      Schedule(cycle: 'monthly', start: d(2026, 1, 1), count: 6).validate(),
      isNull,
    );
  });

  test('describe reads naturally', () {
    expect(
      Schedule(cycle: 'monthly', start: d(2026, 1, 1), monthDay: 5).describe(),
      'Every month on the 5th',
    );
    expect(
      Schedule(cycle: 'monthly', start: d(2026, 1, 1), monthDay: 22).describe(),
      'Every month on the 22nd',
    );
    expect(
      Schedule(cycle: 'weekly', start: d(2026, 11, 5), weekday: 1).describe(),
      'Every week on Mon',
    );
    expect(
      Schedule(cycle: 'weekly', every: 2, start: d(2026, 11, 5)).describe(),
      'Every 2 weeks on Thu',
    );
    expect(
      Schedule(
        cycle: 'daily',
        start: d(2026, 1, 1),
        timeOfDay: '09:30',
      ).describe(),
      'Every day at 09:30',
    );
    expect(
      Schedule(cycle: 'yearly', start: d(2026, 1, 1)).describe(),
      'Every year',
    );
  });
}

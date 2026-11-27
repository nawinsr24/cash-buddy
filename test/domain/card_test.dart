import 'package:cash_buddy/domain/card.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('due dates', () {
    test('latest and next due date around today', () {
      final today = Dates.day(2026, 11, 4);
      expect(Dates.str(latestDueDate(25, today)), '2026-10-25');
      expect(Dates.str(nextDueDate(25, today)), '2026-11-25');
      // on the due day itself
      final d = Dates.day(2026, 11, 25);
      expect(Dates.str(latestDueDate(25, d)), '2026-11-25');
      expect(Dates.str(nextDueDate(25, d)), '2026-11-25');
    });

    test('day 31 in a short month falls on its last day', () {
      final feb = Dates.day(2027, 2, 10);
      expect(Dates.str(nextDueDate(31, feb)), '2027-02-28');
      expect(Dates.str(latestDueDate(31, feb)), '2027-01-31');
      expect(Dates.str(nextDueDate(30, Dates.day(2028, 2, 1))), '2028-02-29');
    });

    test('year boundary', () {
      expect(Dates.str(latestDueDate(20, Dates.day(2027, 1, 5))), '2026-12-20');
      expect(Dates.str(nextDueDate(20, Dates.day(2026, 12, 28))), '2027-01-20');
    });
  });

  group('interest estimate', () {
    final due = Dates.day(2026, 10, 25);
    int calc({
      int bill = 1000000,
      int bps = 350,
      String period = 'month',
      int grace = 0,
      DateTime? today,
    }) => cardInterest(
      unpaidBill: bill,
      rateBps: bps,
      period: period,
      graceDays: grace,
      dueDate: due,
      today: today ?? Dates.day(2026, 11, 4),
    );

    test('monthly rate: 3.5% a month for 10 days overdue', () {
      // 10,000.00 x 3.5% / 30 x 10 = 116.67
      expect(calc(), 11667);
    });

    test('yearly rate: 42% a year is 3.5% a month on a 365-day basis', () {
      // 10,000.00 x 42% / 365 x 10 = 115.07
      expect(calc(bps: 4200, period: 'year'), 11507);
    });

    test('nothing until the days after the due date have passed', () {
      expect(calc(today: Dates.day(2026, 10, 25)), 0); // on the due day
      expect(
        calc(grace: 5, today: Dates.day(2026, 10, 30)),
        0,
      ); // last free day
      expect(calc(grace: 5, today: Dates.day(2026, 10, 31)), isPositive);
    });

    test('grace days shift when interest starts', () {
      final noGrace = calc();
      final grace3 = calc(grace: 3); // 7 days instead of 10
      expect(grace3, lessThan(noGrace));
      expect(grace3, 8167);
    });

    test('no bill or no rate means no interest', () {
      expect(calc(bill: 0), 0);
      expect(calc(bps: 0), 0);
    });
  });

  test('status helpers', () {
    const c = CardStatus(
      id: 'c',
      name: 'HDFC',
      owed: 100000,
      interest: 5000,
      limit: 400000,
    );
    expect(c.toPay, 105000);
    expect(c.used, 0.25);
    expect(const CardStatus(id: 'c', name: 'x', owed: 5, interest: 0).used, 0);
  });
}

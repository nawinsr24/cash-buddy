import 'dart:math';

import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('half-even rounding', () {
      expect(Money.divRoundHalfEven(5, 2), 2); // 2.5 -> 2
      expect(Money.divRoundHalfEven(7, 2), 4); // 3.5 -> 4
      expect(Money.divRoundHalfEven(-5, 2), -2);
      expect(Money.divRoundHalfEven(-7, 2), -4);
      expect(Money.divRoundHalfEven(10, 3), 3);
      expect(Money.divRoundHalfEven(11, 3), 4);
      expect(Money.divRoundHalfEven(-11, 3), -4);
      expect(Money.divRoundHalfEven(6, -3), -2);
    });
    test('rounding is within 1 of exact for random inputs', () {
      final r = Random(1);
      for (var i = 0; i < 2000; i++) {
        final n = r.nextInt(2000000) - 1000000;
        final d = r.nextInt(999) + 1;
        final q = Money.divRoundHalfEven(n, d);
        expect((q * d - n).abs() * 2 <= d, isTrue, reason: '$n/$d=$q');
      }
    });
    test('percentBps', () {
      expect(Money.percentBps(100000, 200), 2000); // 2% of 1000.00
      expect(Money.percentBps(12345, 150), 185); // 185.175 -> 185
    });
    test('parse', () {
      expect(Money.parse('1,234.5'), 123450);
      expect(Money.parse('₹ 99'), 9900);
      expect(Money.parse('0.05'), 5);
      expect(Money.parse('12.345'), isNull);
      expect(Money.parse('-5'), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse(''), isNull);
    });
    test('format', () {
      expect(Money.format(123456), '₹1,234.56');
      expect(Money.format(-500), '-₹5.00');
      expect(Money.format(1234567890), '₹1,23,45,678.90'); // Indian grouping
    });
  });

  group('Dates', () {
    test('addMonths clamps and does not accumulate', () {
      final jan31 = Dates.day(2025, 1, 31);
      expect(Dates.addMonths(jan31, 1), Dates.day(2025, 2, 28));
      expect(Dates.addMonths(jan31, 2), Dates.day(2025, 3, 31));
      expect(
        Dates.addMonths(Dates.day(2024, 1, 31), 1),
        Dates.day(2024, 2, 29),
      );
      expect(Dates.addMonths(jan31, -2), Dates.day(2024, 11, 30));
    });
    test('ranges', () {
      final now = DateTime(2026, 11, 4);
      expect(DateRange.thisMonth(now).startStr, '2026-11-01');
      expect(DateRange.thisMonth(now).endStr, '2026-11-30');
      expect(DateRange.lastMonth(now).startStr, '2026-10-01');
      expect(DateRange.lastMonth(now).endStr, '2026-10-31');
      expect(DateRange.lastMonth(DateTime(2026, 1, 15)).startStr, '2025-12-01');
      expect(DateRange.thisQuarter(now).startStr, '2026-10-01');
      expect(DateRange.thisQuarter(now).endStr, '2026-12-31');
      expect(DateRange.lastDays(7, now).startStr, '2026-10-29');
      expect(DateRange.thisMonth(now).previous, DateRange.lastMonth(now));
      final custom = DateRange(
        Dates.day(2026, 11, 10),
        Dates.day(2026, 11, 19),
      );
      expect(custom.previous.startStr, '2026-10-31');
      expect(custom.previous.endStr, '2026-11-09');
    });
  });
}

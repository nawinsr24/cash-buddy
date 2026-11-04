import 'dart:math';

import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/interest.dart';
import 'package:flutter_test/flutter_test.dart';

DebtTerms terms({
  int p = 100000, // 1000.00
  bool interest = true,
  InterestType type = InterestType.simple,
  int bps = 200,
  RatePeriod per = RatePeriod.monthly,
  DateTime? on,
}) => DebtTerms(
  principalMinor: p,
  issuedOn: on ?? Dates.day(2026, 1, 15),
  interestEnabled: interest,
  interestType: type,
  rateBps: bps,
  ratePeriod: per,
);

void main() {
  test('interest-free debt accrues nothing', () {
    final s = InterestEngine.replay(
      terms(interest: false),
      [],
      Dates.day(2030, 1, 1),
    );
    expect(s.accruals, isEmpty);
    expect(s.outstanding, 100000);
  });

  test('simple monthly 2%: 3 months = 3 x 20.00', () {
    final s = InterestEngine.replay(terms(), [], Dates.day(2026, 4, 15));
    expect(s.accruals.map((a) => a.amountMinor), [2000, 2000, 2000]);
    expect(s.interestOutstanding, 6000);
    expect(s.outstanding, 106000);
  });

  test('no accrual before a full period elapses', () {
    final s = InterestEngine.replay(terms(), [], Dates.day(2026, 2, 14));
    expect(s.accruals, isEmpty);
  });

  test('compound monthly 2% compounds on unpaid interest', () {
    final s = InterestEngine.replay(
      terms(type: InterestType.compound),
      [],
      Dates.day(2026, 4, 15),
    );
    expect(s.accruals.map((a) => a.amountMinor), [
      2000,
      2040,
      2081,
    ]); // 2080.8 -> 2081
    expect(s.outstanding, 100000 + 2000 + 2040 + 2081);
  });

  test('partial repayment goes to interest first, then principal', () {
    final pay = DebtPayment('r1', Dates.day(2026, 3, 20), 5000);
    final s = InterestEngine.replay(terms(), [pay], Dates.day(2026, 3, 20));
    // two accruals of 20.00 by Mar 15 -> 40.00 interest; 50.00 pays 40 interest + 10 principal
    expect(s.allocations['r1']!.interestMinor, 4000);
    expect(s.allocations['r1']!.principalMinor, 1000);
    expect(s.principalOutstanding, 99000);
    expect(s.interestOutstanding, 0);
  });

  test('simple interest base shrinks after principal repayment', () {
    final pay = DebtPayment(
      'r1',
      Dates.day(2026, 2, 20),
      50000,
    ); // 20 int + 480 principal
    final s = InterestEngine.replay(terms(), [pay], Dates.day(2026, 3, 15));
    expect(s.accruals.map((a) => a.amountMinor), [2000, 1040]); // 2% of 520.00
  });

  test('payment on a boundary date is applied after that period accrues', () {
    final pay = DebtPayment('r1', Dates.day(2026, 2, 15), 2000);
    final s = InterestEngine.replay(terms(), [pay], Dates.day(2026, 2, 15));
    expect(s.accruals.single.amountMinor, 2000);
    expect(s.allocations['r1']!.interestMinor, 2000);
    expect(s.outstanding, 100000);
  });

  test('overpayment is reported as excess', () {
    final pay = DebtPayment('r1', Dates.day(2026, 1, 20), 150000);
    final s = InterestEngine.replay(terms(interest: false), [
      pay,
    ], Dates.day(2026, 1, 20));
    expect(s.allocations['r1']!.excessMinor, 50000);
  });

  test('payments after asOf are ignored (as-of semantics)', () {
    final pay = DebtPayment('r1', Dates.day(2026, 6, 1), 100000);
    final s = InterestEngine.replay(terms(interest: false), [
      pay,
    ], Dates.day(2026, 3, 1));
    expect(s.outstanding, 100000);
    expect(s.allocations, isEmpty);
  });

  test('settled debt stops accruing', () {
    final pay = DebtPayment('r1', Dates.day(2026, 2, 16), 102000);
    final s = InterestEngine.replay(terms(), [pay], Dates.day(2027, 1, 1));
    expect(s.outstanding, 0);
    expect(s.accruals.length, 1);
  });

  test('month-end anchor never drifts (Jan 31)', () {
    final t = terms(on: Dates.day(2026, 1, 31));
    expect(InterestEngine.periodEnd(t, 1), Dates.day(2026, 2, 28));
    expect(InterestEngine.periodEnd(t, 2), Dates.day(2026, 3, 31));
  });

  test('weekly / daily / yearly periods', () {
    final w = InterestEngine.replay(
      terms(per: RatePeriod.weekly),
      [],
      Dates.day(2026, 1, 29),
    );
    expect(w.accruals.length, 2);
    final d = InterestEngine.replay(
      terms(per: RatePeriod.daily, bps: 10),
      [],
      Dates.day(2026, 1, 20),
    );
    expect(d.accruals.length, 5);
    final y = InterestEngine.replay(
      terms(per: RatePeriod.yearly, bps: 1200),
      [],
      Dates.day(2028, 1, 15),
    );
    expect(y.accruals.map((a) => a.amountMinor), [12000, 12000]);
  });

  test('replay is deterministic and conserves money (property test)', () {
    final r = Random(42);
    for (var i = 0; i < 300; i++) {
      final t = terms(
        p: 1000 + r.nextInt(5000000),
        type: r.nextBool() ? InterestType.simple : InterestType.compound,
        bps: r.nextInt(500),
        per: RatePeriod.values[r.nextInt(4)],
      );
      final pays = List.generate(
        r.nextInt(5),
        (j) => DebtPayment(
          'p$j',
          t.issuedOn.add(Duration(days: r.nextInt(400))),
          1 + r.nextInt(300000),
        ),
      );
      final asOf = t.issuedOn.add(Duration(days: r.nextInt(900)));
      final a = InterestEngine.replay(t, pays, asOf);
      final b = InterestEngine.replay(t, pays, asOf);
      expect(a.outstanding, b.outstanding);
      expect(a.accruals.length, b.accruals.length);
      // conservation: principal + accrued - paid == outstanding (excess excluded)
      final applied = a.allocations.values.fold<int>(
        0,
        (s, x) => s + x.interestMinor + x.principalMinor,
      );
      expect(t.principalMinor + a.totalAccrued - applied, a.outstanding);
      expect(a.principalOutstanding >= 0 && a.interestOutstanding >= 0, isTrue);
    }
  });
}

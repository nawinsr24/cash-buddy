import 'package:cash_buddy/data/loan_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/loan.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sync/sync_test.dart' show dev, dump, syncAll;
import 'helpers.dart';

final _range = DateRange.thisMonth(DateTime(2026, 11, 4));

/// ₹5,00,000 at 9% for 60 months.
Future<String> _loan(Repo r, {bool full = true}) => r.addLoan(
  kind: 'car',
  lender: 'HDFC',
  owed: 50000000,
  annualMilli: 9000,
  months: 60,
  emiDay: 5,
  emiInBudget: full,
);

Future<(int balance, int spending, int income)> _state(Repo r) async {
  final d = await r.dashboard(_range);
  return (await r.totalBalance(), d.spending, d.income);
}

void main() {
  test('the example matches hand-checked figures', () {
    expect(emiFor(50000000, 9000, 60), 1037918);
    expect(monthlyInterest(50000000, 9000), 375000);
    final s = scheduleFor(50000000, 9000, 1037918)!;
    expect(s.length, 60);
    expect(s.last.balance, 0);
    expect(s.fold<int>(0, (a, i) => a + i.principal), 50000000);
  });

  test('every schedule ends at exactly zero', () {
    for (final owed in [100000, 12345678, 750000000]) {
      for (final rate in [0, 8500, 14250, 36000]) {
        for (final months in [1, 7, 36, 240]) {
          final emi = emiFor(owed, rate, months);
          final s = scheduleFor(owed, rate, emi)!;
          final why = '$owed $rate $months';
          // Tiny loans over many years can finish early through rounding.
          if (owed > 10000000 || months <= 36) {
            expect(s.length, months, reason: why);
          } else {
            expect(s.length, lessThanOrEqualTo(months), reason: why);
          }
          expect(s.last.balance, 0);
          expect(s.fold<int>(0, (a, i) => a + i.principal), owed);
        }
      }
    }
    expect(scheduleFor(1000000, 12000, 10000), isNull);
  });

  test('adding a running loan does not move the balance', () async {
    final e = await newEnv(opening: 100000000);
    final id = await _loan(e.repo);
    expect(await _state(e.repo), (100000000, 0, 0));
    final l = await e.repo.loanStatus(id);
    expect((l.owed, l.emi, l.monthsLeft), (50000000, 1037918, 60));
  });

  test('an EMI moves the full amount; budget follows the choice', () async {
    final e = await newEnv(opening: 100000000);
    final id = await _loan(e.repo);
    final before = await e.repo.loanStatus(id);
    final pay = await e.repo.payEmi(
      id,
      interest: before.nextInterest,
      principal: before.nextPrincipal,
    );
    expect(await _state(e.repo), (98962082, 1037918, 0));
    await e.repo.setEmiInBudget(id, false);
    expect(await _state(e.repo), (98962082, 375000, 0));
    final l = await e.repo.loanStatus(id);
    expect(l.owed, 49337082);
    expect(l.interestPaid, 375000);
    expect(l.monthsLeft, 59);
    expect(l.nextDue(e.repo.today), Dates.day(2026, 12, 5));
    await e.repo.deleteDebtEvent(pay);
    expect(await _state(e.repo), (100000000, 0, 0));
    expect((await e.repo.loanStatus(id)).interestPaid, 0);
  });

  test('part payment shortens the term or lowers the EMI', () async {
    final e = await newEnv(opening: 100000000);
    final a = await _loan(e.repo);
    await e.repo.partPay(a, 10000000, shorterTerm: true);
    final shorter = await e.repo.loanStatus(a);
    expect((shorter.owed, shorter.emi), (40000000, 1037918));
    expect(shorter.monthsLeft, lessThan(60));

    final b = await _loan(e.repo);
    final undo = await e.repo.partPay(b, 10000000, shorterTerm: false);
    final lower = await e.repo.loanStatus(b);
    expect(lower.emi, emiFor(40000000, 9000, 60));
    expect(lower.monthsLeft, 60);
    // extra payments are not monthly spending
    expect((await _state(e.repo)).$2, 0);
    await e.repo.deleteDebtEvent(undo);
    expect((await e.repo.loanStatus(b)).emi, 1037918);
  });

  test('a rate change applies from its date', () async {
    final e = await newEnv();
    final id = await _loan(e.repo);
    await e.repo.changeLoanRate(
      id,
      8500,
      from: Dates.day(2026, 12, 1),
      keepEmi: false,
    );
    expect((await e.repo.loanStatus(id)).annualMilli, 9000);
    e.clockNow = DateTime(2026, 12, 2, 10);
    final l = await e.repo.loanStatus(id);
    expect(l.annualMilli, 8500);
    expect(l.emi, emiFor(50000000, 8500, 60));
  });

  test('preclosing adds up and closes the loan', () async {
    final p = preclosureFor(
      owed: 30000000,
      annualMilli: 10000,
      emi: 1000000,
      days: 10,
      penaltyBps: 200,
      taxBps: 1800,
    );
    expect((p.penalty, p.tax, p.interest), (600000, 108000, 82192));
    expect(p.total, 30000000 + 82192 + 600000 + 108000);
    expect(p.saving, p.interestAvoided - 82192 - 708000);

    final e = await newEnv(opening: 100000000);
    final id = await _loan(e.repo);
    await e.repo.precloseLoan(id, interest: 50000, charges: 708000);
    expect(await _state(e.repo), (100000000 - 50758000, 758000, 0));
    final l = await e.repo.loanStatus(id);
    expect((l.owed, l.monthsLeft), (0, 0));
  });

  test('paying more principal than is owed is refused', () async {
    final e = await newEnv();
    final id = await _loan(e.repo);
    await expectLater(
      e.repo.payEmi(id, interest: 100, principal: 60000000),
      throwsA(isA<ValidationException>()),
    );
    expect((await e.repo.loanStatus(id)).history.length, 1);
  });

  test('a loan and its payments reach the other device', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    final id = await _loan(a.repo);
    await a.repo.partPay(id, 10000000, shorterTerm: false);
    await syncAll([a, b]);
    expect(await dump(b.repo), await dump(a.repo));
    await b.repo.payEmi(id, interest: 300000, principal: 500000);
    await syncAll([a, b]);
    expect((await a.repo.loanStatus(id)).owed, 39500000);
    expect(await dump(b.repo), await dump(a.repo));
  });
}

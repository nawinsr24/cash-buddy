import 'package:cash_buddy/data/repo.dart' show ValidationException;
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // newEnv clock: 4 Nov 2026
  test('lent 1,00,000 at 2% per month: interest each full month, shown in the dashboard', () async {
    final e = await newEnv(opening: 50000000);
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'Ravi',
      principalMinor: 10000000,
      issuedOn: Dates.day(2026, 8, 4), // 3 full months before 4 Nov
      interestEnabled: true,
      rateBps: 200,
      ratePeriod: 'monthly',
      interestType: 'simple',
      accountId: 'acc_overall',
    );
    final st = await r.debtState(id);
    expect(st.principalOutstanding, 10000000);
    expect(st.totalAccrued, 600000); // 3 x 2,000
    expect(st.interestOutstanding, 600000);
    expect(st.outstanding, 10600000);
    // dashboard: Incoming Debts = what is still to come in
    final dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.incomingDebts, 10600000);
    expect(dash.incomingPrincipal, 10000000);
    expect(dash.incomingInterest, 600000);
    // lending reduced the balance once (principal only)
    expect(await r.totalBalance(), 50000000 - 10000000);
    expect(await r.checkInvariants(), isEmpty);
  });

  test('receiving interest only keeps the principal; it counts as income, principal does not', () async {
    final e = await newEnv(opening: 50000000);
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'Ravi',
      principalMinor: 10000000,
      issuedOn: Dates.day(2026, 8, 4),
      interestEnabled: true,
      rateBps: 200,
      accountId: 'acc_overall',
    );
    await r.addRepayment(
      id,
      600000,
      date: Dates.day(2026, 11, 4),
    ); // exactly the interest
    final st = await r.debtState(id);
    expect(st.interestOutstanding, 0);
    expect(st.principalOutstanding, 10000000);
    final dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.income, 600000); // interest received is income
    expect(dash.incomingDebts, 10000000);
    expect(await r.totalBalance(), 50000000 - 10000000 + 600000);
  });

  Future<(TestEnv, String)> lent({String direction = 'receivable'}) async {
    final e = await newEnv(opening: 50000000);
    final id = await e.repo.createDebt(
      direction: direction,
      counterparty: 'Ravi',
      principalMinor: 10000000,
      issuedOn: Dates.day(2026, 8, 4),
      interestEnabled: true,
      rateBps: 200,
      accountId: 'acc_overall',
    );
    return (e, id);
  }

  test('principal-only payment leaves the interest owed and shrinks future interest', () async {
    final (e, id) = await lent();
    final r = e.repo;
    await r.addRepayment(
      id,
      4000000,
      date: Dates.day(2026, 11, 4),
      target: 'principal',
    );
    final st = await r.debtState(id);
    expect(st.principalOutstanding, 6000000);
    expect(st.interestOutstanding, 600000); // untouched
    final dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.incomingDebts, 6600000);
    expect(dash.income, 0); // principal back is not income
    // the next interest is charged on what is left of the principal
    final next = await r.nextInterest(id);
    expect(next!.date, Dates.day(2026, 12, 4));
    expect(next.amountMinor, 120000); // 2% of 60,000
    expect(await r.checkInvariants(), isEmpty);
  });

  test('interest-only payment cannot exceed the interest due, principal-only cannot exceed principal', () async {
    final (e, id) = await lent();
    final r = e.repo;
    expect(
      () => r.addRepayment(
        id,
        700000,
        date: Dates.day(2026, 11, 4),
        target: 'interest',
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => r.addRepayment(
        id,
        10000001,
        date: Dates.day(2026, 11, 4),
        target: 'principal',
      ),
      throwsA(isA<ValidationException>()),
    );
    // nothing changed
    final st = await r.debtState(id);
    expect(st.outstanding, 10600000);
  });

  test(
    'interest paid on money I borrowed is spending; principal repaid is not',
    () async {
      final (e, id) = await lent(direction: 'liability');
      final r = e.repo;
      await r.addRepayment(
        id,
        600000,
        date: Dates.day(2026, 11, 4),
        target: 'interest',
      );
      await r.addRepayment(
        id,
        2000000,
        date: Dates.day(2026, 11, 4),
        target: 'principal',
      );
      final dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
      expect(dash.spending, 600000); // only the interest
      expect(dash.liabilities, 8000000);
      expect(await r.checkInvariants(), isEmpty);
    },
  );

  test('default payment still goes to interest first', () async {
    final (e, id) = await lent();
    await e.repo.addRepayment(id, 1000000, date: Dates.day(2026, 11, 4));
    final st = await e.repo.debtState(id);
    expect(st.interestOutstanding, 0);
    expect(st.principalOutstanding, 9600000);
  });

  test('interest-free debt has no next interest', () async {
    final e = await newEnv(opening: 50000000);
    final id = await e.repo.createDebt(
      direction: 'receivable',
      counterparty: 'Meera',
      principalMinor: 500000,
      issuedOn: Dates.day(2026, 10, 1),
    );
    expect(await e.repo.nextInterest(id), isNull);
  });

  test(
    'a debt issued today shows its first interest one period away',
    () async {
      final e = await newEnv(opening: 50000000);
      final id = await e.repo.createDebt(
        direction: 'receivable',
        counterparty: 'Ravi',
        principalMinor: 10000000,
        issuedOn: e.repo.today,
        interestEnabled: true,
        rateBps: 200,
      );
      final next = await e.repo.nextInterest(id);
      expect(next!.date, Dates.day(2026, 12, 4));
      expect(next.amountMinor, 200000);
      expect((await e.repo.debtState(id)).totalAccrued, 0);
    },
  );
}

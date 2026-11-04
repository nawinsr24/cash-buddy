import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final issued = Dates.day(2026, 8, 4);

  test('lend: debits cash, is NOT spending, raises Incoming Debts', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    await r.createDebt(
      direction: 'receivable',
      counterparty: 'Ravi',
      principalMinor: 200000,
      issuedOn: issued,
    );
    expect(await r.totalBalance(), 800000);
    final d = await r.dashboard(
      DateRange.thisMonth(e.clockNow).previous.previous.previous,
    ); // Aug
    expect(d.spending, 0);
    final now = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(now.spending, 0);
    expect(now.incomingDebts, 200000);
    expect(now.liabilities, 0);
  });

  test('borrow: credits cash, is NOT income, raises Liabilities', () async {
    final e = await newEnv();
    final r = e.repo;
    await r.createDebt(
      direction: 'liability',
      counterparty: 'Bank',
      principalMinor: 500000,
      issuedOn: issued,
    );
    expect(await r.totalBalance(), 500000);
    final d = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(d.income, 0);
    expect(d.liabilities, 500000);
  });

  test('interest-bearing receivable: accrues (non-cash), repay interest-first, interest counts as income only when received', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    // 2% monthly simple on 1000.00 issued 2026-08-04, as of 2026-11-04 => 3 accruals of 20.00
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'Asha',
      principalMinor: 100000,
      issuedOn: issued,
      interestEnabled: true,
      rateBps: 200,
      ratePeriod: 'monthly',
    );
    var st = await r.debtState(id);
    expect(st.interestOutstanding, 6000);
    expect(st.outstanding, 106000);
    // accruals are non-cash: balance only reflects the principal lent
    expect(await r.totalBalance(), 900000);
    var dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.incomeByCategory, isEmpty);
    expect(dash.incomingDebts, 106000);
    expect(dash.incomingInterest, 6000);

    // receive 50.00 on Nov 4 -> all interest first (it has 60.00 accrued): 50 interest, 0 principal
    await r.addRepayment(id, 5000, date: Dates.day(2026, 11, 4));
    expect(await r.totalBalance(), 905000);
    dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.income, 5000); // interest received = income
    expect(dash.incomeByCategory.single.name, 'Interest Income');
    expect(dash.incomingDebts, 101000);

    // receive 600.00: 10 interest + 590 principal; interest is income, principal is not
    await r.addRepayment(id, 60000, date: Dates.day(2026, 11, 4));
    dash = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(dash.income, 5000 + 1000);
    expect(await r.totalBalance(), 965000);
    st = await r.debtState(id);
    expect(st.principalOutstanding, 100000 - 59000);
    expect(st.interestOutstanding, 0);
  });

  test('liability: repaying principal is NOT spending, paying interest IS spending', () async {
    final e = await newEnv();
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'liability',
      counterparty: 'Friend',
      principalMinor: 100000,
      issuedOn: issued,
      interestEnabled: true,
      rateBps: 200,
      ratePeriod: 'monthly',
    );
    expect(await r.totalBalance(), 100000);
    await r.addRepayment(
      id,
      26000,
      date: Dates.day(2026, 11, 4),
    ); // 60 interest + 200 principal
    final d = await r.dashboard(DateRange.thisMonth(e.clockNow));
    expect(d.spending, 6000);
    expect(d.spendingByCategory.single.name, 'Interest Paid');
    expect(await r.totalBalance(), 100000 - 26000);
    expect(d.liabilities, 100000 - 20000);
  });

  test('reconcile is idempotent: repeated runs never duplicate events or ledger rows', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'X',
      principalMinor: 100000,
      issuedOn: issued,
      interestEnabled: true,
      rateBps: 200,
    );
    await r.addRepayment(id, 30000, date: Dates.day(2026, 10, 10));
    Future<(int, int, String)> snap() async {
      final ev = await r.db.select(r.db.debtEvents).get();
      final tx = await r.db.select(r.db.transactions).get();
      return (
        ev.length,
        tx.length,
        ev.map((x) => x.hlc).join() + tx.map((x) => x.hlc).join(),
      );
    }

    final a = await snap();
    for (var i = 0; i < 5; i++) {
      await r.reconcileDebt(id);
      await r.reconcileAllDebts();
    }
    final b = await snap();
    expect(b, a); // same rows AND same versions: no churn
    expect(await r.checkInvariants(), isEmpty);
  });

  test('overpayment is rejected and changes nothing', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'X',
      principalMinor: 100000,
      issuedOn: issued,
    );
    final before = await r.totalBalance();
    await expectLater(
      r.addRepayment(id, 100001, date: Dates.day(2026, 9, 1)),
      throwsA(isA<OverpaymentException>()),
    );
    expect(await r.totalBalance(), before);
    expect(
      (await r.debtTimeline(id)).where((x) => x.type == 'repayment'),
      isEmpty,
    );
  });

  test(
    'full settlement: status settled, dashboard drops it, balance restored',
    () async {
      final e = await newEnv(opening: 1000000);
      final r = e.repo;
      final id = await r.createDebt(
        direction: 'receivable',
        counterparty: 'X',
        principalMinor: 100000,
        issuedOn: issued,
      );
      await r.addRepayment(id, 40000, date: Dates.day(2026, 9, 1));
      var s = (await r.debtSummaries()).single;
      expect(s.status, 'partial');
      await r.addRepayment(id, 60000, date: Dates.day(2026, 9, 2));
      s = (await r.debtSummaries()).single;
      expect(s.status, 'settled');
      expect(await r.totalBalance(), 1000000);
      final d = await r.dashboard(DateRange.thisMonth(e.clockNow));
      expect(d.incomingDebts, 0);
      expect(d.receivables, isEmpty);
    },
  );

  test(
    'deleting a repayment reverses its ledger legs and re-accrues interest',
    () async {
      final e = await newEnv(opening: 1000000);
      final r = e.repo;
      final id = await r.createDebt(
        direction: 'receivable',
        counterparty: 'X',
        principalMinor: 100000,
        issuedOn: issued,
        interestEnabled: true,
        rateBps: 200,
      );
      final before = await r.totalBalance();
      final pay = await r.addRepayment(
        id,
        50000,
        date: Dates.day(2026, 8, 20),
      ); // principal heavy, shrinks base
      expect(await r.totalBalance(), before + 50000);
      final withPay = (await r.debtState(id)).interestOutstanding;
      await r.deleteDebtEvent(pay);
      expect(await r.totalBalance(), before);
      final without = (await r.debtState(id)).interestOutstanding;
      expect(without, 6000);
      expect(withPay < without, isTrue);
      // persisted accruals match the replay
      final persisted = (await r.debtTimeline(id))
          .where((e) => e.type == 'accrual')
          .fold<int>(0, (s, e) => s + e.amountMinor);
      expect(persisted, 6000);
      expect(await r.checkInvariants(), isEmpty);
    },
  );

  test('deleting a debt removes all its ledger postings', () async {
    final e = await newEnv(opening: 1000000);
    final r = e.repo;
    final id = await r.createDebt(
      direction: 'liability',
      counterparty: 'X',
      principalMinor: 100000,
      issuedOn: issued,
    );
    await r.addRepayment(id, 10000, date: Dates.day(2026, 9, 1));
    await r.deleteDebt(id);
    expect(await r.totalBalance(), 1000000);
    expect(await r.debts(), isEmpty);
  });

  test(
    'debt-managed ledger rows cannot be edited or deleted directly',
    () async {
      final e = await newEnv(opening: 1000000);
      final r = e.repo;
      await r.createDebt(
        direction: 'receivable',
        counterparty: 'X',
        principalMinor: 100000,
        issuedOn: issued,
      );
      final t = (await r.searchTransactions(const TxnFilter(source: 'debt')))
          .single;
      expect(
        () => r.deleteTransaction(t.id),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => r.updateTransaction(t.id, amountMinor: 5),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'as-of semantics: dashboard for a past range ignores later repayments',
    () async {
      final e = await newEnv(opening: 1000000);
      final r = e.repo;
      final id = await r.createDebt(
        direction: 'receivable',
        counterparty: 'X',
        principalMinor: 100000,
        issuedOn: issued,
      );
      await r.addRepayment(id, 100000, date: Dates.day(2026, 10, 15));
      final sep = await r.dashboard(
        DateRange(Dates.day(2026, 9, 1), Dates.day(2026, 9, 30)),
      );
      expect(sep.incomingDebts, 100000);
      final nov = await r.dashboard(DateRange.thisMonth(e.clockNow));
      expect(nov.incomingDebts, 0);
    },
  );

  test(
    'time passing accrues more interest on next reconcile (catch-up)',
    () async {
      final e = await newEnv(opening: 1000000);
      final r = e.repo;
      final id = await r.createDebt(
        direction: 'receivable',
        counterparty: 'X',
        principalMinor: 100000,
        issuedOn: issued,
        interestEnabled: true,
        rateBps: 200,
      );
      int accrued() => 0;
      expect(accrued(), 0);
      e.clockNow = DateTime(2027, 2, 4);
      await r.reconcileAllDebts();
      final tl = (await r.debtTimeline(id))
          .where((x) => x.type == 'accrual')
          .toList();
      expect(tl.length, 6); // Sep..Feb
      expect(tl.fold<int>(0, (s, x) => s + x.amountMinor), 12000);
    },
  );

  test('validation', () async {
    final e = await newEnv();
    final r = e.repo;
    expect(
      () => r.createDebt(
        direction: 'receivable',
        counterparty: '',
        principalMinor: 5,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => r.createDebt(
        direction: 'receivable',
        counterparty: 'a',
        principalMinor: 0,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => r.createDebt(
        direction: 'receivable',
        counterparty: 'a',
        principalMinor: 5,
        interestEnabled: true,
        rateBps: 0,
      ),
      throwsA(isA<ValidationException>()),
    );
    final id = await r.createDebt(
      direction: 'receivable',
      counterparty: 'a',
      principalMinor: 100,
      issuedOn: issued,
    );
    expect(
      () => r.addRepayment(id, 10, date: Dates.day(2026, 1, 1)),
      throwsA(isA<ValidationException>()),
    );
  });
}

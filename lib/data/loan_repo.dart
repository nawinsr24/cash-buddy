import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/loan.dart';
import 'db.dart';
import 'repo.dart';

/// An EMI loan as it stands today. A loan is a liability whose interest is
/// recorded when each EMI is paid, as the bank statement shows it.
class LoanStatus {
  final Debt debt;
  final int owed, annualMilli, emi, interestPaid;
  final DateTime lastPaid;

  /// The date of the latest EMI recorded, to avoid asking for it again.
  final DateTime? lastEmi;
  final List<Instalment>? schedule;
  final List<DebtEvent> history;
  const LoanStatus({
    required this.debt,
    required this.owed,
    required this.annualMilli,
    required this.emi,
    required this.interestPaid,
    required this.lastPaid,
    this.lastEmi,
    required this.schedule,
    required this.history,
  });

  int get monthsLeft => schedule?.length ?? 0;
  int get interestLeft => schedule?.fold<int>(0, (s, i) => s + i.interest) ?? 0;
  int get nextInterest => monthlyInterest(owed, annualMilli);
  int get nextPrincipal =>
      (emi - nextInterest).clamp(0, owed < 0 ? 0 : owed).toInt();

  /// The next EMI day on or after [today].
  DateTime nextDue(DateTime today) {
    final day = debt.emiDay ?? 1;
    DateTime on(int year, int month) =>
        Dates.day(year, month, day.clamp(1, Dates.daysInMonth(year, month)));
    DateTime after(DateTime d) {
      final next = DateTime.utc(d.year, d.month + 1);
      return on(next.year, next.month);
    }

    var due = on(today.year, today.month);
    if (due.isBefore(today)) due = after(today);
    // This one is already paid, possibly a few days early.
    final paid = lastEmi;
    if (paid != null &&
        (due.difference(paid).inDays <= 10 ||
            (paid.year == due.year && paid.month == due.month))) {
      due = after(due);
    }
    return due;
  }
}

extension LoanRepo on Repo {
  /// Records a loan that is already running; the balance does not move.
  Future<String> addLoan({
    required String kind, // personal | car | home
    required String lender,
    required int owed,
    required int annualMilli,
    required int months,
    required int emiDay,
    int? emi,
    String? accountId,
    DateTime? asOf,
    bool emiInBudget = true,
    bool uncounted = false,
  }) async {
    if (annualMilli < 0) throw ValidationException('Rate cannot be negative');
    if (months <= 0 || months > 600) {
      throw ValidationException('Months left must be between 1 and 600');
    }
    if (emiDay < 1 || emiDay > 31) {
      throw ValidationException('EMI day must be between 1 and 31');
    }
    final pay = emi ?? emiFor(owed, annualMilli, months);
    if (scheduleFor(owed, annualMilli, pay) == null) {
      throw ValidationException('This EMI does not cover the interest');
    }
    return db.transaction(() async {
      final id = await createDebt(
        direction: 'liability',
        counterparty: lender,
        principalMinor: owed,
        accountId: accountId,
        issuedOn: asOf,
        affectsBalance: false,
      );
      await (db.update(db.debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          loanKind: Value(kind),
          annualRate: Value(annualMilli),
          emiMinor: Value(pay),
          emiDay: Value(emiDay),
          emiInBudget: Value(emiInBudget),
          uncounted: Value(uncounted),
          hlc: Value(clock.next()),
        ),
      );
      return id;
    });
  }

  Future<LoanStatus> loanStatus(String id) async {
    final debt = await (db.select(
      db.debts,
    )..where((d) => d.id.equals(id))).getSingle();
    final history = await debtTimeline(id);
    final state = await debtState(id);
    var rate = debt.annualRate ?? 0;
    var emi = debt.emiMinor ?? 0;
    var last = Dates.parse(debt.issuedOn);
    var interest = 0;
    DateTime? lastEmi;
    final inOrder = [...history]
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.hlc.compareTo(b.hlc);
      });
    for (final e in inOrder) {
      final on = Dates.parse(e.date);
      if (on.isAfter(today)) continue; // a rate change not yet in force
      if (e.type == 'terms') {
        rate = e.amountMinor;
        emi = e.principalPart;
      } else if (e.type == 'interest_paid') {
        interest += e.amountMinor;
      } else if (e.type == 'repayment') {
        if (on.isAfter(last)) last = on;
        if (e.note == 'emi') lastEmi = on; // in date order
      }
    }
    final owed = state.principalOutstanding;
    return LoanStatus(
      debt: debt,
      owed: owed,
      annualMilli: rate,
      emi: emi,
      interestPaid: interest,
      lastPaid: last,
      lastEmi: lastEmi,
      schedule: scheduleFor(owed, rate, emi),
      history: history,
    );
  }

  Future<List<LoanStatus>> loanStatuses() async => [
    for (final d in await debts(direction: 'liability'))
      if (d.loanKind != null) await loanStatus(d.id),
  ];

  Future<void> _loanEvent(
    String id,
    String debtId,
    String type,
    int amount,
    DateTime date, {
    int principalPart = 0,
  }) async {
    await db
        .into(db.debtEvents)
        .insert(
          DebtEventsCompanion.insert(
            id: id,
            debtId: debtId,
            type: type,
            amountMinor: amount,
            date: Dates.str(date),
            principalPart: Value(principalPart),
            hlc: clock.next(),
          ),
        );
  }

  /// One payment to the lender: principal, interest and any charges. Removing
  /// the returned event removes all of it.
  Future<String> _payLoan(
    String debtId, {
    required int principal,
    int interest = 0,
    int charges = 0,
    required String note, // emi | part | close
    DateTime? date,
  }) async {
    if (interest < 0 || charges < 0) {
      throw ValidationException('Amounts cannot be negative');
    }
    final on = date ?? today;
    return db.transaction(() async {
      final id = await addRepayment(
        debtId,
        principal,
        date: on,
        target: 'principal',
        note: note,
      );
      if (interest > 0) {
        await _loanEvent('${id}_i', debtId, 'interest_paid', interest, on);
      }
      if (charges > 0) {
        await _loanEvent('${id}_f', debtId, 'fee', charges, on);
      }
      await reconcileDebt(debtId);
      return id;
    });
  }

  Future<String> payEmi(
    String debtId, {
    required int interest,
    required int principal,
    DateTime? date,
  }) => _payLoan(
    debtId,
    principal: principal,
    interest: interest,
    note: 'emi',
    date: date,
  );

  Future<String> precloseLoan(
    String debtId, {
    required int interest,
    required int charges,
    DateTime? date,
  }) async => _payLoan(
    debtId,
    principal: (await loanStatus(debtId)).owed,
    interest: interest,
    charges: charges,
    note: 'close',
    date: date,
  );

  /// Pays extra principal, then either finishes sooner or lowers the EMI.
  Future<String> partPay(
    String debtId,
    int amount, {
    required bool shorterTerm,
    DateTime? date,
  }) async {
    return db.transaction(() async {
      final before = await loanStatus(debtId);
      final id = await _payLoan(
        debtId,
        principal: amount,
        note: 'part',
        date: date,
      );
      final owed = before.owed - amount;
      if (!shorterTerm && owed > 0 && before.monthsLeft > 0) {
        await _loanEvent(
          '${id}_t',
          debtId,
          'terms',
          before.annualMilli,
          date ?? today,
          principalPart: emiFor(owed, before.annualMilli, before.monthsLeft),
        );
      }
      return id;
    });
  }

  /// A floating rate moved. Past payments stay exactly as they were.
  Future<void> changeLoanRate(
    String debtId,
    int annualMilli, {
    required DateTime from,
    required bool keepEmi,
  }) async {
    final now = await loanStatus(debtId);
    final emi = keepEmi
        ? now.emi
        : emiFor(now.owed, annualMilli, now.monthsLeft);
    if (annualMilli < 0 || scheduleFor(now.owed, annualMilli, emi) == null) {
      throw ValidationException('This EMI does not cover the interest');
    }
    await _loanEvent(
      Repo.newId('ev_'),
      debtId,
      'terms',
      annualMilli,
      from,
      principalPart: emi,
    );
  }

  Future<void> setEmiInBudget(String debtId, bool value) async {
    await db.transaction(() async {
      await (db.update(db.debts)..where((d) => d.id.equals(debtId))).write(
        DebtsCompanion(emiInBudget: Value(value), hlc: Value(clock.next())),
      );
      await reconcileDebt(debtId);
    });
  }
}

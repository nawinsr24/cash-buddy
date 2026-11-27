/// EMI loan arithmetic. Money is in minor units; a yearly rate is in
/// thousandths of a percent, so 8.5% is 8500 and stays exact.
library;

import 'dart:math';

import 'money.dart';

/// One month's interest on what is still owed.
int monthlyInterest(int principal, int annualMilli) =>
    Money.divRoundHalfEven(principal * annualMilli, 1200000);

/// The level monthly payment that clears [principal] in [months].
int emiFor(int principal, int annualMilli, int months) {
  if (principal <= 0 || months <= 0) return 0;
  if (annualMilli <= 0) return (principal + months - 1) ~/ months;
  final r = annualMilli / 1200000;
  // Rounded up, as lenders do, so the loan never runs past its term.
  return (principal * r / (1 - pow(1 + r, -months))).ceil();
}

class Instalment {
  final int interest, principal, balance;
  const Instalment(this.interest, this.principal, this.balance);
}

/// The months still to pay. Empty when nothing is owed, null when [emi] does
/// not even cover the interest (or would take more than 50 years).
List<Instalment>? scheduleFor(int owed, int annualMilli, int emi) {
  final out = <Instalment>[];
  var balance = owed;
  while (balance > 0) {
    final interest = monthlyInterest(balance, annualMilli);
    var principal = emi - interest;
    if (principal <= 0 || out.length >= 600) return null;
    // The last payment absorbs the few paise that rounding leaves over.
    if (balance - principal < emi ~/ 20) principal = balance;
    balance -= principal;
    out.add(Instalment(interest, principal, balance));
  }
  return out;
}

class Preclosure {
  final int principal, interest, penalty, tax;

  /// Interest that would have been paid had the loan run its course.
  final int interestAvoided;
  const Preclosure(
    this.principal,
    this.interest,
    this.penalty,
    this.tax,
    this.interestAvoided,
  );

  int get total => principal + interest + penalty + tax;
  int get saving => interestAvoided - interest - penalty - tax;
}

/// An estimate: interest is counted by the day since the last payment, and
/// tax (GST) applies to the penalty only.
Preclosure preclosureFor({
  required int owed,
  required int annualMilli,
  required int emi,
  required int days,
  required int penaltyBps,
  required int taxBps,
}) {
  final interest = Money.divRoundHalfEven(
    owed * annualMilli * max(days, 0),
    36500000,
  );
  final penalty = Money.percentBps(owed, penaltyBps);
  final ahead = (scheduleFor(owed, annualMilli, emi) ?? const []).fold<int>(
    0,
    (s, i) => s + i.interest,
  );
  return Preclosure(
    owed,
    interest,
    penalty,
    Money.percentBps(penalty, taxBps),
    ahead,
  );
}

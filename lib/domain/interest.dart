import 'dates.dart';
import 'money.dart';

enum RatePeriod { daily, weekly, monthly, yearly }

enum InterestType { simple, compound }

/// Terms of one debt. Interest accrues once per [ratePeriod] counted from
/// [accrualStart]; the rate ([rateBps], basis points) is *per period*
/// (e.g. 200 bps + monthly = 2% per month).
///
/// simple   : interest = outstanding principal at period start * rate
/// compound : interest = (outstanding principal + unpaid interest) * rate
class DebtTerms {
  final int principalMinor;
  final DateTime issuedOn;
  final bool interestEnabled;
  final InterestType interestType;
  final int rateBps;
  final RatePeriod ratePeriod;
  final DateTime accrualStart;

  const DebtTerms({
    required this.principalMinor,
    required this.issuedOn,
    this.interestEnabled = false,
    this.interestType = InterestType.simple,
    this.rateBps = 0,
    this.ratePeriod = RatePeriod.monthly,
    DateTime? accrualStart,
  }) : accrualStart = accrualStart ?? issuedOn;
}

/// A payment (or non-cash write-off) reducing the debt. Allocation order is
/// fixed: accrued interest first, then principal.
class DebtPayment {
  final String id;
  final DateTime date;
  final int amountMinor;
  const DebtPayment(this.id, this.date, this.amountMinor);
}

class Accrual {
  /// 1-based period number; stable idempotency key `(debtId, k)`.
  final int periodIndex;
  final DateTime date;
  final int amountMinor;
  const Accrual(this.periodIndex, this.date, this.amountMinor);
}

class Allocation {
  final int interestMinor;
  final int principalMinor;

  /// Amount that exceeded the outstanding balance (must be 0 for valid input).
  final int excessMinor;
  const Allocation(this.interestMinor, this.principalMinor, this.excessMinor);
}

class DebtState {
  final List<Accrual> accruals;
  final Map<String, Allocation> allocations;
  final int principalOutstanding;
  final int interestOutstanding;
  final int totalAccrued;
  final int totalPaid;
  const DebtState(
    this.accruals,
    this.allocations,
    this.principalOutstanding,
    this.interestOutstanding,
    this.totalAccrued,
    this.totalPaid,
  );

  int get outstanding => principalOutstanding + interestOutstanding;
}

class InterestEngine {
  InterestEngine._();

  static const _maxPeriods = 20000;

  /// Date of the end of period [k] (k >= 1), computed from the anchor.
  static DateTime periodEnd(DebtTerms t, int k) {
    switch (t.ratePeriod) {
      case RatePeriod.daily:
        return t.accrualStart.add(Duration(days: k));
      case RatePeriod.weekly:
        return t.accrualStart.add(Duration(days: 7 * k));
      case RatePeriod.monthly:
        return Dates.addMonths(t.accrualStart, k);
      case RatePeriod.yearly:
        return Dates.addMonths(t.accrualStart, 12 * k);
    }
  }

  /// Pure, deterministic replay of a debt up to and including [asOf].
  /// Payments dated *on* a period boundary are applied after that period's
  /// interest is charged. Running it twice yields identical output, which is
  /// what makes persisted accruals idempotent.
  static DebtState replay(
    DebtTerms t,
    List<DebtPayment> payments,
    DateTime asOf,
  ) {
    final pays = [...payments]
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    var principal = t.principalMinor;
    var interest = 0;
    var totalAccrued = 0;
    var totalPaid = 0;
    final accruals = <Accrual>[];
    final allocs = <String, Allocation>{};
    var pi = 0;

    void apply(DebtPayment p) {
      final i = p.amountMinor < interest ? p.amountMinor : interest;
      final rest = p.amountMinor - i;
      final pr = rest < principal ? rest : principal;
      final excess = rest - pr;
      interest -= i;
      principal -= pr;
      totalPaid += i + pr;
      allocs[p.id] = Allocation(i, pr, excess);
    }

    final accrues = t.interestEnabled && t.rateBps > 0;
    var k = 1;
    while (accrues && k <= _maxPeriods) {
      final b = periodEnd(t, k);
      if (b.isAfter(asOf)) break;
      while (pi < pays.length && pays[pi].date.isBefore(b)) {
        apply(pays[pi++]);
      }
      final base = t.interestType == InterestType.simple
          ? principal
          : principal + interest;
      final amt = Money.percentBps(base, t.rateBps);
      if (amt > 0) {
        interest += amt;
        totalAccrued += amt;
        accruals.add(Accrual(k, b, amt));
      }
      k++;
    }
    while (pi < pays.length && !pays[pi].date.isAfter(asOf)) {
      apply(pays[pi++]);
    }
    return DebtState(
      accruals,
      allocs,
      principal,
      interest,
      totalAccrued,
      totalPaid,
    );
  }
}

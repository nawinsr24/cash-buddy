import 'dart:math';

/// One dated cash flow from the investor's point of view:
/// negative = money put in, positive = money received back.
class Flow {
  final DateTime date;
  final double amount;
  const Flow(this.date, this.amount);
}

/// Annualised return (XIRR) via bisection; null when it cannot be defined
/// (needs at least one outflow and one inflow, over more than a day).
double? xirr(List<Flow> flows) {
  if (flows.length < 2) return null;
  final hasOut = flows.any((f) => f.amount < 0);
  final hasIn = flows.any((f) => f.amount > 0);
  if (!hasOut || !hasIn) return null;
  final t0 = flows.map((f) => f.date).reduce((a, b) => a.isBefore(b) ? a : b);
  double npv(double r) {
    var s = 0.0;
    for (final f in flows) {
      final years = f.date.difference(t0).inHours / 24 / 365;
      s += f.amount / pow(1 + r, years);
    }
    return s;
  }

  var lo = -0.99, hi = 10.0;
  var flo = npv(lo), fhi = npv(hi);
  if (flo.isNaN || fhi.isNaN || flo * fhi > 0) return null;
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    final fm = npv(mid);
    if (fm.abs() < 1e-7) return mid;
    if (flo * fm < 0) {
      hi = mid;
      fhi = fm;
    } else {
      lo = mid;
      flo = fm;
    }
  }
  return (lo + hi) / 2;
}

/// Value today of dated contributions growing at [annualRate] (0.12 = 12%),
/// compounded daily-equivalent. An estimate for display, never ledger data.
int projectedValue(
  Iterable<({DateTime date, int amountMinor})> contributions,
  double annualRate,
  DateTime asOf,
) {
  var total = 0.0;
  for (final c in contributions) {
    final years = max(0, asOf.difference(c.date).inHours) / 24 / 365;
    total += c.amountMinor * pow(1 + annualRate, years);
  }
  return total.round();
}

/// Date of chit month [k] (0-based) for a chit starting on [start].
DateTime chitMonthDate(DateTime start, int k) {
  final m = start.month - 1 + k;
  final y = start.year + m ~/ 12;
  final mo = m % 12 + 1;
  final last = DateTime(y, mo + 1, 0).day;
  return DateTime(y, mo, min(start.day, last));
}

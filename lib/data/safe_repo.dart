import '../domain/dates.dart';
import 'budget_repo.dart';
import 'card_repo.dart';
import 'loan_repo.dart';
import 'repo.dart';

/// A payment still to come this month that will use up budget.
class Reserved {
  final String name;
  final int amount;
  const Reserved(this.name, this.amount);
}

/// What can be spent today without breaking this month's budget.
class SafeToSpend {
  /// Budget not yet spent as of this morning.
  final int left;
  final int spentToday;
  final int daysLeft; // today included
  final List<Reserved> reserved;
  const SafeToSpend(this.left, this.spentToday, this.daysLeft, this.reserved);

  int get reservedTotal => reserved.fold(0, (s, r) => s + r.amount);
  int get perDay {
    final free = left - reservedTotal;
    return free <= 0 ? 0 : free ~/ daysLeft;
  }

  /// Negative once today's share is used up.
  int get today => perDay - spentToday;
}

extension SafeRepo on Repo {
  /// Null when this month has no budget.
  Future<SafeToSpend?> safeToSpend() async {
    final now = today;
    final status = await budgetStatus(now.year, now.month);
    if (status == null) return null;
    final byDay = await budgetDaily(now.year, now.month);
    final spentToday = byDay.isEmpty
        ? 0
        : byDay.last - (byDay.length > 1 ? byDay[byDay.length - 2] : 0);
    final end = Dates.day(
      now.year,
      now.month,
      Dates.daysInMonth(now.year, now.month),
    );
    final reserved = <Reserved>[];

    // A card bill only uses budget later if card spends wait for the bill;
    // otherwise they are already in "spent" and must not be taken twice.
    if (await getSetting('cardBudgetMode') != 'swipe') {
      for (final c in await cardStatuses()) {
        final due = c.nextDue;
        if (due != null && !due.isAfter(end) && c.toPay > 0) {
          reserved.add(Reserved(c.name, c.toPay));
        }
      }
    }

    // This month's EMI, until it is recorded as paid (also when overdue).
    for (final l in await loanStatuses()) {
      if (l.owed <= 0) continue;
      final day = (l.debt.emiDay ?? 1).clamp(1, end.day);
      final due = Dates.day(now.year, now.month, day);
      // Added after this month's date: that EMI was paid before.
      if (due.isBefore(Dates.parse(l.debt.issuedOn))) continue;
      final paid = l.lastEmi;
      if (paid != null &&
          (due.difference(paid).inDays <= 10 ||
              (paid.year == due.year && paid.month == due.month))) {
        continue;
      }
      final counts = (l.debt.emiInBudget ?? true)
          ? l.nextInterest + l.nextPrincipal
          : l.nextInterest;
      if (counts > 0) reserved.add(Reserved(l.debt.counterparty, counts));
    }

    return SafeToSpend(
      status.remaining + spentToday,
      spentToday,
      end.day - now.day + 1,
      reserved,
    );
  }
}

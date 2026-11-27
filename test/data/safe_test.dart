import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/data/loan_repo.dart';
import 'package:cash_buddy/data/safe_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 10 November: 21 days left in the month, today included.
Future<TestEnv> _env() =>
    newEnv(opening: 100000000, now: DateTime(2026, 11, 10, 10));

void main() {
  test('no budget, no number', () async {
    final e = await _env();
    expect(await e.repo.safeToSpend(), isNull);
  });

  test('budget left over the days, less what was spent today', () async {
    final e = await _env();
    await e.repo.setBudget(3000000);
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 900000,
      date: Dates.day(2026, 11, 3),
    );
    var s = (await e.repo.safeToSpend())!;
    expect(
      (s.left, s.daysLeft, s.perDay, s.today),
      (2100000, 21, 100000, 100000),
    );
    await e.repo.addTransaction(type: 'debit', amountMinor: 30000);
    s = (await e.repo.safeToSpend())!;
    expect((s.perDay, s.today), (100000, 70000));
  });

  test('an EMI still due is set aside until it is paid', () async {
    final e = await _env();
    await e.repo.setBudget(3000000);
    e.clockNow = DateTime(2026, 11, 1, 10);
    final id = await e.repo.addLoan(
      kind: 'car',
      lender: 'HDFC',
      owed: 50000000,
      annualMilli: 9000,
      months: 60,
      emiDay: 20,
    );
    e.clockNow = DateTime(2026, 11, 10, 10);
    var s = (await e.repo.safeToSpend())!;
    expect(s.reservedTotal, 1037918);
    final l = await e.repo.loanStatus(id);
    await e.repo.payEmi(
      id,
      interest: l.nextInterest,
      principal: l.nextPrincipal,
    );
    s = (await e.repo.safeToSpend())!;
    // now it is spending instead, and is not taken a second time
    expect(s.reservedTotal, 0);
    expect(s.spentToday, 1037918);
    expect(s.left, 3000000);
  });

  test('a card bill is set aside only when it has not counted yet', () async {
    final e = await _env();
    await e.repo.setBudget(3000000);
    final card = await e.repo.addCard(name: 'HDFC Card', dueDay: 25);
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 500000,
      accountId: card,
      date: Dates.day(2026, 11, 2),
    );
    var s = (await e.repo.safeToSpend())!;
    expect((s.left, s.reservedTotal), (3000000, 500000));
    await e.repo.setSetting('cardBudgetMode', 'swipe');
    s = (await e.repo.safeToSpend())!;
    expect((s.left, s.reservedTotal), (2500000, 0));
  });
}

import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/home_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/data/loan_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _month = DateRange.thisMonth(DateTime(2026, 11, 4));

Future<(TestEnv, GroupService)> _sharing({bool earlierToo = true}) async {
  final env = await newEnv(opening: 5000000);
  addTearDown(() => env.db.close());
  await env.repo.setBudget(1500000);
  await env.repo.setSetting('accountSession', '{}');
  final service = GroupService(
    env.repo,
    secrets: MemorySecretStore(),
    server: Uri.parse('https://x.test/'),
    send: (_, _, _, _) async => (200, '{}'),
  );
  await service.create('Naveen');
  await env.repo.chooseSharing(earlierToo: earlierToo);
  return (env, service);
}

/// What the partner would receive, as amounts.
Future<List<int>> _shared(TestEnv env, GroupService service) async {
  await service.change(env.repo.publishHome);
  return [
    for (final e in GroupService.ofKind((await service.open())!, 'expense'))
      e.data['amountMinor'] as int,
  ]..sort();
}

Future<void> _partner(GroupService service, Map<String, Object?> balance) =>
    service.change((g) {
      g.put('member:mpriya', {'kind': 'member', 'name': 'Priya'});
      g.put('balance:mpriya', {'kind': 'balance', 'at': 1, ...balance});
    });

void main() {
  test('without home sharing, nothing is different', () async {
    final env = await newEnv(opening: 100000);
    await env.repo.setBudget(50000);
    await env.repo.addTransaction(
      type: 'debit',
      amountMinor: 700,
      uncounted: true,
    );
    expect(await env.repo.homeSummary(_month), isNull);
    expect((await env.repo.budgetStatus(2026, 11))!.spent, 700);
  });

  test(
    'one total for both; "Don\'t count" stays out and stays private',
    () async {
      final (env, service) = await _sharing();
      final r = env.repo;
      await r.addTransaction(
        type: 'debit',
        amountMinor: 1200000,
        categoryId: 'cat_bills',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 90000,
        note: 'secret gift',
        uncounted: true,
      );
      await service.change(
        (g) => g.add([
          {
            'kind': 'expense',
            'paidBy': 'mpriya',
            'amountMinor': 560000,
            'date': '2026-11-03',
            'note': 'milk',
            'cat': 'Food',
            'sub': 'Groceries',
          },
        ]),
      );
      final s = (await r.homeSummary(_month))!;
      expect((s.total, s.sharedTotal), (1760000, 1760000));
      expect(s.main.map((c) => c.name), ['Bills', 'Food']);
      // the money still left my account
      expect(await r.totalBalance(), 5000000 - 1290000);
      expect((await r.budgetStatus(2026, 11))!.spent, 1200000);
      expect(await _shared(env, service), [560000, 1200000]);
      final g = (await service.open())!;
      expect(g.disk.notes.values.join(), isNot(contains('secret gift')));
    },
  );

  test('what is shared follows edits, ticks and deletes', () async {
    final (env, service) = await _sharing();
    final r = env.repo;
    final id = await r.addTransaction(type: 'debit', amountMinor: 1000);
    expect(await _shared(env, service), [1000]);
    expect(await _shared(env, service), [1000]); // not sent twice
    await r.updateTransaction(id, amountMinor: 1500);
    expect(await _shared(env, service), [1500]);
    await r.setUncounted(id, true);
    expect(await _shared(env, service), isEmpty);
    await r.setUncounted(id, false);
    expect(await _shared(env, service), [1500]);
    await r.deleteTransaction(id);
    expect(await _shared(env, service), isEmpty);
  });

  test('"only from today" keeps earlier spending to myself', () async {
    final (env, service) = await _sharing(earlierToo: false);
    final r = env.repo;
    await r.addTransaction(
      type: 'debit',
      amountMinor: 111,
      date: Dates.day(2026, 11, 2),
    );
    await r.addTransaction(type: 'debit', amountMinor: 222);
    expect(await _shared(env, service), [222]);
    final s = (await r.homeSummary(_month))!;
    // my chart still has everything; the budget matches the partner's phone
    expect((s.total, s.sharedTotal), (333, 222));
  });

  test('chit and EMI count unless ticked; stocks are never spending', () async {
    final (env, service) = await _sharing();
    final r = env.repo;
    final loan = await r.addLoan(
      kind: 'home',
      lender: 'HDFC',
      owed: 50000000,
      annualMilli: 9000,
      months: 60,
      emiDay: 5,
    );
    await r.payEmi(loan, interest: 375000, principal: 662918);
    Future<String> invest(String kind, int amount) async {
      final id = await r.createInvestment(kind: kind, name: kind);
      await r.addInvestmentEntry(
        id,
        type: 'contribute',
        amountMinor: amount,
        date: Dates.day(2026, 11, 3),
      );
      return id;
    }

    final chit = await invest('custom', 500000);
    await invest('stock', 700000);
    expect((await r.homeSummary(_month))!.total, 1037918 + 500000);
    await r.setLoanUncounted(loan, true);
    await r.setInvestmentUncounted(chit, true);
    await r.updateInvestment(chit, name: 'Family chit'); // keeps the tick
    expect((await r.homeSummary(_month))!.total, 0);
    expect(await _shared(env, service), isEmpty);
  });

  test('balances show only when both have said yes', () async {
    final (env, service) = await _sharing();
    final r = env.repo;
    Future<Map<String, dynamic>?> mine() async {
      await service.change(r.publishHome);
      final g = (await service.open())!;
      return g.entries['balance:${g.disk.member}']?.data;
    }

    await _partner(service, {'on': false});
    expect(await mine(), isNull);
    await r.showMyBalance(true);
    // my yes alone sends no amount
    expect((await mine())!['balanceMinor'], isNull);
    expect((await r.homeSummary(_month))!.partnerBalances, isEmpty);

    await _partner(service, {'on': true, 'balanceMinor': 1860000});
    expect((await mine())!['balanceMinor'], 5000000);
    final shown = (await r.homeSummary(_month))!.partnerBalances.single;
    expect((shown.name, shown.amount), ('Priya', 1860000));

    await r.showMyBalance(false);
    expect((await mine())!['balanceMinor'], isNull);
    expect((await r.homeSummary(_month))!.partnerBalances, isEmpty);
  });
}

import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/home_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _month = DateRange.thisMonth(DateTime(2026, 11, 4));

Future<(TestEnv, GroupService)> _sharing() async {
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
  return (env, service);
}

void main() {
  test('without home sharing, nothing is different', () async {
    final env = await newEnv(opening: 100000);
    await env.repo.addTransaction(type: 'debit', amountMinor: 500);
    expect(await env.repo.homeSummary(_month), isNull);
  });

  test(
    'each spend counts in one place; balance falls for what I paid',
    () async {
      final (env, service) = await _sharing();
      final r = env.repo;
      await r.addTransaction(
        type: 'debit',
        amountMinor: 820000,
        categoryId: 'cat_food',
      );
      await r.addTransaction(
        type: 'debit',
        amountMinor: 1200000,
        categoryId: 'cat_bills',
        home: true,
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
      expect((s.mine, s.iPaidHome, s.iPaidInTotal), (820000, 1200000, 2020000));
      expect(s.homeTotal, 1760000);
      expect(s.byPerson[s.me], 1200000);
      expect(s.byPerson['mpriya'], 560000);
      expect(s.main.map((c) => c.name), ['Bills', 'Food']);
      // my budget and my chart see only my own spending
      expect((await r.budgetStatus(2026, 11))!.spent, 820000);
      expect((await r.budgetDaily(2026, 11)).last, 820000);
      final d = await r.dashboard(_month);
      expect(d.spendingByCategory.single.name, 'Food');
      expect(d.spending, 2020000);
      expect(await r.totalBalance(), 5000000 - 2020000);
    },
  );

  test('what my partner receives follows my Home mark', () async {
    final (env, service) = await _sharing();
    final r = env.repo;
    final id = await r.addTransaction(
      type: 'debit',
      amountMinor: 1000,
      note: 'gas',
      home: true,
    );
    await r.addTransaction(type: 'debit', amountMinor: 9, note: 'secret gift');
    Future<List<int>> shared() async {
      await service.change(r.publishHome);
      final g = (await service.open())!;
      return [
        for (final e in GroupService.ofKind(g, 'expense'))
          e.data['amountMinor'] as int,
      ];
    }

    expect(await shared(), [1000]);
    expect(await shared(), [1000]); // not sent twice
    await r.updateTransaction(id, amountMinor: 1500);
    expect(await shared(), [1500]);
    await r.setHome(id, false);
    expect(await shared(), isEmpty);
    await r.setHome(id, true);
    expect(await shared(), [1500]);
    await r.deleteTransaction(id);
    expect(await shared(), isEmpty);
    final g = (await service.open())!;
    expect(g.disk.notes.values.join(), isNot(contains('secret gift')));
  });
}

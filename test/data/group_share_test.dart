import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/group_share.dart';
import 'package:cash_buddy/features/group.dart' show groupBalances;
import 'package:cash_buddy/sync/group/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('only my share of group spending is mine', () async {
    final env = await newEnv(opening: 500000);
    addTearDown(() => env.db.close());
    await env.repo.setBudget(1000000);
    await env.repo.setSetting('accountSession', '{}');
    expect(await env.repo.myGroupShare('2026-11-01', '2026-11-30'), isEmpty);

    final service = GroupService(
      env.repo,
      secrets: MemorySecretStore(),
      server: Uri.parse('https://x.test/'),
      send: (_, _, _, _) async => (200, '{}'),
    );
    await service.create('Naveen');
    final me = (await service.open())!.disk.member;
    await service.change(
      (g) => g.add([
        {
          'kind': 'expense',
          'amountMinor': 100000,
          'note': 'rent',
          'paidBy': 'mpartner',
          'date': '2026-11-03',
          'shares': {me: 40000, 'mpartner': 60000},
        },
      ]),
    );
    expect(await env.repo.myGroupShare('2026-11-01', '2026-11-30'), {
      '2026-11-03': 40000,
    });
    expect((await env.repo.budgetStatus(2026, 11))!.spent, 40000);
    expect((await env.repo.budgetDaily(2026, 11)).last, 40000);
    expect(groupBalances((await service.open())!), {
      'mpartner': 40000,
      me: -40000,
    });
    // nothing changes outside the budget
    expect(await env.repo.totalBalance(), 500000);
  });
}

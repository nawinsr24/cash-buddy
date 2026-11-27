import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/split.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sync/sync_test.dart' show dev, dump, syncAll;
import 'helpers.dart';

final _range = DateRange.thisMonth(DateTime(2026, 11, 4));

/// ₹1,000 paid: my share ₹400, two friends ₹300 each.
Future<String> _dinner(Repo r, {String? account}) => r.addSplit(
  mine: 40000,
  others: [('Ravi', 30000), ('Arun', 30000)],
  accountId: account,
  categoryId: 'cat_food',
);

Future<(int balance, int spending, int income, int owed)> _state(Repo r) async {
  final d = await r.dashboard(_range);
  return (await r.totalBalance(), d.spending, d.income, d.incomingDebts);
}

void main() {
  test('shares add up and leftovers stay with me', () {
    final equal = splitShares(10000, SplitBy.equal, 2, [])!;
    expect(equal.others, [3333, 3333]);
    expect(equal.mine, 3334);
    final pct = splitShares(9999, SplitBy.percent, 2, [2500, 3333])!;
    expect(pct.mine + pct.others[0] + pct.others[1], 9999);
    expect(splitShares(100000, SplitBy.amount, 1, [40000])!.mine, 60000);
    // everyone, me included, must owe something
    expect(splitShares(100, SplitBy.amount, 1, [100]), isNull);
    expect(splitShares(100, SplitBy.percent, 1, [10000]), isNull);
    expect(splitShares(100, SplitBy.amount, 1, [null]), isNull);
    expect(splitShares(1, SplitBy.equal, 2, []), isNull);
  });

  test('balance drops by the bill, only my share is spending', () async {
    final e = await newEnv(opening: 500000);
    await _dinner(e.repo);
    expect(await _state(e.repo), (400000, 40000, 0, 60000));
  });

  test('being paid back is not income and leaves spending alone', () async {
    final e = await newEnv(opening: 500000);
    final id = await _dinner(e.repo);
    final ravi = (await e.repo.splitDebts(id))
        .firstWhere((d) => d.counterparty == 'Ravi');
    await e.repo.addRepayment(ravi.id, 30000);
    expect(await _state(e.repo), (430000, 40000, 0, 30000));
  });

  test('a written-off share becomes my spending, no money moves', () async {
    final e = await newEnv(opening: 500000);
    final id = await _dinner(e.repo);
    final friend = (await e.repo.splitDebts(id)).first;
    final event = await e.repo.addRepayment(friend.id, 30000, writeOff: true);
    expect(await _state(e.repo), (400000, 70000, 0, 30000));
    await e.repo.deleteDebtEvent(event);
    expect(await _state(e.repo), (400000, 40000, 0, 60000));
  });

  test('delete removes the whole split, undo brings it all back', () async {
    final e = await newEnv(opening: 500000);
    final id = await _dinner(e.repo);
    await e.repo.deleteTransaction(id);
    expect(await _state(e.repo), (500000, 0, 0, 0));
    await e.repo.restoreTransaction(id);
    expect(await _state(e.repo), (400000, 40000, 0, 60000));
  });

  test('edit replaces the people, undo after it restores only them', () async {
    final e = await newEnv(opening: 500000);
    final id = await _dinner(e.repo);
    await e.repo.updateSplit(
      id,
      mine: 50000,
      others: [('Meena', 70000)],
      accountId: await e.repo.defaultAccountId(),
      date: e.repo.today,
    );
    expect(await _state(e.repo), (380000, 50000, 0, 70000));
    e.clockNow = e.clockNow.add(const Duration(minutes: 1));
    await e.repo.deleteTransaction(id);
    await e.repo.restoreTransaction(id);
    expect((await e.repo.splitDebts(id)).single.counterparty, 'Meena');
    expect(await _state(e.repo), (380000, 50000, 0, 70000));
  });

  test('once someone has paid, edit and delete are refused', () async {
    final e = await newEnv(opening: 500000);
    final id = await _dinner(e.repo);
    final friend = (await e.repo.splitDebts(id)).first;
    await e.repo.addRepayment(friend.id, 10000);
    final refused = throwsA(isA<ValidationException>());
    expect(e.repo.deleteTransaction(id), refused);
    expect(
      e.repo.updateSplit(
        id,
        mine: 1,
        others: [('X', 1)],
        accountId: friend.accountId,
        date: e.repo.today,
      ),
      refused,
    );
    expect(e.repo.deleteDebt(friend.id), refused);
  });

  test('paid by credit card, friends pay back in money', () async {
    final e = await newEnv(opening: 500000);
    final card = await e.repo.addCard(
      name: 'HDFC',
      bank: 'HDFC',
      last4: '1234',
      limitMinor: 1000000,
      dueDay: 25,
    );
    final id = await _dinner(e.repo, account: card);
    expect((await e.repo.cardStatuses()).single.owed, 100000);
    expect(await e.repo.totalBalance(), 500000);
    final friend = (await e.repo.splitDebts(id)).first;
    await e.repo.addRepayment(friend.id, 30000);
    expect((await e.repo.cardStatuses()).single.owed, 100000);
    expect(await e.repo.totalBalance(), 530000);
  });

  test('a split reaches the other device the same', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    final id = await _dinner(a.repo);
    await syncAll([a, b]);
    expect(await b.repo.splitDebts(id), hasLength(2));
    expect(await dump(b.repo), await dump(a.repo));
    final friend = (await b.repo.splitDebts(id)).first;
    await b.repo.addRepayment(friend.id, 30000, writeOff: true);
    await syncAll([a, b]);
    expect(await dump(b.repo), await dump(a.repo));
  });
}

import 'package:cash_buddy/data/card_repo.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show dev, dump, syncAll;

void main() {
  test(
    'cards, their settings and their spends sync to another device',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      final id = await a.repo.addCard(
        name: 'HDFC Regalia',
        bank: 'HDFC',
        last4: '1234',
        limitMinor: 20000000,
        dueDay: 25,
        interestBps: 4200,
        ratePeriod: 'year',
        graceDays: 3,
      );
      await a.repo.addTransaction(
        type: 'debit',
        amountMinor: 250000,
        accountId: id,
      );
      await syncAll([a, b]);
      final card = (await b.repo.cards()).single;
      expect(card.name, 'HDFC Regalia');
      expect(card.dueDay, 25);
      expect(card.interestBps, 4200);
      expect(card.ratePeriod, 'year');
      expect(card.graceDays, 3);
      expect(card.limitMinor, 20000000);
      expect((await b.repo.cardStatuses()).single.owed, 250000);
      expect(await dump(b.repo), await dump(a.repo));
    },
  );
}

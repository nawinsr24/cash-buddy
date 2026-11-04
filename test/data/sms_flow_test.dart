import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

typedef Msg = ({String sender, String body, DateTime receivedAt});
Msg m(String s, String b) =>
    (sender: s, body: b, receivedAt: DateTime(2026, 11, 4, 8));

void main() {
  final parser = SmsParser();

  test('candidates never reach the ledger before confirmation', () async {
    final e = await newEnv(opening: 100000);
    final r = e.repo;
    final res = await r.ingestSms([
      m(
        'VM-HDFCBK',
        'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
      ),
      m('VM-HDFCBK', 'Your OTP is 123456'),
      m('VM-HDFCBK', 'Pre-approved loan! Apply now https://x.co'),
    ], parser);
    expect((res.added, res.rejected, res.duplicates), (1, 2, 0));
    expect(await r.totalBalance(), 100000);
    expect(await r.searchTransactions(const TxnFilter()), isEmpty);
    expect(await r.pendingSmsCount(), 1);
  });

  test(
    'confirm creates exactly one transaction; discard creates none',
    () async {
      final e = await newEnv(opening: 100000);
      final r = e.repo;
      await r.ingestSms([
        m(
          'VM-HDFCBK',
          'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
        ),
        m(
          'AX-AXISBK',
          'INR 85000.00 credited to A/c XX9876 on 01-Nov-26 by NEFT. Ref 7777777777',
        ),
      ], parser);
      final pending = await r.pendingSms();
      final debit = pending.firstWhere((s) => s.direction == 'debit');
      final credit = pending.firstWhere((s) => s.direction == 'credit');
      await r.confirmSms(debit.id, categoryId: 'cat_food_dining');
      await r.discardSms(credit.id);
      expect(await r.totalBalance(), 100000 - 50000);
      final txns = await r.searchTransactions(const TxnFilter());
      expect(txns.single.source, 'sms');
      expect(txns.single.categoryId, 'cat_food_dining');
      expect(await r.pendingSmsCount(), 0);
      // raw text purged once resolved
      expect(
        (await r.db.select(r.db.smsInbox).get()).every((s) => s.body.isEmpty),
        isTrue,
      );
      // cannot confirm twice
      await expectLater(
        r.confirmSms(debit.id),
        throwsA(isA<ValidationException>()),
      );
      expect((await r.searchTransactions(const TxnFilter())).length, 1);
    },
  );

  test('duplicates are skipped: same message, reworded repeat, and already-confirmed/discarded', () async {
    final e = await newEnv();
    final r = e.repo;
    final msg = m(
      'VM-HDFCBK',
      'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
    );
    var res = await r.ingestSms([msg, msg], parser);
    expect((res.added, res.duplicates), (1, 1));
    // same payment reported with different wording but same amount/account/ref
    res = await r.ingestSms([
      m('VM-ICICIB', 'Rs 500.00 spent on a/c XX1234, Ref 9000011111 at SWIGGY'),
    ], parser);
    expect(res.duplicates, 1);
    // after confirming, re-importing the same text does not resurface
    await r.confirmSms((await r.pendingSms()).single.id);
    res = await r.ingestSms([msg], parser);
    expect((res.added, res.duplicates), (0, 1));
    // after discarding likewise
    await r.ingestSms([
      m(
        'VM-HDFCBK',
        'Rs.77.00 debited from a/c XX1234 on 03-11-26. Ref 5555555555',
      ),
    ], parser);
    await r.discardSms((await r.pendingSms()).single.id);
    res = await r.ingestSms([
      m(
        'VM-HDFCBK',
        'Rs.77.00 debited from a/c XX1234 on 03-11-26. Ref 5555555555',
      ),
    ], parser);
    expect((res.added, res.duplicates), (0, 1));
  });

  test(
    'two messages with same amount but different references are both kept',
    () async {
      final e = await newEnv();
      final res = await e.repo.ingestSms([
        m(
          'VM-HDFCBK',
          'Rs.100.00 debited from a/c XX1234 on 03-11-26. Ref 1111111111',
        ),
        m(
          'VM-HDFCBK',
          'Rs.100.00 debited from a/c XX1234 on 03-11-26. Ref 2222222222',
        ),
      ], parser);
      expect(res.added, 2);
    },
  );

  test('purge removes stored SMS text', () async {
    final e = await newEnv();
    await e.repo.ingestSms([
      m(
        'VM-HDFCBK',
        'Rs.100.00 debited from a/c XX1234 on 03-11-26. Ref 1111111111',
      ),
    ], parser);
    await e.repo.purgeSmsText();
    expect((await e.repo.db.select(e.repo.db.smsInbox).get()).single.body, '');
  });
}

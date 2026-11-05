import 'package:cash_buddy/data/repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> inbound(
  Repo r,
  String last4,
  int amount,
  String ref,
) => r.ingestSms([
  (
    sender: 'VM-HDFCBK',
    body:
        'Rs.$amount.00 debited from a/c XX$last4 on 03-11-26 at SHOP. Ref $ref',
    receivedAt: DateTime(2026, 11, 3, 10),
  ),
], SmsParser());

void main() {
  test('combined mode: a bank message goes to the single account', () async {
    final e = await newEnv(opening: 100000);
    final m = await e.repo.accountForSms('1234');
    expect(m!.sure, isTrue);
    expect(m.id, 'acc_overall');
  });

  test('split with one bank: always that bank, nothing to ask', () async {
    final e = await newEnv(accountMode: 'split', opening: 100000);
    final m = await e.repo.accountForSms('9999');
    expect(m!.id, 'acc_bank');
    expect(m.sure, isTrue);
  });

  test('several banks: digits match picks the right one, else asks', () async {
    final e = await newEnv(accountMode: 'split');
    final hdfc = await e.repo.addAccount('HDFC', last4: '1234');
    final sbi = await e.repo.addAccount('SBI', last4: '5678');
    expect((await e.repo.accountForSms('1234'))!.id, hdfc);
    expect((await e.repo.accountForSms('5678'))!.id, sbi);
    final unknown = await e.repo.accountForSms('0000');
    expect(unknown!.sure, isFalse); // user must choose
    final none = await e.repo.accountForSms(null);
    expect(none!.sure, isFalse);
  });

  test('digits are optional: learning is off by default and opt-in', () async {
    final e = await newEnv(accountMode: 'split');
    final hdfc = await e.repo.addAccount('HDFC');
    await e.repo.addAccount('SBI');
    await inbound(e.repo, '1234', 100, '111');
    var sms = (await e.repo.pendingSms()).single;
    await e.repo.confirmSms(sms.id, accountId: hdfc);
    expect(
      (await e.repo.accounts()).firstWhere((a) => a.id == hdfc).last4,
      isNull,
    );

    await e.repo.setSetting('smsLearnDigits', '1');
    await inbound(e.repo, '1234', 200, '222');
    sms = (await e.repo.pendingSms()).single;
    await e.repo.confirmSms(sms.id, accountId: hdfc);
    expect(
      (await e.repo.accounts()).firstWhere((a) => a.id == hdfc).last4,
      '1234',
    );
    // next message from that account is recognised
    expect((await e.repo.accountForSms('1234'))!.id, hdfc);
  });

  test(
    'learning never steals digits already used by another account',
    () async {
      final e = await newEnv(accountMode: 'split');
      await e.repo.addAccount('HDFC', last4: '1234');
      final sbi = await e.repo.addAccount('SBI');
      await e.repo.setSetting('smsLearnDigits', '1');
      await inbound(e.repo, '1234', 100, '333');
      final sms = (await e.repo.pendingSms()).single;
      await e.repo.confirmSms(sms.id, accountId: sbi);
      expect(
        (await e.repo.accounts()).firstWhere((a) => a.id == sbi).last4,
        isNull,
      );
    },
  );

  test('dashboard is cumulative over all banks, with cash vs online', () async {
    final e = await newEnv(accountMode: 'split', opening: 50000);
    final hdfc = await e.repo.addAccount('HDFC', openingMinor: 1000000);
    final sbi = await e.repo.addAccount('SBI', openingMinor: 500000);
    final d = Dates.day(2026, 11, 3);
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 10000,
      accountId: hdfc,
      date: d,
    );
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 20000,
      accountId: sbi,
      date: d,
    );
    await e.repo.addTransaction(
      type: 'debit',
      amountMinor: 5000,
      accountId: 'acc_cash',
      date: d,
    );
    await e.repo.addTransaction(
      type: 'credit',
      amountMinor: 70000,
      accountId: sbi,
      date: d,
    );
    final x = await e.repo.dashboard(DateRange.thisMonth(e.clockNow));
    expect(x.spending, 35000); // every account added up
    expect(x.income, 70000);
    expect(x.cashSpending, 5000);
    expect(x.onlineSpending, 30000);
    expect(x.totalBalance, 50000 + 1000000 + 500000 - 35000 + 70000);
    expect(await e.repo.checkInvariants(), isEmpty);
  });
}

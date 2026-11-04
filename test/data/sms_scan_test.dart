import 'package:cash_buddy/platform/sms_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeReader implements SmsReader {
  bool granted;
  List<({String sender, String body, DateTime receivedAt})> inbox;
  DateTime? lastSince;
  FakeReader(this.granted, this.inbox);

  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<List<({String sender, String body, DateTime receivedAt})>> readInbox({
    required DateTime since,
    int limit = 500,
  }) async {
    lastSince = since;
    return inbox.where((m) => m.receivedAt.isAfter(since)).toList();
  }
}

void main() {
  final now = DateTime.now();
  msg(String s, String b, {int minsAgo = 5}) => (
    sender: s,
    body: b,
    receivedAt: now.subtract(Duration(minutes: minsAgo)),
  );

  test('no permission: nothing is read and an error is reported', () async {
    final e = await newEnv();
    final r = await scanSmsInbox(
      e.repo,
      reader: FakeReader(false, [
        Msg('VM-HDFCBK', 'Rs.5 debited from a/c XX1234'),
      ]),
    );
    expect(r.ok, isFalse);
    expect(await e.repo.pendingSmsCount(), 0);
  });

  test(
    'scan queues only real transactions; ledger untouched until confirm',
    () async {
      final e = await newEnv(opening: 100000);
      final reader = FakeReader(true, [
        Msg(
          'VM-HDFCBK',
          'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
        ),
        Msg('VM-HDFCBK', 'Your OTP is 123456. Do not share.'),
        Msg('AD-OFFERS', 'Get 50% off! Click https://x.co'),
        Msg('9876543210', 'Rs.500 debited from a/c XX1234'),
      ]);
      final r = await scanSmsInbox(e.repo, reader: reader);
      expect((r.scanned, r.added, r.ignored), (4, 1, 3));
      expect(await e.repo.pendingSmsCount(), 1);
      expect(await e.repo.totalBalance(), 100000);
    },
  );

  test('rescan is incremental and never duplicates', () async {
    final e = await newEnv();
    final reader = FakeReader(true, [
      Msg(
        'VM-HDFCBK',
        'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
        minsAgo: 30,
      ),
    ]);
    var r = await scanSmsInbox(e.repo, reader: reader);
    expect(r.added, 1);
    // a new message arrives; the old one is inside the 1-minute overlap window or filtered by 'since'
    reader.inbox = [
      ...reader.inbox,
      Msg(
        'AX-AXISBK',
        'INR 900.00 credited to A/c XX9876 on 04-11-26 by NEFT. Ref 7777777777',
        minsAgo: -1,
      ),
    ];
    r = await scanSmsInbox(e.repo, reader: reader);
    expect(r.added, 1);
    expect(await e.repo.pendingSmsCount(), 2);
    // scanning again with nothing new adds nothing
    r = await scanSmsInbox(e.repo, reader: reader);
    expect(r.added, 0);
    expect(await e.repo.pendingSmsCount(), 2);
    // first scan looked back ~30 days
    final fresh = FakeReader(true, []);
    await scanSmsInbox((await newEnv()).repo, reader: fresh);
    expect(now.difference(fresh.lastSince!).inDays, inInclusiveRange(29, 30));
  });
}

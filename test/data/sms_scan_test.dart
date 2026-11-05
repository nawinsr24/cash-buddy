import 'dart:async';

import 'package:cash_buddy/platform/sms_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeReader implements SmsReader {
  bool granted;
  List<({String sender, String body, DateTime receivedAt})> inbox;
  DateTime? lastSince;
  bool hang = false;
  FakeReader(this.granted, this.inbox);

  @override
  Future<void> setAutoDetect(bool enabled) async {}
  @override
  Future<String?> consumeLaunchAction() async => null;
  @override
  Future<void> setSecure(bool on) async {}
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
    if (hang) {
      return Completer<
            List<({String sender, String body, DateTime receivedAt})>
          >()
          .future;
    }
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
        msg('VM-HDFCBK', 'Rs.5 debited from a/c XX1234'),
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
        msg(
          'VM-HDFCBK',
          'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
        ),
        msg('VM-HDFCBK', 'Your OTP is 123456. Do not share.'),
        msg('AD-OFFERS', 'Get 50% off! Click https://x.co'),
        msg('9876543210', 'Rs.500 debited from a/c XX1234'),
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
      msg(
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
      msg(
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
    // a fresh install only looks at today's messages (from local midnight)
    final fresh = FakeReader(true, []);
    await scanSmsInbox((await newEnv()).repo, reader: fresh);
    expect(fresh.lastSince, DateTime(now.year, now.month, now.day));
  });

  test('one unparseable message never aborts the scan', () async {
    final e = await newEnv();
    final reader = FakeReader(true, [
      msg('VM-HDFCBK', 'Rs.${'9' * 40} debited from a/c XX1234 at SHOP'),
      msg('VM-HDFCBK', 'x' * 5000),
      msg(
        'VM-HDFCBK',
        'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
      ),
    ]);
    final r = await scanSmsInbox(e.repo, reader: reader);
    expect(r.ok, isTrue);
    expect(r.added, 1); // the good one still comes through
    expect(await e.repo.pendingSmsCount(), 1);
  });

  test('last scan result is recorded for Diagnostics', () async {
    final e = await newEnv();
    await scanSmsInbox(
      e.repo,
      reader: FakeReader(true, [
        msg(
          'VM-HDFCBK',
          'Rs.500.00 debited from a/c XX1234 on 03-11-26 at SWIGGY. Ref 9000011111',
        ),
      ]),
    );
    final info = await e.repo.getSetting('lastScanInfo');
    expect(info, contains('1 messages'));
    expect(info, contains('1 new'));
    await scanSmsInbox(e.repo, reader: FakeReader(false, []));
    expect(await e.repo.getSetting('lastScanInfo'), contains('permission'));
  });

  test(
    'a stuck inbox read times out instead of blocking scans forever',
    () async {
      final e = await newEnv();
      final stuck = FakeReader(true, [])..hang = true;
      final r = await scanSmsInbox(
        e.repo,
        reader: stuck,
        readTimeout: const Duration(milliseconds: 50),
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('too long'));
      // and the next scan works normally
      final ok = await scanSmsInbox(e.repo, reader: FakeReader(true, []));
      expect(ok.busy, isFalse);
      expect(ok.ok, isTrue);
    },
  );
}

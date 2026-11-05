import 'package:cash_buddy/data/insights_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';

void main() {
  test('parser stays fast on hostile / very long messages', () {
    final p = SmsParser();
    final nasty = [
      'Rs.${'1,' * 5000}00 debited ${'a/c XX' * 2000} at ${'SHOP ' * 3000}',
      '${' ' * 20000}Rs.5 debited${' ' * 20000}',
      'balance ${'-' * 30000} Rs.100 avl bal ${'.' * 30000} debited',
      'to ${'A' * 40000} on ref ${'9' * 40000} debited Rs.10',
      List.filled(
        800,
        'Your a/c XX1234 debited Rs.1,00,000.00 at UPI/ref 123456789012 bal Rs.5,000.',
      ).join(' '),
      '${'₹' * 10000} debited',
    ];
    for (final m in nasty) {
      final sw = Stopwatch()..start();
      p.parse('VM-HDFCBK', m, DateTime(2026, 11, 5));
      expect(
        sw.elapsedMilliseconds,
        lessThan(1500),
        reason: m.substring(0, 30),
      );
    }
  });

  test('ingesting 500 messages is quick and the heavy insight queries stay cheap', () async {
    final e = await newEnv(accountMode: 'split', opening: 1000000);
    final r = e.repo;
    // a year of data so ensureMonthTitles has real work
    for (var m = 1; m <= 11; m++) {
      for (var i = 0; i < 20; i++) {
        await r.addTransaction(
          type: i == 0 ? 'credit' : 'debit',
          amountMinor: 10000 + i,
          date: Dates.day(2026, m, 1 + i),
        );
      }
    }
    final msgs = [
      for (var i = 0; i < 500; i++)
        (
          sender: 'VM-HDFCBK',
          body:
              'Rs.${100 + i}.00 debited from a/c XX1234 on 03-11-26 at SHOP$i. Ref ${900000000 + i}',
          receivedAt: DateTime(2026, 11, 3, 10),
        ),
    ];
    var sw = Stopwatch()..start();
    await r.ingestSms(msgs, SmsParser());
    final ingest = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    await r.ensureMonthTitles();
    final titles = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    await r.insights();
    final ins = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'ingest 500: ${ingest}ms, titles(12 mo): ${titles}ms, insights: ${ins}ms',
    );
    expect(ingest, lessThan(5000));
    expect(titles, lessThan(3000));
    expect(ins, lessThan(1000));
  });
}

import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// All fixtures are synthetic.
final p = SmsParser();
final now = DateTime(2026, 11, 4, 9);

SmsParseResult run(String s, String body) => p.parse(s, body, now);

void main() {
  group('accepts real money movements', () {
    test('card debit', () {
      final r = run(
        'VM-HDFCBK',
        'Rs.1,250.50 debited from a/c XX1234 on 03-11-26 at AMAZON PAY. Ref 4093827123. Avl Bal Rs.45,000.00',
      );
      expect(r.isAccepted, isTrue);
      expect(r.parsed!.direction, 'debit');
      expect(r.parsed!.amountMinor, 125050);
      expect(r.parsed!.accountRef, '1234');
      expect(r.parsed!.reference, '4093827123');
      expect(Dates.str(r.parsed!.date), '2026-11-03');
    });
    test('credit salary', () {
      final r = run(
        'AX-AXISBK',
        'INR 85000.00 credited to A/c no. XX9876 on 01-Nov-26 by NEFT from DENOVO SYSTEMS. Bal: INR 90,500.00',
      );
      expect(r.parsed!.direction, 'credit');
      expect(r.parsed!.amountMinor, 8500000);
      expect(Dates.str(r.parsed!.date), '2026-11-01');
    });
    test('UPI debit extracts merchant', () {
      final r = run(
        'JD-ICICIB',
        'Rs 349.00 paid to SWIGGY on 02-11-26 via UPI. UPI Ref 330012345678. A/c XX4321',
      );
      expect(r.parsed!.direction, 'debit');
      expect(r.parsed!.amountMinor, 34900);
      expect(r.parsed!.merchant, 'SWIGGY');
      expect(r.parsed!.reference, '330012345678');
    });
    test('falls back to received time when no date in text', () {
      final r = run('VM-SBIINB', 'Rs 500 withdrawn from a/c 5555 ATM.');
      expect(r.isAccepted, isTrue);
      expect(Dates.str(r.parsed!.date), '2026-11-04');
    });
  });

  group('rejects non-transactions', () {
    final cases = <String, List<String>>{
      'otp': [
        'VM-HDFCBK',
        'Your OTP for txn of Rs.500 is 123456. Do not share.',
      ],
      'promotional': [
        'VM-HDFCBK',
        'Pre-approved loan up to Rs.5,00,000! Apply now at https://bit.ly/x',
      ],
      'not_executed': [
        'VM-HDFCBK',
        'Rs.999 will be debited from a/c XX1234 on 05-11-26 for your mandate',
      ],
      'no_transaction': [
        'VM-HDFCBK',
        'Your a/c XX1234 available balance is Rs.45,000.00',
      ],
      'unknown_sender': ['9876543210', 'Rs.500 debited from a/c XX1234'],
    };
    cases.forEach((reason, c) {
      test(reason, () => expect(run(c[0], c[1]).rejectReason, reason));
    });
    test('failed transaction', () {
      expect(
        run(
          'VM-HDFCBK',
          'Txn of Rs.500 failed. Amount not debited.',
        ).isAccepted,
        isFalse,
      );
    });
    test('promotional sender suffix -P', () {
      expect(
        run('VM-HDFCBK-P', 'Rs.500 debited from a/c XX1234').rejectReason,
        'unknown_sender',
      );
    });
    test('cashback marketing that mentions debit', () {
      expect(
        run(
          'VM-HDFCBK',
          'Congratulations! Get cashback offer when Rs.500 is debited. Click link',
        ).isAccepted,
        isFalse,
      );
    });
    test('denied sender', () {
      final s = SmsParser(deniedSenders: {'VM-HDFCBK'});
      expect(
        s.parse('VM-HDFCBK', 'Rs.5 debited from a/c XX1234', now).isAccepted,
        isFalse,
      );
    });
  });

  test('any named sender is read when the text names an account', () {
    const alert =
        'Rs.250.00 debited from a/c XX1234 on 03-11-26. Ref 1234567890';
    expect(run('JM-KVBANK', alert).isAccepted, isTrue);
    expect(run('AD-SHOPXY', alert).isAccepted, isTrue);
    // no account or card named: not trusted from an unknown sender
    expect(
      run('AD-SHOPXY', 'Rs.250.00 paid to Ravi on 03-11-26').isAccepted,
      isFalse,
    );
    // a person's phone number is never a bank
    expect(run('+919876543210', alert).isAccepted, isFalse);
    // promotional category headers stay out
    expect(run('AD-SHOPXY-P', alert).isAccepted, isFalse);
  });

  test('channel names (UPI/NEFT/ATM) are not mistaken for merchants', () {
    final r = run(
      'AX-AXISBK',
      'INR 12000.00 credited to A/c XX9876 on 04-11-26 by UPI from RAHUL. Ref 7777777777',
    );
    expect(r.parsed!.merchant, 'RAHUL');
    final a = run('VM-SBIINB', 'Rs 500 withdrawn from a/c 5555 at ATM.');
    expect(a.parsed!.merchant, isNull);
  });

  test('balance amount is never mistaken for the transaction amount', () {
    final r = run(
      'VM-HDFCBK',
      'Avl Bal Rs.45,000.00. Rs.100.00 debited from a/c XX1234',
    );
    expect(r.parsed!.amountMinor, 10000);
  });

  test('same message -> same fingerprint; different amount -> different', () {
    final a = run(
      'VM-HDFCBK',
      'Rs.100 debited from a/c XX1234 Ref 111111',
    ).parsed!;
    final b = run(
      'VM-HDFCBK',
      'Rs.100  debited  from a/c XX1234 Ref 111111',
    ).parsed!;
    final c = run(
      'VM-HDFCBK',
      'Rs.101 debited from a/c XX1234 Ref 111111',
    ).parsed!;
    expect(a.fingerprint, b.fingerprint);
    expect(a.fingerprint, isNot(c.fingerprint));
    expect(a.semanticKey, isNot(c.semanticKey));
  });

  test(
    'HDFC "Sent Rs.… From … To …" UPI alert from JD-HDFCBN-S is captured',
    () {
      final r = run(
        'JD-HDFCBN-S',
        'Sent Rs.650.00\nFrom HDFC Bank A/C *7130\nTo SANTHOSH MANI ACADEMY\nOn 06/11/26\nRef 123731371685\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808',
      );
      expect(r.isAccepted, isTrue);
      expect(r.parsed!.amountMinor, 65000);
      expect(r.parsed!.merchant, 'SANTHOSH MANI ACADEMY');
    },
  );
}

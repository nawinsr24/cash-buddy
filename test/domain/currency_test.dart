import 'package:cash_buddy/domain/currency.dart';
import 'package:cash_buddy/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Money.configure()); // back to INR for other tests

  test('INR is first in the list and keeps Indian grouping', () {
    expect(allCurrencies.first.code, 'INR');
    Money.configure();
    expect(Money.format(10000000), '₹1,00,000.00');
    expect(Money.compact(10000000), '₹1.0L');
  });

  test('every currency has a symbol and a sane number of decimals', () {
    for (final c in allCurrencies) {
      expect(c.symbol, isNotEmpty, reason: c.code);
      expect(c.decimals, inInclusiveRange(0, 3), reason: c.code);
    }
  });

  test('US dollar: cents, US grouping, K / M compact', () {
    Money.configure(code: 'USD');
    expect(Money.format(123456), r'$1,234.56');
    expect(Money.compact(250000000), r'$2.5M');
    expect(Money.parse('12.5'), 1250);
    expect(Money.parse(r'$1,000'), 100000);
    expect(Money.parse('1.234'), isNull);
  });

  test('yen has no decimals; dinar has three', () {
    Money.configure(code: 'JPY');
    expect(Money.decimals, 0);
    expect(Money.format(1235), contains('1,235'));
    expect(Money.parse('1500'), 1500);
    expect(Money.parse('1500.5'), isNull);
    expect(Money.edit(1500), '1500');
    Money.configure(code: 'KWD');
    expect(Money.decimals, 3);
    expect(Money.parse('1.5'), 1500);
    expect(Money.edit(1500), '1.500');
    expect(Money.edit(1500, trimZeros: true), '1.5');
  });

  test('amounts round-trip through the edit box in every currency', () {
    for (final c in allCurrencies) {
      Money.configure(code: c.code);
      for (final minor in [0, 1, 99, 12345, 100000000]) {
        expect(
          Money.parse(Money.edit(minor)),
          minor,
          reason: '${c.code} $minor',
        );
      }
    }
  });

  test('chart helper converts back and forth', () {
    Money.configure(code: 'KWD');
    expect(Money.fromMajor(2.5), 2500);
    expect(Money.unit, 1000);
  });
}

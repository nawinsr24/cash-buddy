import 'package:intl/intl.dart';

/// Money is always an integer number of minor units (paise / cents).
/// Never use double for amounts.
class Money {
  Money._();

  /// Integer division rounding half to even (banker's rounding).
  static int divRoundHalfEven(int numerator, int denominator) {
    if (denominator == 0) throw ArgumentError('denominator is zero');
    var n = numerator;
    var d = denominator;
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final q = n ~/ d; // truncates toward zero
    final r = n.remainder(d);
    final twice = r.abs() * 2;
    if (twice < d) return q;
    if (twice > d) return n < 0 ? q - 1 : q + 1;
    // exactly half: choose even
    if (q.isEven) return q;
    return n < 0 ? q - 1 : q + 1;
  }

  /// amount * bps / 10000 rounded half-even.
  static int percentBps(int amountMinor, int bps) =>
      divRoundHalfEven(amountMinor * bps, 10000);

  /// Parses user input like "1,234.5" into minor units (123450).
  /// Returns null for invalid / negative / >2 decimals input.
  static int? parse(String input) {
    final s = input
        .trim()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[₹$\s]'), '');
    final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
    if (m == null) return null;
    final whole = int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(2, '0');
    return whole * 100 + int.parse(frac.isEmpty ? '0' : frac);
  }

  static String format(int minor, {String symbol = '₹', bool signed = false}) {
    final f = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: 2,
    );
    final body = f.format(minor.abs() / 100);
    if (minor < 0) return '-$body';
    return signed && minor > 0 ? '+$body' : body;
  }

  /// Compact form for charts / tiles: ₹1.2L, ₹3.4K.
  static String compact(int minor, {String symbol = '₹'}) {
    final v = minor.abs() / 100;
    String s;
    if (v >= 10000000) {
      s = '${(v / 10000000).toStringAsFixed(1)}Cr';
    } else if (v >= 100000) {
      s = '${(v / 100000).toStringAsFixed(1)}L';
    } else if (v >= 1000) {
      s = '${(v / 1000).toStringAsFixed(1)}K';
    } else {
      s = v.toStringAsFixed(0);
    }
    return '${minor < 0 ? '-' : ''}$symbol$s';
  }
}

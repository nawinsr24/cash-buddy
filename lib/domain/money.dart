import 'package:intl/intl.dart';

import 'currency.dart';

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

  // ── the user's currency (set once at start-up and when they change it) ──
  static String _code = 'INR';
  static int _dec = 2;
  static String _symbol = '₹';
  static String _locale = 'en_IN';

  static String get code => _code;
  static String get symbol => _symbol;
  static int get decimals => _dec;

  /// Minor units in one major unit (100 for rupees, 1 for yen, 1000 for dinar).
  static int get minorPerMajor {
    var n = 1;
    for (var i = 0; i < _dec; i++) {
      n *= 10;
    }
    return n;
  }

  /// Same value as a double, for chart axes only (never for money maths).
  static double get unit => minorPerMajor.toDouble();

  /// Digit grouping and separators follow [locale]; India keeps en_IN
  /// (1,00,000). Defaults to INR / en_IN for people who never chose.
  static void configure({String code = 'INR', String? locale}) {
    final c = currencyByCode(code);
    _code = c.code;
    _dec = c.decimals;
    _symbol = c.symbol;
    _locale = locale != null && NumberFormat.localeExists(locale)
        ? locale
        : (c.code == 'INR' ? 'en_IN' : 'en_US');
  }

  /// Regex that lets an amount box accept only valid input for the currency.
  static RegExp get inputPattern =>
      _dec == 0 ? RegExp(r'^\d*') : RegExp('^\\d*\\.?\\d{0,$_dec}');

  /// A number for an edit box: major units with the currency's decimals.
  static String edit(int minor, {bool trimZeros = false}) {
    final v = (minor / unit).toStringAsFixed(_dec);
    if (!trimZeros || !v.contains('.')) return v;
    return v.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// A major-unit number (from a chart or a slider) back to minor units.
  static int fromMajor(double major) => (major * unit).round();

  /// Parses user input like "1,234.5" into minor units. Returns null for
  /// invalid, negative or too many decimals for the currency.
  static int? parse(String input) {
    final s = input
        .trim()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[₹$€£¥\s]'), '')
        .replaceAll(_symbol, '');
    final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(s);
    if (m == null) return null;
    final frac = m.group(2) ?? '';
    if (frac.length > _dec) return null;
    final whole = int.parse(m.group(1)!);
    final f = frac.padRight(_dec, '0');
    return whole * minorPerMajor + (f.isEmpty ? 0 : int.parse(f));
  }

  static String format(int minor, {String? symbol, bool signed = false}) {
    final f = NumberFormat.currency(
      locale: _locale,
      symbol: symbol ?? _symbol,
      decimalDigits: _dec,
    );
    final body = f.format(minor.abs() / unit);
    if (minor < 0) return '-$body';
    return signed && minor > 0 ? '+$body' : body;
  }

  /// Compact form for charts / tiles: ₹1.2L / ₹3.4K in India, $1.2M / $3.4K
  /// elsewhere.
  static String compact(int minor, {String? symbol}) {
    final sym = symbol ?? _symbol;
    final v = minor.abs() / unit;
    final india = _code == 'INR';
    String s;
    if (india && v >= 10000000) {
      s = '${(v / 10000000).toStringAsFixed(1)}Cr';
    } else if (india && v >= 100000) {
      s = '${(v / 100000).toStringAsFixed(1)}L';
    } else if (!india && v >= 1000000000) {
      s = '${(v / 1000000000).toStringAsFixed(1)}B';
    } else if (!india && v >= 1000000) {
      s = '${(v / 1000000).toStringAsFixed(1)}M';
    } else if (v >= 1000) {
      s = '${(v / 1000).toStringAsFixed(1)}K';
    } else {
      s = v.toStringAsFixed(0);
    }
    return '${minor < 0 ? '-' : ''}$sym$s';
  }
}

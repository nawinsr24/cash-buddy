import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'dates.dart';

class ParsedSms {
  final String direction; // 'credit' | 'debit'
  final int amountMinor;
  final DateTime date;
  final String? merchant;
  final String? accountRef;
  final String? reference;
  final String fingerprint;
  final String semanticKey;
  const ParsedSms({
    required this.direction,
    required this.amountMinor,
    required this.date,
    this.merchant,
    this.accountRef,
    this.reference,
    required this.fingerprint,
    required this.semanticKey,
  });
}

class SmsParseResult {
  final ParsedSms? parsed;
  final String? rejectReason;
  const SmsParseResult.ok(ParsedSms p) : parsed = p, rejectReason = null;
  const SmsParseResult.rejected(String reason)
    : parsed = null,
      rejectReason = reason;
  bool get isAccepted => parsed != null;
}

/// Pure-Dart bank SMS parser shared by every ingestion path
/// (paste / share / Android reader). Prefers false negatives over false
/// positives: anything that is not clearly an *executed* money movement
/// from a recognised sender is rejected with a reason.
class SmsParser {
  /// Sender header keywords of recognised institutions (after the `XX-` prefix).
  static const defaultSenders = <String>{
    'HDFCBK',
    'SBIINB',
    'SBIPSG',
    'SBICRD',
    'ICICIB',
    'AXISBK',
    'KOTAKB',
    'PNBSMS',
    'BOIIND',
    'CANBNK',
    'UNIONB',
    'IDFCFB',
    'YESBNK',
    'INDBNK',
    'PAYTMB',
    'HSBCIN',
    'SCBANK',
    'FEDBNK',
    'BOBSMS',
  };

  final Set<String> senders;
  final Set<String> deniedSenders;

  /// Also accept TRAI-style headers that look like a bank/payment sender
  /// (e.g. `JM-KVBANK`, `AD-PAYTMB`) even if not in [senders]. Content rules
  /// (no OTP / promo / pending) still apply, so false positives stay rare.
  final bool bankLikeHeaders;

  SmsParser({
    Set<String>? senders,
    Set<String>? deniedSenders,
    this.bankLikeHeaders = true,
  }) : senders = senders ?? defaultSenders,
       deniedSenders = deniedSenders ?? const {};

  static final _bankLike = RegExp(r'(BANK|BNK|BK|PAY|CARD|CRD|UPI|FIN|CU)$');

  static final _otp = RegExp(
    r'\b(otp|one[- ]time password|verification code|do not share|never share|cvv|passcode)\b',
    caseSensitive: false,
  );
  static final _promo = RegExp(
    r'\b(offer|apply now|apply today|pre-?approved|click|avail|congratulations|congrats|loan up to|reward|cashback offer|t&c|limited time|exclusive|upgrade|win|download the app|install)\b|https?://|bit\.ly|\bwww\.',
    caseSensitive: false,
  );
  static final _notExecuted = RegExp(
    r'will be debited|will be credited|to be debited|has been declined|declined|failed|unsuccessful|insufficient|reversal initiated|request(ed)? (for|to)|mandate|payment due|due on|minimum (amount )?due|is due|not processed|could not be|autopay.*(scheduled|upcoming)|upcoming',
    caseSensitive: false,
  );
  static final _debit = RegExp(
    r'\b(debited|spent|withdrawn|withdrawal|purchase|paid|sent)\b',
    caseSensitive: false,
  );
  static final _credit = RegExp(
    r'\b(credited|received|deposited)\b',
    caseSensitive: false,
  );
  static final _amount = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  /// Text immediately before an amount that marks it as a balance/limit figure.
  static final _balanceLabel = RegExp(
    r'(bal(ance)?|avl|available|limit|outstanding)\W*(is|of|:)?\W*$',
  );
  static const _notMerchant = {
    'upi',
    'neft',
    'imps',
    'rtgs',
    'atm',
    'pos',
    'vpa',
    'ecs',
    'nach',
    'card',
    'your a/c',
    'a/c',
    'account',
    'bank',
    'ref',
    'info',
  };
  static final _acct = RegExp(
    r'(?:a\/c|acct?|account|card)\s*(?:no\.?)?\s*(?:ending|ending with|xx+|x+|\*+)?\s*(\d{3,4})\b',
    caseSensitive: false,
  );
  static final _ref = RegExp(
    r'(?:ref(?:erence)?(?:\s*no)?|utr|upi\s*ref)[.:\s#-]*([A-Za-z0-9]{6,22})',
    caseSensitive: false,
  );
  static final _date = RegExp(
    r'\b(\d{1,2})[-\/ ]([A-Za-z]{3}|\d{1,2})[-\/ ](\d{2,4})\b',
  );
  static final _merchant = RegExp(
    r'(?:\bto\b|\bat\b|\bfrom\b|\bby\b|\binfo:?)\s+(?:vpa\s+)?([A-Za-z0-9][A-Za-z0-9 .&_@\-]{1,34}?)(?=\s+(?:on|ref|upi|via|using|from|avl|bal|available)\b|[.,;]|\s*$)',
    caseSensitive: false,
  );

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  bool _recognisedSender(String sender) {
    final s = sender.trim().toUpperCase();
    if (deniedSenders.contains(s)) return false;
    final m = RegExp(r'^[A-Z0-9]{2}-([A-Z0-9]{3,10})(?:-([A-Z]))?$')
        .firstMatch(s);
    final body = m != null ? m.group(1)! : s;
    final suffix = m?.group(2);
    if (suffix == 'P') return false; // TRAI promotional category
    if (senders.contains(body)) return true;
    return bankLikeHeaders && m != null && _bankLike.hasMatch(body);
  }

  SmsParseResult parse(String sender, String body, DateTime receivedAt) {
    if (!_recognisedSender(sender)) {
      return const SmsParseResult.rejected('unknown_sender');
    }
    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_otp.hasMatch(text)) return const SmsParseResult.rejected('otp');
    if (_notExecuted.hasMatch(text)) {
      return const SmsParseResult.rejected('not_executed');
    }
    if (_promo.hasMatch(text)) {
      return const SmsParseResult.rejected('promotional');
    }

    final d = _debit.firstMatch(text);
    final c = _credit.firstMatch(text);
    if (d == null && c == null) {
      return const SmsParseResult.rejected('no_transaction');
    }
    final isDebit = d != null && (c == null || d.start < c.start);

    int? amount;
    for (final m in _amount.allMatches(text)) {
      final before = text
          .substring((m.start - 24).clamp(0, m.start), m.start)
          .toLowerCase();
      if (_balanceLabel.hasMatch(before)) continue;
      amount = _toMinor(m.group(1)!);
      break;
    }
    if (amount == null || amount <= 0) {
      return const SmsParseResult.rejected('no_amount');
    }

    final acct = _acct.firstMatch(text)?.group(1);
    final ref = _ref.firstMatch(text)?.group(1);
    String? merchant;
    for (final m in _merchant.allMatches(text)) {
      final c = m.group(1)?.trim();
      if (c == null || c.isEmpty) continue;
      final l = c.toLowerCase();
      // channel names and account fragments are not merchants
      if (_notMerchant.contains(l) ||
          l.startsWith('a/c') ||
          RegExp(r'^[\d .-]+$').hasMatch(l)) {
        continue;
      }
      merchant = c;
      break;
    }
    final date = _extractDate(text) ?? Dates.fromLocal(receivedAt);

    final dir = isDebit ? 'debit' : 'credit';
    final fp = sha256
        .convert(utf8.encode('${sender.toUpperCase()}|${text.toLowerCase()}'))
        .toString();
    final sem = [dir, amount, acct ?? '', ref ?? Dates.str(date)].join('|');
    return SmsParseResult.ok(
      ParsedSms(
        direction: dir,
        amountMinor: amount,
        date: date,
        merchant: merchant,
        accountRef: acct,
        reference: ref,
        fingerprint: fp,
        semanticKey: sem,
      ),
    );
  }

  static int _toMinor(String s) {
    final clean = s.replaceAll(',', '');
    final parts = clean.split('.');
    final frac = parts.length > 1
        ? parts[1].padRight(2, '0').substring(0, 2)
        : '00';
    return int.parse(parts[0]) * 100 + int.parse(frac);
  }

  DateTime? _extractDate(String text) {
    final m = _date.firstMatch(text);
    if (m == null) return null;
    final dd = int.parse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!) ?? _months[m.group(2)!.toLowerCase()];
    var yy = int.parse(m.group(3)!);
    if (mm == null || mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    if (yy < 100) yy += 2000;
    if (dd > Dates.daysInMonth(yy, mm)) return null;
    return Dates.day(yy, mm, dd);
  }
}

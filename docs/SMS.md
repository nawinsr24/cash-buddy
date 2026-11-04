# SMS assistant: what exists and what does not

Implemented (and tested): pure-Dart parser (`lib/domain/sms_parser.dart`), strict
exclusion rules (OTP / promo / not-executed / balance-only / unknown sender),
two-level dedup (fingerprint + semantic key), review queue (`sms_inbox`), confirm
= one ledger transaction, discard = none, raw text purged once resolved,
paste/share import UI, optional daily reminder.

NOT implemented: automatic inbox reading.
* iOS cannot read Messages at all (platform restriction) - paste/share import only.
* Android `READ_SMS`: Google Play restricts this permission to apps that qualify
  for a declared exception. The permission is deliberately NOT in the manifest.
  To add an Android reader later: native `ContentResolver` query over a
  MethodChannel feeding `Repo.ingestSms`, behind a build flavour, plus the Play
  Console permissions declaration. The parser and review flow need no change.

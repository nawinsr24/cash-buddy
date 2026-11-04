# SMS assistant

## Android (sideloaded build)
* Turning the SMS assistant on shows the system **READ_SMS** permission dialog.
  Denied -> the toggle stays off. Granted -> the inbox is scanned (first scan: last 30 days).
* `MainActivity.kt` reads `content://sms/inbox` on-device and passes messages to the
  Dart parser. Nothing is uploaded. Re-scans happen on app open/resume and via
  "Scan messages". Incremental, deduplicated.
* Only transaction-looking messages from bank-like senders become *candidates*;
  the user confirms or discards each one. OTPs, promos, failed/pending and
  balance-only messages are ignored.
* Google Play restricts READ_SMS. This build is distributed as a direct APK, so it
  is fine; a Play Store release would need a permissions declaration or a
  different approach (user-initiated import only).

## iOS / web
No inbox access exists. Use paste import in the Inbox tab.

## Daily review reminder
Settings > SMS assistant > Daily review reminder asks for notification permission,
schedules the reminder and reports failures. "Send a test notification" verifies it.

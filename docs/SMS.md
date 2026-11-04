# SMS assistant

## Android (sideloaded APK)
* Turning the assistant on shows the system **SMS** permission dialog (READ_SMS + RECEIVE_SMS).
  Denied -> stays off. Granted -> the last 30 days are scanned.
* **Real time:** `SmsReceiver.kt` fires when an SMS arrives. If it looks like an executed
  transaction it posts a "New transaction detected" notification; tapping it opens the Inbox.
  Nothing is stored or uploaded by the receiver.
* **Scanning:** on app open/resume (and "Scan messages") `MainActivity.kt` reads
  `content://sms/inbox`; Dart applies the real parser + dedup and queues *candidates*.
  Only you confirm or discard. OTP / promo / failed / pending / balance-only are ignored.
* Daily review reminder: set time in Settings; shows "N transactions are waiting" and is
  rescheduled whenever the count changes; nothing is shown when nothing is pending.
  "Send a test notification" verifies permission.
* Google Play restricts SMS permissions: this is a direct-APK build. A Play release would
  need a permissions declaration or a user-initiated-only design.

## iOS / web
No inbox access exists. Paste import is available in the Inbox tab as a fallback only.

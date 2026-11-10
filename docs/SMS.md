# Bank alerts (automatic entries)

Cash++ never opens the SMS inbox and has no SMS permission. It uses Android's
**notification access** instead:

* Turning on "Add entries from bank messages" opens Android's notification access
  screen, where the user switches on Cash++.
* `BankAlertListener.kt` sees notifications from the phone's messaging app only
  (the default SMS app, well-known ones, or an app that looks like one). Every
  other notification from every other app is ignored at once and never stored.
* If the text looks like an executed bank transaction, the alert waits in
  `BankAlertQueue.kt` (private app storage, left out of backups, emptied when the
  app takes it, at most 200 alerts for 7 days) and a private "tap to review"
  notification is shown (lock screen shows a generic line only).
* When the app opens, Dart takes the queue, applies the real parser
  (`lib/domain/sms_parser.dart`), removes duplicates and puts candidates in
  "Bank messages to review". The user confirms or ignores each one. Nothing is
  added without a confirmation, and nothing leaves the phone.
* Older messages: copy and paste or share them ("Add from a copied message").
* iPhone: no automatic entries; paste, share or manual entry only.

Limits: only alerts that arrive after access is switched on; the messaging app
must show notifications; battery savers can stop the listener on some phones.

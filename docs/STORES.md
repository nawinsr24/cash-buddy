# Store builds (Google Play, App Store, sideload)

One codebase, one package id (`com.denovo.cash_buddy`, never change it).

| Build | How it is made | SMS reading |
|---|---|---|
| **sideload** (the APK people install from the link) | `android.yml` on every push: `flutter build apk --flavor sideload` | Notifications only |
| **play** (Google Play) | `play-bundle.yml`, run by hand: `flutter build appbundle --flavor play --dart-define=STORE=play` | Notifications only |
| **iOS** | not set up yet (needs the $99 Apple Developer account, then TestFlight) | Never: iOS cannot read messages. The option is hidden; manual entry and paste / share instead |

## Bank alerts on both stores
Neither build has an SMS permission. Both read bank alerts from notifications
(see `docs/SMS.md`), so no Google SMS exception is needed. The Play and sideload
builds therefore behave the same; they stay separate only for packaging.

## Cloud switch
`web/flags.json` is published with the web app at
`https://nawinsr24.github.io/cash-buddy/app/flags.json`. The app downloads it at most
once a day (no user data is sent) and remembers the answer. Setting
`"sms_reading": {"android": false}` hides automatic entries in builds that have it.
It cannot add a permission a build does not declare.

## Security summary
- Database: SQLite3MultipleCiphers, key in Android Keystore / iOS Keychain.
- Android backup excludes the database and keys; data returns through Drive sync.
- Drive sync and backup files: AES-256-GCM, key from the user's passphrase (PBKDF2).
- Recent-apps preview hidden by default; lock-screen notifications are private.
- Release builds are obfuscated; `debug-symbols` is saved as a build artifact.
- `dependency check` workflow runs `tool/check_vulns.py` (osv.dev) weekly and on push.
- Still to do before launch: outside penetration test (VAPT), privacy policy hosting.

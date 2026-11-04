# Cash Buddy

Offline-first personal finance app (Flutter, iOS + Android). Spec / build prompt: `IMPLEMENTATION_PROMPT.md`.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift code
flutter test            # 90+ tests: domain, ledger, debts, sync, SMS, UI, perf
flutter analyze
flutter run             # needs Xcode / Android SDK
```

Stack: Flutter 3 + Dart 3, drift (SQLite), Riverpod, fl_chart. See `docs/` for
SMS and Google Drive notes and `STATUS.md` for what is verified vs not.

## Install on Android (test build)
Every push to `main` builds an APK in GitHub Actions and publishes it as the
**latest** pre-release: `https://github.com/nawinsr24/cash-buddy/releases/download/latest/cash-buddy.apk`.
Open that link on your phone, allow "install unknown apps" for your browser when asked, and install.
It is a debug-signed test build, not a Play Store build.

## Web preview
https://nawinsr24.github.io/cash-buddy/ (browser build; data stays in your browser; no Drive sync / notifications).

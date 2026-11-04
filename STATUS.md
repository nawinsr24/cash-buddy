# Cash Buddy: status (2026-11-04)

Verified by automated tests (`flutter test`: 90 pass, `flutter analyze`: clean)

| Area | Evidence |
|---|---|
| Money / dates / interest engine | exact-value tests, half-even rounding, month-end anchoring, property test (conservation, determinism) |
| Ledger + balances | derived from transactions; random 300-op property test vs independent model |
| Combined <-> Split switch | total balance identical before/after, no duplicate accounts |
| Debts | lend/borrow/accrue/repay/settle/delete; rules in the posting table hold (principal never counts as income/spending; interest does only when received/paid); reconcile is idempotent (no row or version churn); overpayment rejected |
| SMS | parser accept/reject corpus (synthetic), dedup, confirm-only ledger writes, text purge |
| Sync engine | in-memory remote: failures, corrupt segment, LWW, tombstones, clock skew, debts converge, 3-device random simulation converges with zero loss and reaches quiescence |
| Offline Mode | spy remote receives 0 calls |
| UI | onboarding, dashboard, add txn, search, debts, inbox, settings, dark mode, overflow checks (320px/2x text, tablet), semantics |
| Performance | dashboard over 100k rows: ~33 ms |

NOT verified / NOT built (be honest before shipping)

* **Never run on a device or simulator**: this Mac has no Xcode or Android SDK. UI was checked via widget tests and rendered screenshots (`test/screens`, output `build/screens/`).
* **Google Drive**: `DriveRemote` compiles but was never run against Google (needs your OAuth client, docs/SETUP_GOOGLE_DRIVE.md).
* **No client-side encryption** of Drive payloads or the local DB (no SQLCipher), **no app lock**.
* **No background sync** (WorkManager/BGTask); sync runs on foreground + 45 s after changes.
* **Android automatic SMS reading not built** (iOS impossible); paste/share import only (docs/SMS.md). Share-sheet receiving extension not built.
* **Notifications** (8:00 reminder) written, untested; debt due-date reminders not built.
* Not built: backup restore UI, export CSV, localisation, mode-switch chooser UI for "existing Drive data" (sync merges; never overwrites), top-up lending on an existing debt, multi-currency.

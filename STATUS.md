# Cash++: status (2026-11-04)

Verified by automated tests (`flutter test`: 231 pass, `flutter analyze`: clean)

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
| Investments | mutual fund / stock / chit entries post one ledger leg each (never spending or income); global + per-entry balance rules; lending rule; XIRR + projection; two-device sync convergence |
| Monthly title / grade | 15 titles by fixed rules in priority order; Money Grade parts add to 100; title stored once per finished month; banner first 7 days; health note always kind and pauses roasts when health is 30%+ of spend; insights (forecast, net worth, recurring bills) |
| Budget | strictly-under / exactly-equal / over against one overall budget; category splits are a guide; spend excludes investments and lent principal; finished months frozen; Online Mode now says clearly when Google sign-in is not configured |
| Money Health | six parts (budget included; left out and rescaled when no budget is set), named levels, trend vs last month and 12-month history; live title decided daily; month-end celebration with last-month comparison; budget, splits and frozen results sync through Drive |
| Performance | dashboard over 100k rows: ~33 ms |

NOT verified / NOT built (be honest before shipping)

* **Never run on a device or simulator**: this Mac has no Xcode or Android SDK. UI was checked via widget tests and rendered screenshots (`test/screens`, output `build/screens/`).
* **Google Drive**: `DriveRemote` compiles but was never run against Google (needs your OAuth client, docs/SETUP_GOOGLE_DRIVE.md).
* **No client-side encryption** of Drive payloads or the local DB (no SQLCipher), **no app lock**.
* **No background sync** (WorkManager/BGTask); sync runs on foreground + 45 s after changes.
* **Android automatic SMS reading not built** (iOS impossible); paste/share import only (docs/SMS.md). Share-sheet receiving extension not built.
* **Notifications** (8:00 reminder) written, untested; debt due-date reminders not built.
* Not built: backup restore UI, export CSV, localisation, mode-switch chooser UI for "existing Drive data" (sync merges; never overwrites), top-up lending on an existing debt, multi-currency.

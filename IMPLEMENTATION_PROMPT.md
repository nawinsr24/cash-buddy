# Cash++ — Implementation Prompt for Claude Code / Cursor

> Paste this whole file (or point the assistant at it) as the first message of a new session in the `cash-buddy/` folder. Work in the phases of section 14. Do not skip ahead; each phase must compile, pass tests, and run on both platforms before moving on.

---

## 0. Role and Mission

You are a senior mobile architect, UI/UX engineer and finance-domain engineer. Build **Cash++**: an **offline-first, cross-platform (iOS + Android) personal finance app** with optional Google Drive sync, debt tracking (receivables and liabilities with interest), an optional SMS transaction assistant, and a four-pillar dashboard.

Non-negotiables: **no data loss, no double-counted balances, no silent failures, local-first speed, premium UI.**

Before writing code: restate the plan, list assumptions, and ask me only about blockers. Otherwise pick the sensible default, document it in `docs/DECISIONS.md`, and continue.

## 1. Tech Stack (defaults — deviate only with a written reason)

| Concern | Choice |
|---|---|
| Framework | **Flutter (stable) + Dart 3, null-safe, `sdk: ^3.x`** — same stack as my existing `TamilTV` app (`~/TamilTV`, `pubspec.yaml`: `flutter_lints`, `shared_preferences`, `http`, `flutter_launcher_icons`). Reuse its conventions (lints, folder layout, `analysis_options.yaml`, icon generation) where sensible. Targets: iOS + Android only |
| Navigation | `go_router` (shell routes + bottom `NavigationBar`/`CupertinoTabBar` adaptive, platform-native transitions) |
| Local DB | SQLite via **`drift`** (+ `sqlite3_flutter_libs`, or `sqlcipher_flutter_libs` for encryption) with versioned, tested migrations |
| State | **Riverpod** (`flutter_riverpod`, `riverpod_generator`) with Drift streams; **the DB is the source of truth** (no duplicated balance state in memory) |
| Charts | `fl_chart` (or custom `CustomPainter`); animated, accessible (`Semantics` summaries) |
| Animation | Flutter implicit/explicit animations, `flutter_animate`, `HapticFeedback` |
| Secure storage | `flutter_secure_storage` (tokens, DB key in Keychain/Keystore); `local_auth` for biometrics |
| Auth/Drive | `google_sign_in` + `googleapis` Drive v3 with **`drive.appdata` scope only** |
| Background | `workmanager` (Android WorkManager / iOS BGTaskScheduler) |
| Notifications | `flutter_local_notifications` + `timezone` (local scheduled reminders) |
| Models | `freezed` + `json_serializable` for immutable domain/sync payload types |
| Testing | `flutter_test`, `mocktail`, `drift` in-memory DB, `glados` or `kiri_check` for property-based tests, `integration_test` (or Maestro) for E2E, golden tests for light/dark |
| Quality | `flutter_lints` (strict), `dart format`, `flutter analyze`, `dart_code_metrics`/`very_good_analysis` optional, GitHub Actions CI |

Money is **never a float**. Store **integer minor units** (paise/cents) plus an ISO‑4217 currency code. Use a small `Money` value-object module (add, sub, allocate, round half-even) with exhaustive tests. Dates: store UTC ISO‑8601 instants for events plus a local `YYYY-MM-DD` "business date" for period bucketing.

## 2. Project Structure

```
cash-buddy/
  pubspec.yaml, analysis_options.yaml
  android/  ios/            # platform projects (SMS channel, WorkManager, entitlements)
  lib/
    main.dart, app.dart, router.dart
    domain/                 # Pure Dart: money, ledger, interest, categories, rules (no Flutter imports)
    data/                   # Drift tables, DAOs, migrations, repositories
    sync/                   # Drive client, op-log, merge, scheduler
    sms/                    # parsers, filters, platform channel bridge, review queue
    features/               # dashboard, transactions, accounts, debts, categories, settings, onboarding
    ui/                     # design system: tokens/ThemeExtension, widgets, charts
    platform/               # permissions, notifications, background tasks
  docs/                     # DECISIONS.md, ARCHITECTURE.md, SYNC.md, SMS.md, PRIVACY.md
  test/  integration_test/
```

`lib/domain` must be Flutter-free pure Dart and ≥90% test-covered.

## 3. Architecture and Data Persistence

### 3.1 Offline-first
- All reads/writes hit local SQLite first. The app is **fully functional with no network, forever**. No screen may block on the network.
- All mutations go through repositories that, in **one SQLite transaction**, (a) write the entity rows, (b) update/derive balances (see 4.4), and (c) append to the **operation log** (`op_log`) when Online Mode is on.
- Soft-delete everywhere (`deleted_at`) so deletions sync and are undoable (undo snackbar for 10 s; purge after 30 days).

### 3.2 First-run setup wizard (explicit choices, one screen each, back-navigable, nothing pre-selected silently)
1. **Data mode:** *Offline Mode* (data never leaves device, no Google sign-in, no network permission usage) vs *Online Mode* (local + Google Drive sync). Explain trade-offs plainly.
2. **Account mode:** *Combined* (one overall balance) vs *Split* (cash + named bank accounts).
3. **Cash/Card distinction:** toggle on/off.
4. Currency, opening balance(s), week start, optional SMS assistant opt-in (can be skipped), reminder time.
5. Seed predefined categories (section 5.3).

All wizard choices are persisted in a `settings` table and editable later.

### 3.3 Switching modes in Settings (with safeguards)
**Offline → Online:** sign in to Google → check Drive `appDataFolder` for an existing Cash++ dataset →
- none found: upload a full snapshot, then begin op-log sync;
- found: show a **merge/replace/keep-local chooser** with record counts and last-modified dates; default to *merge*; always create a local backup file first.

**Online → Offline:** confirm dialog offering (a) *keep local copy, stop syncing* (default), (b) *also delete the Drive data* (typed confirmation). Flush pending ops first; if flush fails, warn and require explicit override. Revoke/forget tokens only on the user's request.

**Combined ⇄ Split:** implement as a **reversible, lossless migration**:
- Combined → Split: create a `Cash` account and a `Bank` account; ask the user how to allocate the existing balance and (optionally) re-tag past transactions by payment method; unassigned history goes to a default account. 
- Split → Combined: do **not** delete accounts; set `account_mode = combined`, aggregate views, and keep per-account rows archived so switching back restores them.
- Total balance before and after must be identical (assert in code and test).

Every migration: pre-flight backup (`.cbbackup` JSON+checksum) → run in a transaction → verify invariants → roll back on failure → write an audit row.

### 3.4 Google Drive sync (battery-efficient, loss-free)
- Scope: **`drive.appdata`** only (hidden app folder; no access to user's other files).
- **Model:** per-device append-only **op-log segments** + periodic **snapshot**.
  - Local `op_log(op_id ULID, device_id, hlc, entity, entity_id, op, payload_json, applied)`.
  - Upload batches as immutable files `ops/<device_id>/<seq>.json.gz` (+ `manifest.json` per device). Never rewrite a remote file in place → no write-write races.
  - Download others' new segments via the manifest/`changes.list` page token; apply in HLC order.
  - Compact into `snapshot-<hlc>.json.gz` when segments > N or > X MB; keep the previous snapshot until the new one is verified.
- **Conflict resolution:** hybrid logical clocks (HLC) + per-field last-writer-wins for scalar edits; **tombstones win over edits older than the delete**; transactions are immutable-ish (edit = new version, same id). **Never merge by summing balances** — balances are *derived* from transactions after merge, then re-verified.
- **Idempotency:** every op has a unique `op_id`; applying the same op twice is a no-op.
- **Integrity:** SHA‑256 per segment, schema version in every file, refuse to apply files from a newer incompatible schema (prompt to update app).
- **Efficiency:** sync triggers = app foreground, debounced 30–60 s after local change, and OS-scheduled background task (≥ 6–12 h, `requiresNetwork`, prefers charging/unmetered Wi‑Fi). Use ETags/page tokens, gzip, batching, exponential backoff with jitter, no polling loops, no wake locks. Provide "Sync now", last-sync time, pending count, and a human-readable error state.
- **Failure handling:** partial uploads resume; quota-exceeded, token-expired, offline, and revoked-consent paths each have a tested UX. Sync must never block or crash the UI.
- **Security:** encrypt the Drive payload client-side (AES‑GCM, key from device-stored secret, optional user passphrase for cross-device restore). Tokens only in Keychain/Keystore. No analytics on financial data. Logs redact amounts/merchants.
- **Backups:** manual export/import of an encrypted local backup file independent of Drive.

Document the protocol in `docs/SYNC.md` and write a **multi-device simulation test** (3 simulated devices, random offline periods, random edits/deletes, assert convergence and zero loss).

## 4. Accounts, Transactions, and the Accounting Core

### 4.1 Accounts
- Combined mode: one logical "Overall" account.
- Split mode: `Cash` + N bank accounts (name, color, icon, opening balance, optional last-4/reference used for SMS matching).
- Cash/Card distinction toggle: when on, every transaction has `payment_method ∈ {cash, card, upi/other-configurable}`; in Split mode this maps to the account; in Combined mode it's a tag used for breakdowns only.

### 4.2 Transactions
Fields: `id, type(credit|debit|transfer), amount_minor, currency, account_id, category_id, subcategory_id?, payment_method?, date, note, merchant?, tags?, source(manual|sms|debt|interest|transfer), source_ref?, created_at, updated_at, deleted_at`.
Features: add/edit/delete(+undo), duplicate, bulk select, **search** (text, amount range), **filters** (date range, type, category/sub, account, payment method, source), grouped history by day with sticky headers, virtualized `SliverList`/`ListView.builder` with sticky headers, swipe actions, CSV export.
Transfers between accounts (Split mode) are one logical transfer = two linked legs; they must **not** count as income or spending on the dashboard.

### 4.3 Categories
- **Credit categories (predefined, editable):** Salary, Cash Received, Interest Income, Refund, Gift, Other Income.
- **Debit categories: two levels** (main → sub). Seed examples: Entertainment → Movies/Streaming/Games; Food → Groceries/Dining/Coffee; Transport → Fuel/Cab/Public; Bills → Rent/Electricity/Internet; Health; Shopping; Education; Travel; Other.
- Users can create/rename/recolor/re-icon/reorder/archive categories and subcategories, move a subcategory to another parent, and merge categories. Deleting a category with history requires reassignment (never orphan). Seeded categories use stable IDs so sync doesn't duplicate them across devices.
- Spending rolls up: a main category total = itself + all subcategories.

### 4.4 Balance integrity (critical)
- **Balance = opening_balance + Σ(signed, non-deleted transactions for the account)**. Treat the transaction ledger as the single source of truth.
- You may cache balances in a table for speed, but only via **SQLite triggers or a single repository function inside the same transaction**; provide `recomputeAllBalances()` and a startup/debug **invariant check** (cached == recomputed). Any mismatch is auto-healed and logged.
- Editing a transaction = reverse old effect + apply new effect atomically. Changing account/amount/type/date must update both affected accounts and the dashboard.
- Property-based tests: random sequences of add/edit/delete/transfer/switch-mode never break the invariant.

## 5. Debt Module (Receivables and Liabilities)

### 5.1 Model
`debts(id, direction(receivable|liability), counterparty, principal_minor, currency, issued_on, due_on?, interest_enabled, interest_type(simple|compound), rate_bps, rate_period(daily|weekly|monthly|yearly), compounding_frequency?, accrual_start, day_count_convention, schedule_type(none|bullet|installments), status(open|partially_paid|settled|written_off), notes, ...)`
`debt_events(id, debt_id, type(issue|interest_accrual|repayment|adjustment|write_off), amount_minor, principal_part, interest_part, date, linked_txn_id?, period_key?)`
`repayment_schedule(debt_id, installment_no, due_on, principal_due, interest_due, status)`.

### 5.2 Rules
- Support **interest-free** and **interest-bearing** debts; configurable rate, **simple vs compound**, and frequency (e.g., 2% monthly, 12% yearly). Use basis-point integers; round half-even at defined points; document the day-count convention.
- **Accrual engine** (pure function in `domain/interest`): given debt, events, and `asOf`, compute accrued interest deterministically. Persist accruals **idempotently** with a unique key `(debt_id, period_key)`; running the accrual job twice, on two devices, or after a crash produces the same rows. Run on app open + background task + when viewing a debt (catch-up for missed periods).
- **Repayment allocation order** (configurable, default): interest first, then principal. Partial repayments supported; overpayment prompts (record as new debt/credit or reject).
- **Outstanding = principal + accrued interest − repayments** (split into outstanding principal and outstanding interest).
- Full history timeline per debt: issue, each accrual, each repayment, adjustments, write-off.

### 5.3 Balance effects — avoid double counting
Define a single posting table in `docs/ACCOUNTING.md`, implement it once in `domain/ledger`, and test it:

| Event | Cash/account effect | Debt effect | Dashboard |
|---|---|---|---|
| Lend money (receivable issued) | **debit** account by principal (source=`debt`) | +receivable | **not** "Spending"; raises Incoming Debts |
| Receive repayment (principal) | **credit** account | −receivable | **not** "Income"; lowers Incoming Debts |
| Receive interest | credit account | −receivable interest | counts as **Income** (Interest Income) *only when received* |
| Accrue interest (receivable) | none (non-cash) | +receivable interest | raises Incoming Debts only |
| Borrow money (liability issued) | **credit** account by principal | +liability | **not** "Income"; raises Liabilities |
| Repay lender (principal) | **debit** account | −liability | **not** "Spending"; lowers Liabilities |
| Pay interest | debit account | −liability interest | counts as **Spending** (Interest Paid) *when paid* |
| Accrue interest (liability) | none | +liability interest | raises Liabilities only |

Rules: each debt event creates **at most one** linked ledger transaction (`source_ref = debt_event_id`, unique index) so retries/sync cannot duplicate it. Editing/deleting a debt event reverses and re-applies its linked transaction atomically. Debt-linked transactions are editable only through the debt screen (or show a "managed by debt" lock with a jump link).

### 5.4 UI
Tabs: *Receivables* / *Liabilities*; list with progress bar (repaid %), next due date, overdue badges; detail screen with timeline, schedule, add repayment, add interest manually, adjust, settle, write-off; due-date reminders (local notifications); charts (outstanding over time, principal vs interest, repaid vs remaining, by counterparty).

## 6. Intelligent SMS Transaction Assistant (optional, off by default)

### 6.1 Platform reality (implement exactly this)
- **Android:** read SMS via a small native module using `READ_SMS` (+ optionally `RECEIVE_SMS`) with a runtime permission request and a clear rationale screen. **Google Play restricts these permissions**; implement behind a build flavor/feature flag, document the Play Console *Permissions Declaration* requirements and the risk in `docs/SMS.md`, and ship a **fallback** (below) so the app works without the permission. Process **on-device only**; never upload raw SMS to Drive or any server.
- **iOS:** apps **cannot read the Messages inbox**. Do not attempt private APIs. Provide user-initiated alternatives: (a) **Share Sheet / "Share to Cash++"** and paste-from-clipboard import of one or many messages; (b) optional Shortcuts/App Intents action ("Add transaction from text") that users can trigger from a Messages automation; (c) bank-notification email/CSV/PDF statement import (stretch).
- **Android fallback:** same paste/share import, plus optional `NotificationListenerService` (explicit user opt-in, bank-app notifications only).
- All parsing code lives in `lib/sms/parsers` as **pure Dart** shared by every ingestion path, so behavior is identical on both platforms.

### 6.2 Parsing
- Registry of **recognized senders** (e.g., sender-ID patterns such as `XX-HDFCBK`, `AX-SBIINB`) → per-bank regex/templates with versioning and a test corpus (`__tests__/sms/fixtures/*.json`, ≥ 20 real-style samples per major bank, anonymized).
- Extract: direction (credit/debit), amount, currency, date/time, merchant/payee/UPI VPA, account reference (last‑4), available balance (stored only as a hint), reference/UTR number.
- **Strict exclusion filter** (reject unless an actual money movement is confirmed): OTP/verification codes, promotional/offer/loan-pitch messages, links with "click/avail/apply", balance-only / mini-statement alerts, "will be debited"/"failed"/"declined"/"reversed pending" language, marketing sender types, unknown senders. Prefer false negatives over false positives; every rejection reason is logged locally for a "Why was this ignored?" debug view.
- **Dedup:** fingerprint = hash(sender, normalized body, amount, timestamp-bucket) and a second semantic key = (account_ref, amount, direction, reference/UTR or ±2 min window). Skip anything already pending, confirmed, or discarded; also detect a matching manual transaction and offer "link instead of add".
- Auto-suggest category from merchant rules the user previously confirmed (learned mapping, on-device).

### 6.3 Review flow
- Candidates land in `sms_inbox(status: pending|confirmed|discarded)` — **never** written to the ledger until confirmed.
- On app launch, and at a **user-configurable daily reminder** (default 8:00 AM; local notification showing "N transactions to review"), show a summary card → review screen: swipe/tap **✓ Confirm** or **✕ Discard** per row, inline edit of amount/category/account/note, "Confirm all" with a double-check for bulk, undo.
- Confirm = create a normal transaction (`source=sms`, `source_ref=fingerprint`, unique index) inside one transaction with the inbox status update.
- Settings: enable/disable parsing, enable/disable reminder, reminder time, sender allow/deny list, clear processed history, "Delete all stored SMS text" (store only parsed fields by default; keep raw text only for pending items, purge on resolve).
- Privacy: in-app privacy explainer, permission rationale before the OS prompt, graceful handling of permission denial/revocation, nothing breaks if disabled.

## 7. Four-Pillar Dashboard

Four primary metrics for the **selected period** (default: **current calendar month**):
1. **Total Spending** = Σ debit transactions in range, excluding transfers and debt principal movements (see 5.3).
2. **Total Income** = Σ credit transactions in range, excluding transfers and debt principal movements.
3. **Incoming Debts** = outstanding receivables (principal + accrued interest − repayments), as of the end of the range (and "currently").
4. **Liabilities** = outstanding amounts owed, same basis.

Features:
- Period selector: This Month (default), Last Month, Last 7/30/90 days, This Quarter, This Year, Custom range (date picker). Persist last choice per session but default to current month on cold start. Show comparison vs previous equivalent period (▲▼ %).
- Each pillar is a tappable card with a headline number, delta, sparkline, and drills into a **dedicated detail screen** with its own chart(s):
  - Spending: category donut + trend line/bars by day/week, top merchants, main→sub drill-down, cash vs card split (if enabled), per-account split (Split mode).
  - Income: source breakdown, trend, month-over-month.
  - Incoming Debts: outstanding by counterparty, principal vs interest, due/overdue timeline, repaid vs remaining.
  - Liabilities: same set, plus upcoming payment calendar.
- Net position summary (balance + incoming − liabilities) and account balances (Split) or overall balance (Combined).
- **Calculation rules:** all figures derive from SQL aggregate queries over the single ledger/debt tables (no hand-maintained totals); use the same query layer for charts and numbers so they can never disagree; period boundaries use the local business date and device time zone; debt metrics are **as-of** computations; recompute reactively after any write; large datasets (100k transactions) must render the dashboard in < 300 ms (indexes on `(date)`, `(category_id, date)`, `(account_id, date)`; test with a seeded benchmark).
- Empty, loading (skeleton), and error states for every chart; charts have accessible text summaries.

> *Spec note: the source brief was cut off mid-sentence at "Ensure the calculations are…". Implemented here as: calculations are consistent, deterministic, reconcilable to the ledger, and tested. If the original continued with more requirements, add them in `docs/DECISIONS.md` and update this prompt.*

## 8. Design System

- Premium, modern fintech feel (clean surfaces, generous whitespace, large rounded cards, tabular-figure numerics, restrained accent color, subtle depth). Take cues from leading finance apps; do **not** copy any brand's assets.
- **Design tokens** in `src/ui/tokens`: 4/8‑pt spacing scale, radii, type scale (system fonts: SF Pro on iOS, Roboto/Google Sans on Android, `tabular-nums` for money), elevation, semantic colors (`surface`, `surfaceRaised`, `textPrimary/Secondary`, `income`, `spending`, `debtIn`, `liability`, `warning`, `danger`, `accent`), category palette (≥ 16 colors, all passing contrast).
- **Light/Dark:** follow the system appearance live (`ThemeMode.system`, `MediaQuery.platformBrightness`, light/dark `ThemeData` built from the same tokens), no flash on launch, optional manual override in Settings. Charts, status bar, keyboard, and navigation bars all theme correctly. WCAG AA contrast.
- **Motion:** 150–300 ms spring/ease transitions, animated number count-ups, chart draw-in, list item enter/exit, haptics on confirm/discard/delete (respect Reduce Motion).
- **Platform conventions:** iOS — large titles, swipe-back, SF Symbols-style icons, action sheets, native date pickers; Android — Material 3 behaviors, back gesture, bottom sheets, FAB for "Add", edge-to-edge. Same information architecture and features on both.
- **Navigation:** bottom tabs: Dashboard · Transactions · Debts · (SMS Inbox badge) · Settings; global quick-add button; fast keypad-first amount entry (< 3 taps for a typical expense).
- Responsive: phones and tablets, small screens (iPhone SE), large text/Dynamic Type (`MediaQuery.textScaler`), landscape safe. Full accessibility: labels, roles, focus order, screen-reader chart summaries, 44/48 pt targets.
- Localization-ready (i18n framework, currency/number/date formatting via `intl` + `flutter_localizations`/ARB); ship English, RTL-safe layout.

## 9. Settings Screen (all must be wired)

Data mode (Offline/Online + sync status/Sync now/last sync/errors), Account mode (Combined/Split), Cash/Card distinction, Accounts, Categories, Currency, Appearance (System/Light/Dark), Debt defaults (interest convention, repayment allocation), SMS assistant (enable, reminder, time, senders, purge), Notifications, Security (app lock via biometrics/PIN, hide balances), Backup/Export/Import, Privacy & data deletion, About/Diagnostics (invariant check, DB size, logs with redaction).

## 10. Security and Privacy

- Encrypt DB at rest (SQLCipher or file-level with Keystore/Keychain-held key); optional biometric/PIN app lock with auto-lock and blurred app-switcher snapshot.
- No third-party analytics/ads/SDKs touching financial data; crash reporting (if any) scrubbed and opt-in.
- Least-privilege permissions; explain each; handle denial everywhere. Prepare App Store privacy nutrition labels and Play Data Safety answers in `docs/PRIVACY.md`.
- Account deletion/“delete all my data” flow removing local and (if online) Drive data.

## 11. Error Handling and Reliability

- Every repository method returns typed results; no swallowed exceptions; global error boundary; user-facing messages are actionable.
- Crash-safe: all multi-step writes are transactional; schema migrations are forward-only, tested from every previous version with fixture DBs.
- Automatic local backup before each migration and weekly rolling backups (keep last 5).

## 12. Testing Requirements

- **Unit:** money math, interest accrual (simple/compound, each frequency, leap years, partial repayments, overpay), allocation order, ledger posting table, category rollups, period boundaries/time zones, SMS parsers + exclusion filter against fixture corpus (include adversarial OTP/promo samples), dedup.
- **Property-based:** balance invariant, idempotent accrual, op-log merge convergence, mode-switch conservation of total balance.
- **Integration:** migrations, repositories with a real SQLite, sync against a **mock Drive server** (fault injection: timeouts, 401, 429, 5xx, quota, partial upload).
- **E2E (`integration_test`/Maestro):** onboarding for all four combinations (online/offline × combined/split), add/edit/delete transaction, lend → accrue → partial repay → settle, borrow → repay, SMS review confirm/discard, mode switches, dark mode screenshots.
- **Performance:** seeded 100k transactions; scroll 60 fps; cold start < 2 s on mid-range Android.
- CI: lint, typecheck, unit/integration on every PR; E2E nightly.

## 13. Definition of Done (global)

1. Runs on iOS simulator and Android emulator from a clean clone with documented commands in `README.md`.
2. No balance discrepancy in any test; invariant check passes after every E2E scenario.
3. Offline Mode makes **zero** network calls (verify with a test/network guard).
4. Light/Dark switches live with the system setting on both platforms.
5. Debt events never double-post (unique-index enforced and tested).
6. SMS items never hit the ledger before explicit confirmation; duplicates never re-surface.
7. Docs written: ARCHITECTURE, ACCOUNTING, SYNC, SMS, PRIVACY, DECISIONS.
8. All checks green in CI; no `dynamic` in domain code, `flutter analyze` clean; no TODOs left unlisted in `docs/DECISIONS.md`.

## 14. Delivery Phases (stop and summarize after each)

1. **Foundation:** repo, tooling, CI, design tokens, theming, navigation shell, DB + migrations, `Money` module.
2. **Core ledger:** accounts, categories (2-level), transactions CRUD/search/filter, balance invariant, onboarding wizard (offline).
3. **Dashboard:** period selector, four pillars, charts, drill-downs (debts stubbed at zero).
4. **Debts:** model, accrual engine, repayment allocation, posting rules, UI, reminders, debt charts wired into dashboard.
5. **Modes:** Combined⇄Split migration, backup/restore, Offline→Online chooser flow.
6. **Sync:** Google auth, op-log, snapshots, merge, scheduler, fault-injection + multi-device simulation tests.
7. **SMS assistant:** parser library + fixtures, exclusion/dedup, Android native module (flagged), iOS/Android share-paste import, review UI, 8:00 AM reminder.
8. **Polish and hardening:** animations, accessibility, security (lock, encryption), performance pass, store-readiness docs.

## 15. Working Rules for the Assistant

- Work incrementally; run typecheck + tests before declaring a phase done; show me the commands and results.
- Never invent bank SMS formats as "real"; label fixtures as synthetic/anonymized.
- If a requirement conflicts with a platform rule (notably iOS SMS access, Play SMS policy, background execution limits), implement the compliant alternative above and record it in `docs/DECISIONS.md`.
- Prefer small, reviewable commits with clear messages. Ask before adding any dependency not listed in section 1.

**Start now with Phase 1.** First output: the plan, assumptions, and the exact folder/file list you will create.

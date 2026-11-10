import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../domain/hlc.dart';
import 'gzip_codec.dart';
import 'vault.dart';

/// Minimal immutable-object store (Google Drive appDataFolder in production,
/// in-memory in tests). Files are write-once: no remote file is ever rewritten.
abstract class RemoteStore {
  Future<List<String>> list();
  Future<List<int>> read(String name);
  Future<void> write(String name, List<int> bytes);
}

class InMemoryRemote implements RemoteStore {
  final Map<String, List<int>> files = {};
  int failNextWrites = 0;
  int failNextReads = 0;
  int writes = 0;

  @override
  Future<List<String>> list() async => files.keys.toList()..sort();

  @override
  Future<List<int>> read(String name) async {
    if (failNextReads > 0) {
      failNextReads--;
      throw Exception('simulated network error');
    }
    return files[name]!;
  }

  @override
  Future<void> write(String name, List<int> bytes) async {
    if (failNextWrites > 0) {
      failNextWrites--;
      throw Exception('simulated network error');
    }
    if (files.containsKey(name)) {
      throw StateError('immutable file exists: $name');
    }
    files[name] = bytes;
    writes++;
  }
}

class SyncResult {
  final int pushedRows;
  final int pulledRows;
  final int segmentsApplied;
  final String? error;
  const SyncResult(
    this.pushedRows,
    this.pulledRows,
    this.segmentsApplied, [
    this.error,
  ]);
  bool get ok => error == null;
}

/// The steps of a sync, reported so the UI can show real progress.
enum SyncStage { signingIn, finding, downloading, merging, rebuilding, sending }

typedef SyncProgressFn = void Function(SyncStage stage, int done, int total);

/// State-based, row-level last-writer-wins sync over immutable segment files.
///
///  * Every synced row has an HLC `hlc` (version) + `deleted_at` tombstone.
///  * Push: rows with hlc > lastPushed go into one gzip segment
///    `seg/<device>/<seq>.json.gz` with a SHA-256 over its payload.
///  * Pull: unseen segments of *other* devices are verified and merged; a
///    remote row wins only if its hlc is newer (ties: higher device id).
///  * Balances are never merged — they are derived from merged transactions.
///    Derived debt data (accruals, allocations, ledger legs) is deterministic
///    and re-reconciled after every pull, so concurrent edits converge.
class SyncEngine {
  static const schema = 1;
  final Repo repo;
  final RemoteStore remote;
  final String deviceId;
  final SyncProgressFn? onProgress;

  /// When set, every file is encrypted before it leaves the phone. Older
  /// unencrypted files are still readable.
  final Vault? vault;
  SyncEngine(
    this.repo,
    this.remote,
    this.deviceId, {
    this.onProgress,
    this.vault,
  });
  void _p(SyncStage s, [int done = 0, int total = 0]) =>
      onProgress?.call(s, done, total);

  AppDatabase get db => repo.db;
  Hlc get clock => repo.clock;

  static const _tables = [
    'accounts',
    'categories',
    'transactions',
    'debts',
    'debt_events',
    'investments',
    'investment_entries',
    'budget_items',
  ];

  Future<SyncResult> sync() async {
    var pushed = 0, pulled = 0, segs = 0;
    try {
      // Pull first so our reconcile sees the latest state, then push.
      final pull = await _pull();
      pulled = pull.$1;
      segs = pull.$2;
      pushed = await _push();
      await repo.setSetting('lastSyncAt', repo.now().toUtc().toIso8601String());
      await repo.setSetting('lastSyncError', '');
      return SyncResult(pushed, pulled, segs);
    } catch (e) {
      await repo.setSetting('lastSyncError', e.toString());
      return SyncResult(pushed, pulled, segs, e.toString());
    }
  }

  // ───────────── push ─────────────
  Future<Map<String, List<Map<String, dynamic>>>> _changedSince(
    String since,
  ) async {
    final out = <String, List<Map<String, dynamic>>>{};
    Future<void> grab<T extends Table, D>(
      String key,
      TableInfo<T, D> t,
      GeneratedColumn<String> hlcCol,
    ) async {
      final rows = await (db.select(
        t,
      )..where((_) => hlcCol.isBiggerThanValue(since))).get();
      if (rows.isNotEmpty) {
        out[key] = [
          for (final r in rows) (r as dynamic).toJson() as Map<String, dynamic>,
        ];
      }
    }

    await grab('accounts', db.accounts, db.accounts.hlc);
    await grab('categories', db.categories, db.categories.hlc);
    await grab('transactions', db.transactions, db.transactions.hlc);
    await grab('debts', db.debts, db.debts.hlc);
    await grab('debt_events', db.debtEvents, db.debtEvents.hlc);
    await grab('investments', db.investments, db.investments.hlc);
    await grab(
      'investment_entries',
      db.investmentEntries,
      db.investmentEntries.hlc,
    );
    await grab('budget_items', db.budgetItems, db.budgetItems.hlc);
    return out;
  }

  Future<int> _push() async {
    final since = await repo.getSetting('lastPushedHlc') ?? '';
    final rows = await _changedSince(since);
    if (rows.isEmpty) return 0;
    var maxHlc = since;
    var count = 0;
    for (final list in rows.values) {
      for (final r in list) {
        final h = r['hlc'] as String;
        if (h.compareTo(maxHlc) > 0) maxHlc = h;
        count++;
      }
    }
    _p(SyncStage.sending, 0, count);
    final seq = int.parse(await repo.getSetting('segSeq') ?? '0') + 1;
    final payload = jsonEncode({
      'schema': schema,
      'device': deviceId,
      'seq': seq,
      'rows': rows,
    });
    final envelope = jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
    final name = 'seg/$deviceId/${seq.toString().padLeft(8, '0')}.json.gz';
    final packed = gzipEncode(utf8.encode(envelope));
    await remote.write(
      name,
      vault == null ? packed : await vault!.encrypt(packed),
    );
    // Only advance the cursor after the upload succeeded.
    await repo.setSetting('segSeq', '$seq');
    await repo.setSetting('lastPushedHlc', maxHlc);
    return count;
  }

  // ───────────── pull ─────────────
  Future<(int, int)> _pull() async {
    final applied = (jsonDecode(
      await repo.getSetting('appliedSegs') ?? '[]',
    ) as List).cast<String>().toSet();
    var rows = 0, segs = 0;
    final touchedDebts = <String>{};
    _p(SyncStage.finding);
    final pending = [
      for (final name in await remote.list())
        if (name.startsWith('seg/') &&
            !name.startsWith('seg/$deviceId/') &&
            !applied.contains(name))
          name,
    ];
    for (final name in pending) {
      _p(SyncStage.downloading, segs, pending.length);
      final bytes = await remote.read(name);
      var raw = bytes;
      if (Vault.isEncrypted(raw)) {
        if (vault == null) {
          throw VaultException(
            'Your cloud data is protected with a backup password. Enter it to continue.',
          );
        }
        raw = await vault!.decrypt(raw);
      }
      final env =
          jsonDecode(utf8.decode(gzipDecode(raw))) as Map<String, dynamic>;
      final payload = env['payload'] as String;
      if (sha256.convert(utf8.encode(payload)).toString() != env['sha256']) {
        throw StateError('Corrupt segment $name (checksum mismatch)');
      }
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if ((data['schema'] as int) > schema) {
        throw StateError('Segment $name needs a newer app version');
      }
      _p(SyncStage.merging, segs, pending.length);
      await db.transaction(() async {
        final r = data['rows'] as Map<String, dynamic>;
        for (final t in _tables) {
          for (final row in (r[t] as List? ?? const [])) {
            rows +=
                await _merge(
                  t,
                  (row as Map).cast<String, dynamic>(),
                  touchedDebts,
                )
                ? 1
                : 0;
          }
        }
      });
      applied.add(name);
      segs++;
      await repo.setSetting('appliedSegs', jsonEncode(applied.toList()));
    }
    if (segs > 0) {
      _p(SyncStage.rebuilding, 0, touchedDebts.length);
      var i = 0;
      for (final id in touchedDebts) {
        await repo.reconcileDebt(id);
        _p(SyncStage.rebuilding, ++i, touchedDebts.length);
      }
    }
    return (rows, segs);
  }

  /// Returns true if the remote row won and was written.
  Future<bool> _merge(
    String table,
    Map<String, dynamic> json,
    Set<String> touchedDebts,
  ) async {
    final incoming = json['hlc'] as String;
    clock.observe(incoming);
    final id = json['id'] as String;
    String? local;
    switch (table) {
      case 'accounts':
        local = (await (db.select(
          db.accounts,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'categories':
        local = (await (db.select(
          db.categories,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'transactions':
        local = (await (db.select(
          db.transactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'debts':
        local = (await (db.select(
          db.debts,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'debt_events':
        local = (await (db.select(
          db.debtEvents,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'investments':
        local = (await (db.select(
          db.investments,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'investment_entries':
        local = (await (db.select(
          db.investmentEntries,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
      case 'budget_items':
        local = (await (db.select(
          db.budgetItems,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.hlc;
    }
    if (local != null && local.compareTo(incoming) >= 0) return false;
    switch (table) {
      case 'accounts':
        await db
            .into(db.accounts)
            .insertOnConflictUpdate(Account.fromJson(json));
      case 'categories':
        await db
            .into(db.categories)
            .insertOnConflictUpdate(Category.fromJson(json));
      case 'transactions':
        await db
            .into(db.transactions)
            .insertOnConflictUpdate(Transaction.fromJson(json));
      case 'debts':
        await db.into(db.debts).insertOnConflictUpdate(Debt.fromJson(json));
        touchedDebts.add(id);
      case 'debt_events':
        final e = DebtEvent.fromJson(json);
        await db.into(db.debtEvents).insertOnConflictUpdate(e);
        touchedDebts.add(e.debtId);
      case 'investments':
        await db
            .into(db.investments)
            .insertOnConflictUpdate(Investment.fromJson(json));
      case 'investment_entries':
        await db
            .into(db.investmentEntries)
            .insertOnConflictUpdate(InvestmentEntry.fromJson(json));
      case 'budget_items':
        await db
            .into(db.budgetItems)
            .insertOnConflictUpdate(BudgetItem.fromJson(json));
    }
    return true;
  }
}

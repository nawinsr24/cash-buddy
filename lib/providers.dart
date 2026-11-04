import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db.dart';
import 'data/repo.dart';
import 'domain/dates.dart';

/// Overridden in main() with the real repository (and in tests).
final repoProvider = Provider<Repo>(
  (ref) => throw UnimplementedError('repoProvider not overridden'),
);

/// Bumps every time any table changes; providers watch it to refresh.
final changesProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(repoProvider);
  var i = 0;
  yield i;
  await for (final _ in repo.changes) {
    yield ++i;
  }
});

T _tick<T>(Ref ref, T Function() f) {
  ref.watch(changesProvider);
  return f();
}

class AppSettings {
  final bool onboarded;
  final String accountMode; // combined | split
  final String dataMode; // offline | online
  final bool cashCard;
  final bool smsEnabled;
  final bool reminderEnabled;
  final String reminderTime; // HH:mm
  final String themeMode; // system | light | dark
  final String? lastSyncAt;
  final String? lastSyncError;
  const AppSettings({
    this.onboarded = false,
    this.accountMode = 'combined',
    this.dataMode = 'offline',
    this.cashCard = false,
    this.smsEnabled = false,
    this.reminderEnabled = false,
    this.reminderTime = '08:00',
    this.themeMode = 'system',
    this.lastSyncAt,
    this.lastSyncError,
  });
  bool get split => accountMode == 'split';
  bool get online => dataMode == 'online';
}

final settingsProvider = FutureProvider.autoDispose<AppSettings>((ref) async {
  ref.watch(changesProvider);
  final r = ref.watch(repoProvider);
  Future<String?> g(String k) => r.getSetting(k);
  final err = await g('lastSyncError');
  return AppSettings(
    onboarded: await g('onboarded') == '1',
    accountMode: await g('accountMode') ?? 'combined',
    dataMode: await g('dataMode') ?? 'offline',
    cashCard: await g('cashCard') == '1',
    smsEnabled: await g('smsEnabled') == '1',
    reminderEnabled: await g('reminderEnabled') == '1',
    reminderTime: await g('reminderTime') ?? '08:00',
    themeMode: await g('themeMode') ?? 'system',
    lastSyncAt: await g('lastSyncAt'),
    lastSyncError: (err == null || err.isEmpty) ? null : err,
  );
});

enum PeriodPreset {
  thisMonth,
  lastMonth,
  last7,
  last30,
  last90,
  quarter,
  year,
  custom,
}

class PeriodSel {
  final PeriodPreset preset;
  final DateRange? custom;
  const PeriodSel(this.preset, [this.custom]);

  DateRange resolve([DateTime? now]) => switch (preset) {
    PeriodPreset.thisMonth => DateRange.thisMonth(now),
    PeriodPreset.lastMonth => DateRange.lastMonth(now),
    PeriodPreset.last7 => DateRange.lastDays(7, now),
    PeriodPreset.last30 => DateRange.lastDays(30, now),
    PeriodPreset.last90 => DateRange.lastDays(90, now),
    PeriodPreset.quarter => DateRange.thisQuarter(now),
    PeriodPreset.year => DateRange.thisYear(now),
    PeriodPreset.custom => custom ?? DateRange.thisMonth(now),
  };

  static String label(PeriodPreset p) => switch (p) {
    PeriodPreset.thisMonth => 'This month',
    PeriodPreset.lastMonth => 'Last month',
    PeriodPreset.last7 => '7 days',
    PeriodPreset.last30 => '30 days',
    PeriodPreset.last90 => '90 days',
    PeriodPreset.quarter => 'Quarter',
    PeriodPreset.year => 'Year',
    PeriodPreset.custom => 'Custom',
  };
}

/// Defaults to the current calendar month on every cold start.
class PeriodNotifier extends Notifier<PeriodSel> {
  @override
  PeriodSel build() => const PeriodSel(PeriodPreset.thisMonth);
  void select(PeriodPreset p) => state = PeriodSel(p);
  void custom(DateRange r) => state = PeriodSel(PeriodPreset.custom, r);
}

final periodProvider = NotifierProvider<PeriodNotifier, PeriodSel>(
  PeriodNotifier.new,
);

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  ref.watch(changesProvider);
  final sel = ref.watch(periodProvider);
  return ref
      .watch(repoProvider)
      .dashboard(sel.resolve(ref.watch(repoProvider).now()));
});

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) {
  return _tick(ref, () => ref.watch(repoProvider).accounts());
});

final balancesProvider = FutureProvider.autoDispose<Map<String, int>>((ref) {
  return _tick(ref, () => ref.watch(repoProvider).balances());
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return _tick(ref, () => ref.watch(repoProvider).categories());
});

final debtSummariesProvider = FutureProvider.autoDispose
    .family<List<DebtSummary>, String>((ref, direction) {
      return _tick(
        ref,
        () => ref.watch(repoProvider).debtSummaries(direction: direction),
      );
    });

final pendingSmsProvider = FutureProvider.autoDispose<List<SmsInboxData>>((
  ref,
) {
  return _tick(ref, () => ref.watch(repoProvider).pendingSms());
});

class TxnQuery {
  final TxnFilter filter;
  const TxnQuery(this.filter);
}

class TxnFilterNotifier extends Notifier<TxnFilter> {
  @override
  TxnFilter build() => const TxnFilter();
  void set(TxnFilter f) => state = f;
}

final txnFilterProvider = NotifierProvider<TxnFilterNotifier, TxnFilter>(
  TxnFilterNotifier.new,
);

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((
  ref,
) async {
  ref.watch(changesProvider);
  final f = ref.watch(txnFilterProvider);
  return ref.watch(repoProvider).searchTransactions(f, limit: 1000);
});

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/diag.dart';
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import 'dashboard.dart';
import 'debts.dart';
import '../ui/motion.dart';
import 'inbox.dart';
import 'invest.dart';
import 'settings.dart';
import 'transactions.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => ShellState();
}

class ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int _index = 0;

  StreamSubscription<void>? _writeSub;
  int _writesThisSecond = 0;
  Timer? _writeTimer;

  /// Automatic scans in the last minute, app-wide. A safety net: if anything
  /// ever makes scans repeat, they stop instead of looping.
  static final _scanTimes = <DateTime>[];
  static DateTime? _pausedUntil;

  @override
  void initState() {
    super.initState();
    Diag.instance.log('Shell created');
    WidgetsBinding.instance.addObserver(this);
    Notifications.instance.openInboxRequests.addListener(_openInbox);
    // record how fast the database changes, to spot runaway writes
    _writeSub = ref
        .read(repoProvider)
        .changes
        .listen((_) => _writesThisSecond++);
    _writeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_writesThisSecond >= 4) {
        Diag.instance.log('database changes: $_writesThisSecond in 1s');
      }
      _writesThisSecond = 0;
    });
    _autoScan();
  }

  @override
  void dispose() {
    Diag.instance.log('Shell disposed');
    _writeSub?.cancel();
    _writeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    Notifications.instance.openInboxRequests.removeListener(_openInbox);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Diag.instance.log('lifecycle: ${state.name}');
    if (state == AppLifecycleState.resumed) _autoScan();
  }

  DateTime? _lastAutoScan;

  /// Quietly look for new bank messages when the app opens or returns.
  /// Rate-limited, so quick back-and-forth (a permission dialog, a share
  /// sheet) never fires scan after scan.
  Future<void> _autoScan() async {
    final nowT = DateTime.now();
    if (_pausedUntil != null && nowT.isBefore(_pausedUntil!)) return;
    if (_lastAutoScan != null &&
        nowT.difference(_lastAutoScan!) < const Duration(seconds: 20)) {
      Diag.instance.log('auto-scan skipped (too soon)');
      return;
    }
    _scanTimes.removeWhere(
      (t) => nowT.difference(t) > const Duration(minutes: 1),
    );
    _scanTimes.add(nowT);
    if (_scanTimes.length > 4) {
      _pausedUntil = nowT.add(const Duration(minutes: 10));
      Diag.instance.log(
        'auto-scan PAUSED 10 min: ${_scanTimes.length} in a minute',
      );
      return;
    }
    Diag.instance.log('auto-scan');
    _lastAutoScan = nowT;
    ref.invalidate(bannerTitleProvider);
    final repo = ref.read(repoProvider);
    final enabled = await repo.getSetting('smsEnabled') == '1';
    if (SmsReader.supported) {
      await SmsReader.instance.setSecure(
        await repo.getSetting('appLock') == '1',
      );
      await SmsReader.instance.setAutoDetect(enabled);
      if (enabled) await scanSmsInbox(repo);
      // opened from a "new transaction" notification
      if (await SmsReader.instance.consumeLaunchAction() == 'inbox') {
        _openInbox();
      }
    }
    await refreshReminder(repo);
  }

  bool _inboxOpen = false;

  /// The Inbox is a full-screen page (from the Home banner, the Activity
  /// toolbar or a notification), not a tab, so the bar stays at five items.
  Future<void> _openInbox() async {
    if (!mounted || _inboxOpen) return;
    if (!(ref.read(settingsProvider).value?.smsEnabled ?? false)) return;
    _inboxOpen = true;
    await Navigator.of(context).push(softRoute(const InboxPage()));
    _inboxOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider); // keeps Online Mode syncing from launch
    final settings = ref.watch(settingsProvider).value;
    final pending = ref.watch(pendingSmsProvider).value?.length ?? 0;
    // only when the number waiting actually changes, not on every refresh
    ref.listen(pendingSmsProvider, (prev, next) {
      if (prev?.value?.length != next.value?.length) {
        refreshReminder(ref.read(repoProvider));
      }
    });
    final tabs = <_Tab>[
      _Tab(
        'Home',
        Icons.dashboard_outlined,
        Icons.dashboard,
        DashboardPage(
          onOpenInbox: _openInbox,
          onOpenInvest: () => _select(_indexOf('Invest')),
        ),
      ),
      _Tab(
        'Activity',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        TransactionsPage(
          onOpenInbox: (settings?.smsEnabled ?? false) ? _openInbox : null,
          inboxBadge: pending,
        ),
        badge: pending,
      ),
      _Tab(
        'Debts',
        Icons.handshake_outlined,
        Icons.handshake,
        const DebtsPage(),
      ),
      _Tab(
        'Invest',
        Icons.trending_up_outlined,
        Icons.trending_up,
        const InvestPage(),
      ),
      _Tab(
        'Settings',
        Icons.settings_outlined,
        Icons.settings,
        const SettingsPage(),
      ),
    ];
    final i = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(tabs[i].label), child: tabs[i].page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: _badge(t, Icon(t.icon)),
              selectedIcon: _badge(t, Icon(t.selectedIcon)),
              label: t.label,
            ),
        ],
      ),
    );
  }

  int _indexOf(String label) {
    const labels = ['Home', 'Activity', 'Debts', 'Invest', 'Settings'];
    return labels.indexOf(label).clamp(0, labels.length - 1);
  }

  void _select(int i) => setState(() => _index = i);

  Widget _badge(_Tab t, Widget icon) =>
      t.badge > 0 ? Badge(label: Text('${t.badge}'), child: icon) : icon;
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final int badge;
  _Tab(this.label, this.icon, this.selectedIcon, this.page, {this.badge = 0});
}

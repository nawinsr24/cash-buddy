import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import 'dashboard.dart';
import 'debts.dart';
import 'inbox.dart';
import 'settings.dart';
import 'transactions.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => ShellState();
}

class ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifications.instance.openInboxRequests.addListener(_openInbox);
    _autoScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Notifications.instance.openInboxRequests.removeListener(_openInbox);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoScan();
  }

  /// Quietly look for new bank messages when the app opens or returns.
  Future<void> _autoScan() async {
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

  void _openInbox() {
    if (!mounted) return;
    final i = _indexOf('Inbox');
    if (ref.read(settingsProvider).value?.smsEnabled ?? false) _select(i);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final pending = ref.watch(pendingSmsProvider).value?.length ?? 0;
    ref.listen(
      pendingSmsProvider,
      (_, _) => refreshReminder(ref.read(repoProvider)),
    );
    final showInbox = settings?.smsEnabled ?? false;
    // Inbox tab only exists while the SMS assistant is on.
    final tabs = <_Tab>[
      _Tab(
        'Home',
        Icons.dashboard_outlined,
        Icons.dashboard,
        DashboardPage(onOpenInbox: () => _select(_indexOf('Inbox'))),
      ),
      _Tab(
        'Activity',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        const TransactionsPage(),
      ),
      _Tab(
        'Debts',
        Icons.handshake_outlined,
        Icons.handshake,
        const DebtsPage(),
      ),
      if (showInbox)
        _Tab(
          'Inbox',
          Icons.inbox_outlined,
          Icons.inbox,
          const InboxPage(),
          badge: pending,
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
        duration: const Duration(milliseconds: 180),
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
    final showInbox = ref.read(settingsProvider).value?.smsEnabled ?? false;
    final labels = [
      'Home',
      'Activity',
      'Debts',
      if (showInbox) 'Inbox',
      'Settings',
    ];
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

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/invest_repo.dart';
import '../data/repo.dart';
import '../domain/money.dart';
import '../platform/app_lock.dart';
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import '../sync/backup.dart';
import '../sync/sync_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(ref.watch(repoProvider));
  s.start();
  ref.onDispose(s.dispose);
  return s;
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsProvider);
    final repo = ref.watch(repoProvider);
    ref.watch(syncServiceProvider); // start the sync service
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
          children: [
            const _Group('Data'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      s.online
                          ? Icons.cloud_sync_outlined
                          : Icons.phonelink_lock_outlined,
                    ),
                    title: Text(s.online ? 'Online Mode' : 'Offline Mode'),
                    subtitle: Text(
                      s.online
                          ? 'Synced with your Google Drive'
                          : 'Data stays on this device',
                    ),
                    trailing: Switch.adaptive(
                      value: s.online,
                      onChanged: (v) => v
                          ? _goOnline(context, ref)
                          : _goOffline(context, ref),
                    ),
                  ),
                  if (s.online) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        s.lastSyncError != null
                            ? Icons.sync_problem
                            : Icons.check_circle_outline,
                        color: s.lastSyncError != null
                            ? context.cash.spending
                            : context.cash.income,
                      ),
                      title: Text(
                        s.lastSyncError != null
                            ? 'Last sync failed'
                            : 'Up to date',
                      ),
                      subtitle: Text(
                        s.lastSyncError ??
                            (s.lastSyncAt == null
                                ? 'Not synced yet'
                                : 'Last synced ${DateFormat('d MMM, h:mm a').format(DateTime.parse(s.lastSyncAt!).toLocal())}'),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final r = await ref
                              .read(syncServiceProvider)
                              .syncNow();
                          if (context.mounted) {
                            toast(
                              context,
                              r.ok
                                  ? 'Synced: ${r.pushedRows} sent, ${r.pulledRows} received'
                                  : 'Sync failed: ${r.error}',
                            );
                          }
                        },
                        child: const Text('Sync now'),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: const Text('Create local backup'),
                    subtitle: const Text('Checksummed file in the app folder'),
                    onTap: () async {
                      final path = await createBackup(repo);
                      if (context.mounted) {
                        toast(
                          context,
                          path == null
                              ? 'Backups are not available in the browser'
                              : 'Backup saved: ${path.split('/').last}',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const _Group('Balance rules'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Text('📈', style: TextStyle(fontSize: 22)),
                    title: const Text('Investments reduce my balance'),
                    subtitle: const Text(
                      'Money put into funds, stocks and custom investments leaves your account. Withdrawals come back.',
                    ),
                    value: s.investReducesBalance,
                    onChanged: (v) async {
                      await repo.setBalanceRule('investReducesBalance', v);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Text('🤝', style: TextStyle(fontSize: 22)),
                    title: const Text('Money I lend reduces my balance'),
                    subtitle: const Text(
                      'Turn off if lending is tracked separately. Interest you receive still counts as income.',
                    ),
                    value: s.lendReducesBalance,
                    onChanged: (v) async {
                      await repo.setBalanceRule('lendReducesBalance', v);
                    },
                  ),
                  const ListTile(
                    dense: true,
                    leading: Icon(Icons.info_outline, size: 18),
                    title: Text('Spending always reduces your balance.'),
                  ),
                ],
              ),
            ),
            const _Group('Accounts'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(
                      s.split ? 'Split accounts' : 'Combined account',
                    ),
                    subtitle: Text(
                      s.split
                          ? 'Separate cash and bank balances'
                          : 'One overall balance',
                    ),
                    trailing: Switch.adaptive(
                      value: s.split,
                      onChanged: (v) async {
                        await repo.setAccountMode(v ? 'split' : 'combined');
                        if (context.mounted) {
                          toast(
                            context,
                            'Switched. Your total balance did not change.',
                          );
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: const Text('Manage accounts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsPage()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Categories'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesPage()),
                    ),
                  ),
                ],
              ),
            ),
            const _Group('SMS assistant'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.sms_outlined),
                    title: const Text('Detect transactions in bank messages'),
                    subtitle: Text(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? 'iOS cannot read your messages. Import by paste or share; nothing is added until you confirm.'
                          : 'Import messages and approve each one. Parsed on this device only.',
                    ),
                    value: s.smsEnabled,
                    onChanged: (v) => _toggleSms(context, ref, v),
                  ),
                  if (s.smsEnabled && SmsReader.supported) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.manage_search),
                      title: const Text('Scan messages now'),
                      subtitle: const Text(
                        'Reads recent bank messages on this phone',
                      ),
                      onTap: () => scanAndReport(context, ref),
                    ),
                  ],
                  if (s.smsEnabled && s.split) ...[
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.pin_outlined),
                      title: const Text('Remember account digits'),
                      subtitle: const Text(
                        'Optional. Learns the last 4 digits of a bank account from messages you confirm, so later ones are pre-selected. You can also type them in Accounts.',
                      ),
                      value: s.smsLearnDigits,
                      onChanged: (v) =>
                          repo.setSetting('smsLearnDigits', v ? '1' : '0'),
                    ),
                  ],
                  if (s.smsEnabled) ...[
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Daily review reminder'),
                      value: s.reminderEnabled,
                      onChanged: (v) async {
                        if (v) {
                          final ok = await Notifications.instance
                              .requestPermission();
                          if (!ok) {
                            if (context.mounted) {
                              toast(
                                context,
                                Notifications.instance.lastError ?? 'Notifications are blocked. Allow them for Cash++ in system settings.',
                              );
                            }
                            return;
                          }
                          await repo.setSetting('reminderEnabled', '1');
                          await refreshReminder(repo);
                          if (Notifications.instance.lastError != null) {
                            if (context.mounted) {
                              toast(context, Notifications.instance.lastError!);
                            }
                            return;
                          }
                          if (context.mounted) {
                            toast(
                              context,
                              'Reminder set for ${s.reminderTime} every day (shown when something is waiting)',
                            );
                          }
                        } else {
                          await repo.setSetting('reminderEnabled', '0');
                          await Notifications.instance.cancelDailyReview();
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: const Text('Send a test notification'),
                      onTap: () async {
                        await Notifications.instance.requestPermission();
                        final err = await Notifications.instance.testNow();
                        if (context.mounted) {
                          toast(
                            context,
                            err == null
                                ? 'Sent. Check your notification shade.'
                                : 'Failed: $err',
                          );
                        }
                      },
                    ),
                    if (s.reminderEnabled)
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Reminder time'),
                        trailing: Text(
                          s.reminderTime,
                          style: context.text.titleMedium,
                        ),
                        onTap: () async {
                          final t = s.reminderTime.split(':');
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(t[0]),
                              minute: int.parse(t[1]),
                            ),
                          );
                          if (picked != null) {
                            final v =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            await repo.setSetting('reminderTime', v);
                            await refreshReminder(repo);
                          }
                        },
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined),
                      title: const Text('Delete stored message text'),
                      onTap: () async {
                        await repo.purgeSmsText();
                        if (context.mounted) {
                          toast(context, 'Stored message text deleted');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const _Group('Security'),
            Card(
              child: SwitchListTile.adaptive(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('App lock'),
                subtitle: const Text(
                  'Require fingerprint, face or your phone PIN to open Cash++. Also hides the app in the recent-apps view.',
                ),
                value: s.appLock,
                onChanged: (v) => _toggleLock(context, ref, v),
              ),
            ),
            const _Group('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'system',
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: 'light',
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) =>
                      repo.setSetting('themeMode', v.first),
                ),
              ),
            ),
            const _Group('Diagnostics'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Run integrity check'),
                subtitle: const Text('Verifies balances and debt postings'),
                onTap: () async {
                  final problems = await repo.checkInvariants();
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(
                        problems.isEmpty ? 'All good' : 'Problems found',
                      ),
                      content: Text(
                        problems.isEmpty
                            ? 'No inconsistencies were found.'
                            : problems.join('\n'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(BuildContext context, WidgetRef ref, bool on) async {
    final repo = ref.read(repoProvider);
    final auth = ref.read(authenticatorProvider);
    if (on && !await auth.available) {
      if (context.mounted) {
        toast(
          context,
          'Set up a screen lock (PIN, pattern or fingerprint) in your phone settings first.',
        );
      }
      return;
    }
    // Prove it is the owner both when enabling and when disabling.
    final ok = await auth.authenticate(
      on ? 'Turn on app lock' : 'Turn off app lock',
    );
    if (!ok) return;
    await repo.setSetting('appLock', on ? '1' : '0');
    await SmsReader.instance.setSecure(on);
  }

  Future<void> _toggleSms(BuildContext context, WidgetRef ref, bool on) async {
    final repo = ref.read(repoProvider);
    if (!on) {
      await repo.setSetting('smsEnabled', '0');
      await SmsReader.instance.setAutoDetect(false);
      await refreshReminder(repo);
      return;
    }
    if (SmsReader.supported) {
      // Show the system permission dialog; only enable when it is granted.
      final granted = await SmsReader.instance.requestPermission();
      if (!granted) {
        if (context.mounted) {
          toast(
            context,
            'SMS permission was denied. Allow "SMS" for Cash++ in Android Settings > Apps to enable this.',
          );
        }
        return;
      }
      await repo.setSetting('smsEnabled', '1');
      await SmsReader.instance.setAutoDetect(true);
      if (context.mounted) await scanAndReport(context, ref);
    } else {
      await repo.setSetting('smsEnabled', '1');
    }
  }

  Future<void> _goOnline(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Turn on Online Mode?'),
        content: const Text(
          'You will sign in with Google. A local backup is made first. Your data is then merged with any Cash++ data already in your private Drive app folder — nothing is overwritten or deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ref.read(syncServiceProvider).goOnline();
    if (context.mounted) {
      toast(
        context,
        r.ok
            ? 'Online Mode on. ${r.pushedRows} sent, ${r.pulledRows} received.'
            : 'Could not enable: ${r.error}',
      );
    }
  }

  Future<void> _goOffline(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Switch to Offline Mode?'),
        content: const Text(
          'Syncing stops and you are signed out of Google. All data stays on this device. Data already in Drive is kept (remove it from your Google account settings if you want it gone).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Push any pending changes first so nothing is stranded locally.
    await ref.read(syncServiceProvider).syncNow();
    await ref.read(syncServiceProvider).goOffline();
  }
}

class _Group extends StatelessWidget {
  final String text;
  const _Group(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x6, Sp.x1, Sp.x2),
    child: Text(
      text.toUpperCase(),
      style: context.text.labelMedium?.copyWith(
        color: context.cash.textMuted,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? [];
    final bal = ref.watch(balancesProvider).value ?? {};
    final split = ref.watch(settingsProvider).value?.split ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: split
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add bank account'),
              onPressed: () => _edit(context, ref, null),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(Sp.x4),
        children: [
          if (!split)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Text(
                'In Combined mode all balances are shown as one total. Switch to Split accounts in Settings to manage cash and banks separately.',
                style: context.text.bodySmall?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
            ),
          Card(
            child: Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorOf(a.colorValue)
                          .withValues(alpha: 0.18),
                      child: Icon(
                        a.kind == 'cash'
                            ? Icons.payments_outlined
                            : Icons.account_balance,
                        color: colorOf(a.colorValue),
                      ),
                    ),
                    title: Text(a.name),
                    subtitle: Text(
                      [
                        'Opening ${Money.format(a.openingMinor)}',
                        if (a.last4 != null) '•• ${a.last4}',
                      ].join(' · '),
                    ),
                    trailing: TrailingMoney(
                      bal[a.id] ?? 0,
                      style: context.text.titleSmall,
                    ),
                    onTap: () => _edit(context, ref, a),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, Account? a) {
    final name = TextEditingController(text: a?.name ?? '');
    final opening = TextEditingController(
      text: a == null ? '' : (a.openingMinor / 100).toStringAsFixed(2),
    );
    final last4 = TextEditingController(text: a?.last4 ?? '');
    showSheet(
      context,
      (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: Sp.x3),
              AmountField(controller: opening, label: 'Opening balance'),
              if (a == null || a.kind == 'bank') ...[
                const SizedBox(height: Sp.x3),
                TextField(
                  controller: last4,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Last 4 digits of account or card (optional)',
                    helperText: 'Only used to pre-select this account for bank messages',
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: Sp.x4),
              FilledButton(
                onPressed: () async {
                  final repo = ref.read(repoProvider);
                  final o =
                      Money.parse(opening.text.isEmpty ? '0' : opening.text) ??
                      0;
                  try {
                    if (a == null) {
                      await repo.addAccount(
                        name.text,
                        openingMinor: o,
                        last4: last4.text.trim().isEmpty
                            ? null
                            : last4.text.trim(),
                      );
                    } else {
                      await repo.updateAccount(
                        a.id,
                        name: name.text.trim().isEmpty
                            ? a.name
                            : name.text.trim(),
                        openingMinor: o,
                        last4: last4.text.trim().isEmpty
                            ? null
                            : last4.text.trim(),
                        clearLast4:
                            a.kind == 'bank' && last4.text.trim().isEmpty,
                      );
                    }
                    if (c.mounted) Navigator.pop(c);
                  } on ValidationException catch (e) {
                    if (c.mounted) toast(c, e.message);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});
  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  static const _swatches = [
    0xFF2F6BFF,
    0xFF1FA971,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF84CC16,
    0xFFF97316,
    0xFF14B8A6,
    0xFF6366F1,
    0xFF64748B,
  ];

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? [];
    Widget list(String kind) {
      final mains = cats
          .where((c) => c.kind == kind && c.parentId == null)
          .toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 96),
        children: [
          for (final m in mains)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: colorOf(m.colorValue),
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: kind == 'debit'
                          ? IconButton(
                              tooltip: 'Add subcategory',
                              icon: const Icon(Icons.add),
                              onPressed: () => _edit(null, kind, parent: m),
                            )
                          : null,
                      onTap: () => _edit(m, kind),
                    ),
                    for (final s in cats.where((c) => c.parentId == m.id))
                      ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: Sp.x8 + Sp.x4,
                          right: Sp.x4,
                        ),
                        dense: true,
                        title: Text(s.name),
                        onTap: () => _edit(s, kind),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Spending'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Category'),
        onPressed: () => _edit(null, _tabs.index == 0 ? 'debit' : 'credit'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [list('debit'), list('credit')],
      ),
    );
  }

  void _edit(Category? c, String kind, {Category? parent}) {
    final name = TextEditingController(text: c?.name ?? '');
    var color = c?.colorValue ?? parent?.colorValue ?? _swatches.first;
    showSheet(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c == null
                      ? (parent == null
                            ? 'New category'
                            : 'New subcategory of ${parent.name}')
                      : 'Edit category',
                  style: ctx.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Sp.x4),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: Sp.x4),
                Wrap(
                  spacing: Sp.x3,
                  runSpacing: Sp.x3,
                  children: [
                    for (final s in _swatches)
                      Semantics(
                        button: true,
                        selected: color == s,
                        label: 'Colour',
                        child: GestureDetector(
                          onTap: () => set(() => color = s),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(s),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == s
                                    ? ctx.scheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.x5),
                Row(
                  children: [
                    if (c != null)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: ctx.cash.spending,
                          ),
                          onPressed: () => _delete(ctx, c),
                          child: const Text('Delete'),
                        ),
                      ),
                    if (c != null) const SizedBox(width: Sp.x3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final repo = ref.read(repoProvider);
                          try {
                            if (c == null) {
                              await repo.addCategory(
                                name.text,
                                kind,
                                parentId: parent?.id,
                                color: color,
                              );
                            } else {
                              await repo.updateCategory(
                                c.id,
                                name: name.text.trim().isEmpty
                                    ? c.name
                                    : name.text.trim(),
                                color: color,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } on ValidationException catch (e) {
                            if (ctx.mounted) toast(ctx, e.message);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext ctx, Category c) async {
    final repo = ref.read(repoProvider);
    try {
      await repo.deleteCategory(c.id);
      if (ctx.mounted) Navigator.pop(ctx);
    } on ValidationException {
      // Has history: ask for a replacement.
      final others = (await repo.categories(kind: c.kind))
          .where((o) => o.id != c.id && o.parentId != c.id)
          .toList();
      if (!ctx.mounted) return;
      final target = await showDialog<String>(
        context: ctx,
        builder: (d) => SimpleDialog(
          title: const Text('Move its transactions to…'),
          children: [
            for (final o in others)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(d, o.id),
                child: Text(o.name),
              ),
          ],
        ),
      );
      if (target != null) {
        await repo.deleteCategory(c.id, reassignTo: target);
        if (ctx.mounted) Navigator.pop(ctx);
      }
    }
  }
}

/// Scans the inbox and tells the user what happened.
Future<void> scanAndReport(BuildContext context, WidgetRef ref) async {
  final r = await scanSmsInbox(ref.read(repoProvider));
  if (!context.mounted) return;
  toast(
    context,
    r.ok
        ? (r.added > 0
              ? '${r.added} transaction${r.added == 1 ? '' : 's'} found. Review them in the Inbox tab.'
              : 'Scanned ${r.scanned} messages, nothing new to review.')
        : 'Scan failed: ${r.error}',
  );
}

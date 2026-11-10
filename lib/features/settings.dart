import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../data/db.dart';
import '../data/repo.dart';
import '../domain/money.dart';
import '../platform/app_lock.dart';
import '../platform/diag.dart';
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import '../sync/backup.dart';
import '../domain/currency.dart';
import 'inbox.dart' show ImportSheet;
import 'tone.dart';
import 'locale_pickers.dart';
import 'passphrase.dart';
import '../sync/drive_remote.dart';
import '../sync/sync_service.dart';
import '../ui/emoji.dart';
import '../ui/loaders.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'grade_ui.dart';
import 'settings_tour.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsProvider);
    final repo = ref.watch(repoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8),
          children: [
            const SizedBox(height: Sp.x2),
            Card(
              child: ListTile(
                leading: const Text('🧭', style: TextStyle(fontSize: 26)),
                title: Text(tr('Take a tour of Settings')),
                subtitle: const Text('A 1-minute guide in simple words'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showSettingsTour(context),
              ),
            ),
            const _Group('Backup'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      s.online
                          ? Icons.cloud_sync_outlined
                          : Icons.phonelink_lock_outlined,
                    ),
                    title: Text(
                      s.online
                          ? 'Back up to Google Drive'
                          : 'Keep on this phone only',
                    ),
                    subtitle: Text(
                      s.online
                          ? 'Your data is also saved, encrypted, in your Google Drive'
                          : 'Your data stays on this phone',
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
                      subtitle: ValueListenableBuilder<SyncProgress>(
                        valueListenable: ref.read(syncServiceProvider).progress,
                        builder: (context, p, _) => p.active
                            ? SyncProgressLine(p: p)
                            : Text(
                                s.lastSyncError ??
                                    (s.lastSyncAt == null
                                        ? 'Not synced yet'
                                        : 'Last synced ${DateFormat('d MMM, h:mm a').format(DateTime.parse(s.lastSyncAt!).toLocal())}'),
                              ),
                      ),
                      trailing: ValueListenableBuilder<SyncProgress>(
                        valueListenable: ref.read(syncServiceProvider).progress,
                        builder: (context, p, _) => p.active
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : TextButton(
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
                                child: Text(tr('Sync now')),
                              ),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: Text(tr('Back up now')),
                    subtitle: const Text(
                      'Saves a protected copy on this phone',
                    ),
                    onTap: () async {
                      final vault = ref.read(syncServiceProvider).vault;
                      if (!await ensurePassphrase(context, vault)) return;
                      final path = await createBackup(repo, vault: vault);
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
            const _Group('Accounts'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(s.split ? 'Separate balances' : 'One balance'),
                    subtitle: Text(
                      s.split
                          ? 'Cash and each bank account kept apart.'
                          : 'Cash and bank together in one total.',
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
                    title: Text(tr('Manage accounts')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context)
                            .push(softRoute(const AccountsPage())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(tr('Categories')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context)
                            .push(softRoute(const CategoriesPage())),
                  ),
                ],
              ),
            ),
            const _Group('Automatic entries'),
            Card(
              child: Column(
                children: [
                  if (s.smsAllowed) ...[
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.sms_outlined),
                      title: Text(tr('Add entries from bank messages')),
                      subtitle: const Text(
                        'Cash++ turns your bank alerts into entries you confirm.',
                      ),
                      value: s.smsEnabled,
                      onChanged: (v) => _toggleSms(context, ref, v),
                    ),
                    if (s.smsEnabled)
                      FutureBuilder<bool>(
                        future: SmsReader.instance.hasPermission(),
                        builder: (context, snap) => snap.data == false
                            ? ListTile(
                                leading: const Icon(
                                  Icons.notifications_off_outlined,
                                ),
                                title: const Text(
                                  'Turn on notification access',
                                ),
                                subtitle: const Text(
                                  'Cash++ needs it to see your bank alerts. Tap, then switch on Cash++ in the list.',
                                ),
                                onTap: () async {
                                  AppLockGate.holdOff();
                                  await SmsReader.instance.requestPermission();
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    leading: const Icon(Icons.content_paste),
                    title: const Text('Add from a copied message'),
                    subtitle: const Text(
                      'Paste or share a bank message and Cash++ fills in the entry. Nothing is added until you confirm.',
                    ),
                    onTap: () => showSheet(context, (_) => const ImportSheet()),
                  ),
                  if (s.smsEnabled && s.split) ...[
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.pin_outlined),
                      title: Text(tr('Recognise my bank accounts')),
                      subtitle: const Text(
                        'Optional. Learns the last 4 digits of a bank account from entries you confirm, so later ones are pre-selected. You can also type them in Accounts.',
                      ),
                      value: s.smsLearnDigits,
                      onChanged: (v) =>
                          repo.setSetting('smsLearnDigits', v ? '1' : '0'),
                    ),
                  ],
                ],
              ),
            ),
            const _Group('Notifications'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(tr('Daily reminder')),
                    subtitle: const Text(
                      'Every day, even if nothing is waiting',
                    ),
                    value: s.reminderEnabled,
                    onChanged: (v) async {
                      if (v) {
                        AppLockGate.holdOff();
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
                            'Reminder set for ${s.reminderTime} every day ',
                          );
                        }
                      } else {
                        await repo.setSetting('reminderEnabled', '0');
                        await Notifications.instance.cancelDailyReview();
                      }
                    },
                  ),
                  if (s.reminderEnabled)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(tr('Reminder time')),
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
                    leading: const Icon(Icons.notifications_none),
                    title: Text(tr('Send a test notification')),
                    subtitle: const Text(
                      'Checks that Cash++ can alert you on this phone',
                    ),
                    onTap: () async {
                      // the permission dialog is ours: don't lock the app after it
                      AppLockGate.holdOff();
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
                ],
              ),
            ),
            const _Group('Security'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: Text(tr('Hide Cash++ when switching apps')),
                    subtitle: const Text(
                      'Blanks Cash++ in the recent-apps view and blocks screenshots.',
                    ),
                    value: s.hidePreview,
                    onChanged: (v) async {
                      await ref
                          .read(repoProvider)
                          .setSetting('hidePreview', v ? '1' : '0');
                      await SmsReader.instance.setSecure(v || s.appLock);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.lock_outline),
                    title: Text(tr('App lock')),
                    subtitle: const Text(
                      'Require fingerprint, face or your phone PIN to open Cash++.',
                    ),
                    value: s.appLock,
                    onChanged: (v) => _toggleLock(context, ref, v),
                  ),
                  if (s.appLock) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(Sp.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ask again after being away for',
                            style: context.text.labelLarge,
                          ),
                          const SizedBox(height: Sp.x2),
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: 0,
                                label: Text(tr('Always')),
                              ),
                              ButtonSegment(value: 60, label: Text('1 min')),
                              ButtonSegment(value: 300, label: Text('5 min')),
                              ButtonSegment(value: 900, label: Text('15 min')),
                            ],
                            selected: {s.lockAfterSeconds},
                            onSelectionChanged: (v) => repo.setSetting(
                              'lockAfterSeconds',
                              '${v.first}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const _Group('Month-end title'),
            Card(
              child: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final funny = ref.watch(roastModeProvider).value ?? false;
                      return ListTile(
                        leading: const Text(
                          '💬',
                          style: TextStyle(fontSize: 22),
                        ),
                        title: Text(tr('How we talk to you')),
                        subtitle: Text(funny ? 'Honest and funny' : 'Friendly'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showToneSheet(context),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('🏆', style: TextStyle(fontSize: 22)),
                    title: Text(tr('Your titles')),
                    subtitle: const Text(
                      'The title you earned each month, from your first month to now.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context)
                            .push(softRoute(const TrophyShelfPage())),
                  ),
                ],
              ),
            ),
            const _Group('Language and currency'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(tr('Language')),
                    subtitle: Text(
                      appLanguages
                          .firstWhere((l) => l.code == s.language)
                          .native,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final c = await pickLanguageCode(context, s.language);
                      if (c != null) await repo.setSetting('language', c);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(tr('Currency')),
                    subtitle: Text(currencyByCode(s.currency).label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changeCurrency(context, ref, s.currency),
                  ),
                ],
              ),
            ),
            const _Group('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(tr('System')),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: 'light',
                      label: Text(tr('Light')),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text(tr('Dark')),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) =>
                      repo.setSetting('themeMode', v.first),
                ),
              ),
            ),
            const _Group('Help'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(tr('Help and troubleshooting')),
                    subtitle: const Text(
                      'Shows what the app has been doing. Copy it and send it to us if something looks wrong.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context)
                            .push(softRoute(const EventLogPage())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: Text(tr('Check my data')),
                    subtitle: Text(tr('Makes sure your balances add up')),
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
                              child: Text(tr('OK')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeCurrency(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final code = await pickCurrencyCode(context);
    if (code == null || code == current || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('Currency')}: $code'),
        content: const Text(
          'This changes how amounts are shown. Your existing amounts are not converted: 1,000 stays 1,000 in the new currency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Continue')),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(repoProvider).setSetting('currency', code);
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
    final hide = await repo.getSetting('hidePreview') != '0';
    await SmsReader.instance.setSecure(on || hide);
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
      // Android has no pop-up for notification access: it opens its own list.
      AppLockGate.holdOff();
      final granted = await SmsReader.instance.requestPermission();
      await repo.setSetting('smsEnabled', '1');
      await SmsReader.instance.setAutoDetect(true);
      if (!context.mounted) return;
      if (granted) {
        await scanAndReport(context, ref);
      } else {
        toast(
          context,
          'Switch on Cash++ in the notification access list, then come back.',
        );
      }
    } else {
      await repo.setSetting('smsEnabled', '1');
    }
  }

  Future<void> _goOnline(BuildContext context, WidgetRef ref) async {
    if (!DriveRemote.configured) {
      // Say so up front instead of failing silently.
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Google Drive backup is not available yet'),
          content: const Text(DriveRemote.notConfiguredMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr('OK')),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Back up to Google Drive?'),
        content: const Text(
          'You will sign in with Google. A local backup is made first. Your data is then merged with any Cash++ data already in your private Drive app folder — nothing is overwritten or deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Continue')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final vault = ref.read(syncServiceProvider).vault;
    if (!await ensurePassphrase(context, vault)) return;
    AppLockGate.holdOff(const Duration(minutes: 2));
    final r = await ref.read(syncServiceProvider).goOnline();
    if (context.mounted) {
      toast(
        context,
        r.ok
            ? 'Google Drive backup is on. ${r.pushedRows} sent, ${r.pulledRows} received.'
            : 'Could not enable: ${r.error}',
      );
    }
  }

  Future<void> _goOffline(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keep your data on this phone only?'),
        content: const Text(
          'Backing up stops and you are signed out of Google. All your data stays on this phone. What is already in Google Drive stays there; you can remove it from your Google account settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Keep on this phone')),
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
      appBar: AppBar(title: Text(tr('Accounts'))),
      floatingActionButton: split
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(tr('Add bank account')),
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
                'Your cash and bank are shown together as one total. To keep them apart, choose "Separate balances" in Settings.',
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
      text: a == null ? '' : Money.edit(a.openingMinor),
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
                decoration: InputDecoration(labelText: tr('Name')),
              ),
              const SizedBox(height: Sp.x3),
              AmountField(controller: opening, label: tr('Opening balance')),
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
                child: Text(tr('Save')),
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
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorOf(m.colorValue).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          emojiForCategory(m.name),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: kind == 'debit'
                          ? IconButton(
                              tooltip: tr('Add subcategory'),
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
                        leading: Text(
                          emojiForCategory(s.name, m.name),
                          style: const TextStyle(fontSize: 20),
                        ),
                        horizontalTitleGap: Sp.x2,
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
        title: Text(tr('Categories')),
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
        label: Text(tr('Category')),
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
                  decoration: InputDecoration(labelText: tr('Name')),
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
                        label: tr('Colour'),
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
                          child: Text(tr('Delete')),
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
                        child: Text(tr('Save')),
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

/// Checks for new bank alerts and tells the user what happened.
Future<void> scanAndReport(BuildContext context, WidgetRef ref) async {
  final r = await scanSmsInbox(ref.read(repoProvider));
  if (!context.mounted) return;
  if (r.busy) {
    toast(context, 'Already checking your messages. One moment.');
    return;
  }
  toast(
    context,
    r.ok
        ? (r.added > 0
              ? '${r.added} transaction${r.added == 1 ? '' : 's'} found. Review them in the Inbox tab.'
              : 'Checked your bank alerts, nothing new to review.')
        : 'Could not check your bank alerts: ${r.error}',
  );
}

/// The last ~200 things the app did, for diagnosing a problem on a real phone.
class EventLogPage extends StatelessWidget {
  const EventLogPage({super.key});
  @override
  Widget build(BuildContext context) {
    final diag = Diag.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Help and troubleshooting')),
        actions: [
          IconButton(
            tooltip: tr('Copy'),
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diag.dump()));
              if (context.mounted) toast(context, 'Copied. Paste it to share.');
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: diag.changed,
        builder: (context, _, _) {
          final lines = diag.lines.reversed.toList();
          if (lines.isEmpty) {
            return const EmptyState(
              icon: Icons.bug_report_outlined,
              title: 'Nothing logged yet',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(Sp.x3),
            itemCount: lines.length,
            itemBuilder: (_, i) => Text(
              lines[i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}

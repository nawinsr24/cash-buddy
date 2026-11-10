import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/money.dart';
import '../domain/currency.dart';
import '../l10n/l10n.dart';
import '../platform/app_lock.dart';
import '../platform/features.dart';
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import 'budget_editor.dart';
import 'locale_pickers.dart';
import 'passphrase.dart';
import 'tone.dart';
import '../data/repo.dart' show TxnFilter;
import '../ui/art.dart';
import '../ui/loaders.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// First-run wizard. Nothing is pre-selected silently: every choice must be
/// made explicitly, and every choice can be changed later in Settings.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _page = PageController();

  @override
  void initState() {
    super.initState();
    // Pre-select the phone's language and region currency (changeable).
    final dl = WidgetsBinding.instance.platformDispatcher.locale;
    L10n.use(dl.languageCode);
    final code = NumberFormat.simpleCurrency(locale: dl.toString())
        .currencyName;
    Money.configure(
      code: allCurrencies.any((c) => c.code == code) ? code! : 'INR',
    );
    _lang = L10n.lang;
    _cur = Money.code;
  }

  int _step = 0;
  String? _dataMode;
  String? _accountMode;
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  bool _saving = false;
  bool _signingIn = false;
  bool _restoring = false;
  String? _welcome;
  String? _signedInAs; // Google account chosen during setup (Online Mode)
  static const _steps = 9;
  // steps: 0 language + currency, 1 data, 2 accounts, 3 bank alerts,
  // 4 balance, 5 reminder, 6 budget, 7 look, 8 privacy
  String _lang = 'en';
  String _cur = 'INR';
  bool _smsOn = false;
  bool _remind = false;
  TimeOfDay _remindAt = const TimeOfDay(hour: 20, minute: 0);
  final _income = TextEditingController();
  bool _funny = false;
  String _theme = 'system';
  bool _lock = false;

  bool get _canNext => switch (_step) {
    1 => _dataMode != null,
    2 => _accountMode != null,
    _ => true,
  };

  /// Steps after the account choice can all be skipped.
  bool get _skippable => _step >= 3;

  /// The budget step has its own Save / Skip buttons.
  bool get _ownButtons => _step == 6;

  /// Choosing Online Mode asks for the Google sign-in right here, so the user
  /// is never left "online" without an account.
  Future<void> _continueFromDataMode() async {
    if (_dataMode != 'online') {
      _go(2);
      return;
    }
    if (_signedInAs != null) {
      _go(2);
      return;
    }
    final sync = ref.read(syncServiceProvider);
    if (!await ensurePassphrase(context, sync.vault)) {
      if (mounted) setState(() => _dataMode = 'offline');
      return;
    }
    if (!mounted) return;
    setState(() => _signingIn = true);
    final r = await sync.signInForSetup();
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (!r.ok) {
      final useOffline = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(tr('Could not sign in')),
          content: Text(r.error ?? 'Google sign-in did not complete.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Keep on this phone')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Try again')),
            ),
          ],
        ),
      );
      if (useOffline == true && mounted) setState(() => _dataMode = 'offline');
      return;
    }
    setState(() => _signedInAs = r.email ?? 'your Google account');
    if (r.hasData) {
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Found your Cash++ data'),
          content: Text(
            'There is already Cash++ data in the Google Drive of ${r.email ?? 'this account'}. Restore it on this phone?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Start fresh')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Restore')),
            ),
          ],
        ),
      );
      if (restore == true) {
        if (!mounted) return;
        setState(() => _restoring = true);
        final res = await sync.restoreFromDrive();
        if (!mounted) return;
        if (!res.ok && (res.error ?? '').contains('password')) {
          await sync.vault.clear(); // ask again next time
          if (!mounted) return;
        }
        if (res.ok) {
          final repo = ref.read(repoProvider);
          final accounts = (await repo.accounts()).length;
          final txns = (await repo.searchTransactions(
            const TxnFilter(),
            limit: 100000,
          )).length;
          if (!mounted) return;
          setState(
            () => _welcome =
                '$accounts account${accounts == 1 ? '' : 's'} and $txns transaction${txns == 1 ? '' : 's'} are back.',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1700));
          if (!mounted) return;
          ref.invalidate(settingsProvider); // opens the app, already set up
          return;
        }
        setState(() => _restoring = false);
        toast(context, 'Could not restore: ${res.error}');
        return;
      }
    }
    if (mounted) _go(2);
  }

  void _go(int s) {
    setState(() => _step = s);
    _page.animateToPage(
      s,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final cash = Money.parse(_cash.text.isEmpty ? '0' : _cash.text) ?? 0;
    final bank = Money.parse(_bank.text.isEmpty ? '0' : _bank.text) ?? 0;
    try {
      await ref
          .read(repoProvider)
          .completeOnboarding(
            dataMode: _dataMode!,
            accountMode: _accountMode!,
            openingCashMinor: cash,
            openingBankMinor: bank,
          );
      final repo = ref.read(repoProvider);
      final inc = Money.parse(_income.text.trim().isEmpty ? '0' : _income.text);
      if (inc != null && inc > 0) {
        await repo.setSetting('expectedIncome', '$inc');
      }
      await repo.setSetting('language', _lang);
      await repo.setSetting('currency', _cur);
      await repo.setSetting('roastMode', _funny ? '1' : '0');
      await repo.setSetting('themeMode', _theme);
      if (_lock) {
        await repo.setSetting('appLock', '1');
      }
      if (_remind) {
        await repo.setSetting('reminderEnabled', '1');
        await repo.setSetting(
          'reminderTime',
          '${_remindAt.hour.toString().padLeft(2, '0')}:${_remindAt.minute.toString().padLeft(2, '0')}',
        );
        await refreshReminder(repo);
      }
      if (_dataMode == 'offline' && _signedInAs != null) {
        // changed their mind after signing in: sign out again
        await ref.read(syncServiceProvider).goOffline();
      }
      if (_dataMode == 'online' && _signedInAs != null) {
        // merge with Drive in the background; the app is usable right away
        unawaited(ref.read(syncServiceProvider).finishSetupOnline());
      }
      ref.invalidate(settingsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Could not finish setup: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return RestoreScreen(
        progress: ref.read(syncServiceProvider).progress,
        welcome: _welcome,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x4, Sp.x6, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? context.scheme.primary
                              : context.scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _languagePage(),
                  _choicePage(
                    art: Art.welcome,
                    title: 'Where should your data live?',
                    body: 'You can change this later in Settings.',
                    options: [
                      _Opt(
                        'offline',
                        Icons.phonelink_lock_outlined,
                        'Keep on this phone only',
                        'Your data stays on this phone. No sign-in needed.',
                      ),
                      _Opt(
                        'online',
                        Icons.cloud_sync_outlined,
                        'Back up to Google Drive',
                        'Your data stays on this phone and is also saved, encrypted, in your own Google Drive.',
                      ),
                    ],
                    value: _dataMode,
                    onChanged: (v) => setState(() => _dataMode = v),
                  ),
                  _choicePage(
                    art: Art.piggy,
                    title: 'How do you track your money?',
                    body: 'Switch any time without losing history.',
                    options: [
                      _Opt(
                        'combined',
                        Icons.account_balance_wallet_outlined,
                        'One balance',
                        'Cash and bank together in one total.',
                      ),
                      _Opt(
                        'split',
                        Icons.call_split,
                        'Separate balances',
                        'Cash and each bank account kept apart.',
                      ),
                    ],
                    value: _accountMode,
                    onChanged: (v) => setState(() => _accountMode = v),
                  ),
                  _alertsPage(),
                  _openingPage(),
                  _reminderPage(),
                  BudgetEditor(onSaved: () => _go(7), onSkip: () => _go(7)),
                  _lookPage(),
                  _privacyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Sp.x6),
              child: Row(
                children: [
                  if (_step > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.x3),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(56, 52),
                        ),
                        onPressed: _saving ? null : () => _go(_step - 1),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                  if (_ownButtons)
                    const Spacer()
                  else ...[
                    if (_skippable && _step < _steps - 1)
                      Padding(
                        padding: const EdgeInsets.only(right: Sp.x3),
                        child: TextButton(
                          onPressed: _saving ? null : () => _go(_step + 1),
                          child: Text(tr('Skip')),
                        ),
                      ),
                    Expanded(
                      child: FilledButton(
                        onPressed: !_canNext || _saving || _signingIn
                            ? null
                            : (_step == _steps - 1
                                  ? _finish
                                  : (_step == 1
                                        ? _continueFromDataMode
                                        : () => _go(_step + 1))),
                        child: _signingIn
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _step == _steps - 1
                                    ? 'Start using Cash++'
                                    : (_step == 1 && _dataMode == 'online'
                                          ? 'Continue with Google'
                                          : 'Continue'),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, String body, {Art? art}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (art != null) Center(child: Illustration(art, height: 190)),
      const SizedBox(height: Sp.x6),
      Text(
        title,
        style: context.text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: Sp.x2),
      Text(
        body,
        style: context.text.bodyLarge?.copyWith(color: context.cash.textMuted),
      ),
      const SizedBox(height: Sp.x6),
    ],
  );

  Widget _choicePage({
    required String title,
    required String body,
    required List<_Opt> options,
    required String? value,
    required ValueChanged<String> onChanged,
    Art? art,
  }) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(title, body, art: art),
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.x3),
          child: Semantics(
            selected: value == o.key,
            button: true,
            label: '${o.title}. ${o.subtitle}',
            child: InkWell(
              borderRadius: BorderRadius.circular(Sp.rCard),
              onTap: () {
                haptic();
                onChanged(o.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(Sp.x5),
                decoration: BoxDecoration(
                  color: context.cash.surfaceRaised,
                  borderRadius: BorderRadius.circular(Sp.rCard),
                  border: Border.all(
                    color: value == o.key
                        ? context.scheme.primary
                        : context.scheme.outlineVariant,
                    width: value == o.key ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(o.icon, size: 32, color: context.scheme.primary),
                    const SizedBox(width: Sp.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.title,
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Sp.x1),
                          Text(
                            o.subtitle,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.cash.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (value == o.key)
                      Icon(Icons.check_circle, color: context.scheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _openingPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        'Opening balance',
        _accountMode == 'split'
            ? 'How much do you have in cash and in the bank today? Skip if you are unsure — you can edit it later.'
            : 'How much money do you have in total today? Skip if you are unsure.',
      ),
      AmountField(
        controller: _cash,
        label: _accountMode == 'split' ? 'Cash in hand' : 'Current balance',
      ),
      if (_accountMode == 'split') ...[
        const SizedBox(height: Sp.x4),
        AmountField(controller: _bank, label: tr('Bank balance')),
      ],
      const SizedBox(height: Sp.x4),
      AmountField(controller: _income, label: tr('Monthly income (optional)')),
    ],
  );

  Future<void> _pickLanguage() async {
    final code = await pickLanguageCode(context, _lang);
    if (code == null || !mounted) return;
    L10n.use(code);
    await ref.read(repoProvider).setSetting('language', code);
    if (mounted) setState(() => _lang = code);
  }

  Future<void> _pickCurrency() async {
    final code = await pickCurrencyCode(context);
    if (code == null || !mounted) return;
    Money.configure(code: code);
    await ref.read(repoProvider).setSetting('currency', code);
    if (mounted) setState(() => _cur = code);
  }

  Widget _languagePage() {
    final lang = appLanguages.firstWhere((l) => l.code == _lang);
    final cur = currencyByCode(_cur);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
      children: [
        _header(
          tr('Language and currency'),
          tr('You can change this later in Settings.'),
          art: Art.welcome,
        ),
        _pickTile(Icons.translate, tr('Language'), lang.native, _pickLanguage),
        const SizedBox(height: Sp.x3),
        _pickTile(
          Icons.payments_outlined,
          tr('Currency'),
          '${cur.symbol}  ${cur.label}',
          _pickCurrency,
        ),
      ],
    );
  }

  Widget _pickTile(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) => InkWell(
    borderRadius: BorderRadius.circular(Sp.rCard),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: context.cash.surfaceRaised,
        borderRadius: BorderRadius.circular(Sp.rCard),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.scheme.primary),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.labelMedium?.copyWith(
                    color: context.cash.textMuted,
                  ),
                ),
                Text(value, style: context.text.titleMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );

  Widget _alertsPage() {
    final can = Features.smsReading(
      remoteFlag: ref.read(settingsProvider).value?.smsAllowed ?? true,
    );
    return _alertsList(can);
  }

  Widget _alertsList(bool can) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        can
            ? 'Add bank messages automatically'
            : 'Add bank messages in seconds',
        can
            ? 'Cash++ sees your bank alerts in your notifications, never your message inbox, and turns them into entries for you to confirm. Everything stays on your phone.'
            : 'Paste or share a bank message into Cash++ and it fills in the entry for you.',
        art: Art.welcome,
      ),
      if (can)
        _smsOn
            ? ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: context.cash.income),
                title: const Text(
                  'Almost there: switch on Cash++ in the list that opened',
                ),
              )
            : FilledButton.tonalIcon(
                icon: const Icon(Icons.sms_outlined),
                label: Text(tr('Turn on notification access')),
                onPressed: () async {
                  AppLockGate.holdOff();
                  await SmsReader.instance.requestPermission();
                  if (!mounted) return;
                  final repo = ref.read(repoProvider);
                  await repo.setSetting('smsEnabled', '1');
                  await SmsReader.instance.setAutoDetect(true);
                  setState(() => _smsOn = true);
                },
              ),
    ],
  );

  Widget _reminderPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        'Daily reminder',
        'A quiet nudge each day to note your spending. People who check daily keep their budget.',
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(tr('Remind me every day')),
        value: _remind,
        onChanged: (v) async {
          if (v) {
            AppLockGate.holdOff();
            final ok = await Notifications.instance.requestPermission();
            if (!ok) {
              if (mounted) {
                toast(
                  context,
                  'Notifications are blocked. You can allow them later in Settings.',
                );
              }
              return;
            }
          }
          if (mounted) setState(() => _remind = v);
        },
      ),
      if (_remind)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(tr('Time')),
          trailing: Text(
            _remindAt.format(context),
            style: context.text.titleMedium,
          ),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: _remindAt,
            );
            if (t != null && mounted) setState(() => _remindAt = t);
          },
        ),
    ],
  );

  Widget _lookPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        'How should we talk to you?',
        'You can change this, and the theme, later in Settings.',
      ),
      ToneChooser(funny: _funny, onChanged: (v) => setState(() => _funny = v)),
      const SizedBox(height: Sp.x6),
      Text(tr('Theme'), style: context.text.titleSmall),
      const SizedBox(height: Sp.x2),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'system', label: Text(tr('System'))),
          ButtonSegment(value: 'light', label: Text(tr('Light'))),
          ButtonSegment(value: 'dark', label: Text(tr('Dark'))),
        ],
        selected: {_theme},
        onSelectionChanged: (v) async {
          setState(() => _theme = v.first);
          await ref.read(repoProvider).setSetting('themeMode', _theme);
        },
      ),
    ],
  );

  Widget _privacyPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        'Keep it private',
        'Lock Cash++ with your fingerprint, face or phone PIN. Your data is also stored encrypted on this phone.',
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(tr('Lock the app')),
        value: _lock,
        onChanged: (v) async {
          if (v) {
            final auth = ref.read(authenticatorProvider);
            if (!await auth.available) {
              if (mounted) {
                toast(
                  context,
                  'Set up a screen lock in your phone settings first.',
                );
              }
              return;
            }
            AppLockGate.holdOff();
            if (!await auth.authenticate('Turn on app lock')) return;
          }
          if (mounted) setState(() => _lock = v);
        },
      ),
    ],
  );
}

class _Opt {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  _Opt(this.key, this.icon, this.title, this.subtitle);
}

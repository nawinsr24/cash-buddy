import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../domain/currency.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import 'locale_pickers.dart';
import 'account_tile.dart';
import 'legal.dart';
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
    // Pre-select the phone's language. The currency starts as the Indian
    // rupee; both can be changed on this screen and later in Settings.
    final dl = WidgetsBinding.instance.platformDispatcher.locale;
    L10n.use(dl.languageCode);
    Money.configure();
    _lang = L10n.lang;
    _cur = Money.code;
  }

  int _step = 0;
  String? _dataMode;
  String? _accountMode = 'combined';
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  bool _saving = false;
  bool _signingIn = false;
  bool _restoring = false;
  String? _welcome;
  String? _signedInAs; // Google account chosen during setup (Online Mode)
  static const _steps = 3;
  // steps: 0 start (language, currency, Google or offline), 1 your details
  // (offline only), 2 your money. Budget, bank messages, family and the
  // reminder are offered on Home afterwards ("Finish setting up").
  String _lang = 'en';
  String _cur = 'INR';
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  var _ticked = false;

  /// Only builds that talk to a server need the agreement.
  bool get _needsTick => ref.read(accountProvider) != null;

  bool get _detailsOk {
    final m = _mobile.text.replaceAll(RegExp(r'[^0-9]'), '');
    final e = _email.text.trim();
    return m.length >= 10 || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  bool get _canNext => switch (_step) {
    1 => _detailsOk,
    2 => _accountMode != null,
    _ => true,
  };

  /// The start step has its own two buttons.
  bool get _ownButtons => _step == 0;

  Future<void> _choose(String mode) async {
    if (_needsTick && !_ticked) {
      toast(context, tr('Tick the box to agree first'));
      return;
    }
    setState(() => _dataMode = mode);
    await _continueFromDataMode();
  }

  /// Choosing Online Mode asks for the Google sign-in right here, so the user
  /// is never left "online" without an account.
  Future<void> _continueFromDataMode() async {
    if (_needsTick) await recordAgreement(ref.read(repoProvider));
    if (_dataMode != 'online') {
      _go(1);
      return;
    }
    if (_signedInAs != null) {
      _go(2);
      return;
    }
    final sync = ref.read(syncServiceProvider);
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
    // the same sign-in also covers home sharing, so it is not asked again
    final account = ref.read(accountProvider);
    if (account != null && sync.lastIdToken != null) {
      await signInWithConsent(context, account, have: sync.lastIdToken);
      if (!mounted) return;
    }
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
      // "Start fresh": leave the old Drive data behind for good.
      if (restore == false) {
        try {
          await sync.startFreshInDrive();
        } catch (_) {
          if (mounted) {
            toast(context, 'Could not reach Google Drive. Try again.');
            setState(() => _signedInAs = null);
          }
          return;
        }
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
      await repo.setSetting('language', _lang);
      await repo.setSetting('currency', _cur);
      if (_dataMode == 'offline') {
        await repo.setSetting('profileName', _name.text.trim());
        await repo.setSetting('profileMobile', _mobile.text.trim());
        await repo.setSetting('profileEmail', _email.text.trim());
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
                children: [_startPage(), _detailsPage(), _moneyPage()],
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
                        onPressed: _saving
                            ? null
                            : () => _go(
                                _step == 2 && _dataMode == 'online'
                                    ? 0
                                    : _step - 1,
                              ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                  if (_ownButtons)
                    Expanded(child: _startButtons())
                  else
                    Expanded(
                      child: FilledButton(
                        onPressed: !_canNext || _saving
                            ? null
                            : (_step == _steps - 1
                                  ? _finish
                                  : () => _go(_step + 1)),
                        child: Text(
                          _step == _steps - 1
                              ? 'Start using Cash++'
                              : 'Continue',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startButtons() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_needsTick)
        ConsentCheck(
          value: _ticked,
          onChanged: (v) => setState(() => _ticked = v),
        ),
      const SizedBox(height: Sp.x2),
      FilledButton.icon(
        onPressed: _saving || _signingIn ? null : () => _choose('online'),
        icon: _signingIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.account_circle_outlined),
        label: const Text('Continue with Google'),
      ),
      const SizedBox(height: Sp.x3),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _saving || _signingIn ? null : () => _choose('offline'),
        child: Text(tr('Use offline')),
      ),
    ],
  );

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

  Widget _moneyPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        tr('How do you keep money?'),
        tr('Switch any time without losing history.'),
      ),
      Row(
        children: [
          for (final o in [
            ('combined', 'One balance', 'Simplest'),
            ('split', 'Separate balances', 'Cash and bank apart'),
          ]) ...[
            if (o.$1 == 'split') const SizedBox(width: Sp.x3),
            Expanded(
              child: Semantics(
                button: true,
                selected: _accountMode == o.$1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Sp.rCard),
                  onTap: () {
                    haptic();
                    setState(() => _accountMode = o.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: Sp.x5,
                      horizontal: Sp.x3,
                    ),
                    decoration: BoxDecoration(
                      color: _accountMode == o.$1
                          ? context.scheme.primaryContainer
                          : context.cash.surfaceRaised,
                      borderRadius: BorderRadius.circular(Sp.rCard),
                      border: Border.all(
                        color: _accountMode == o.$1
                            ? context.scheme.onSurface
                            : context.scheme.outlineVariant,
                        width: _accountMode == o.$1 ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          tr(o.$2),
                          textAlign: TextAlign.center,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(o.$3),
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(
                            color: context.cash.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: Sp.x6),
      AmountField(
        controller: _cash,
        label: _accountMode == 'split' ? 'Cash in hand' : 'Balance now',
      ),
      if (_accountMode == 'split') ...[
        const SizedBox(height: Sp.x4),
        AmountField(controller: _bank, label: tr('Bank balance')),
      ],
      const SizedBox(height: Sp.x2),
      Text(
        tr('Leave it empty if unsure. You can change it later.'),
        style: context.text.bodySmall?.copyWith(color: context.cash.textMuted),
      ),
    ],
  );

  Widget _detailsPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(tr('Your details'), tr('Mobile or email is needed.')),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: InputDecoration(labelText: tr('Name')),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Sp.x4),
      TextField(
        controller: _mobile,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: InputDecoration(labelText: tr('Mobile')),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Sp.x4),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: tr('Email'),
          hintText: 'you@example.com',
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Sp.x3),
      Text(
        tr('Your money entries are never sent anywhere.'),
        style: context.text.bodySmall?.copyWith(color: context.cash.textMuted),
      ),
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

  Widget _startPage() {
    final lang = appLanguages.firstWhere((l) => l.code == _lang);
    final cur = currencyByCode(_cur);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
      children: [
        _header(
          tr('Feel good about your money.'),
          tr(
            'Track spending, plan ahead, and share a home budget when you are ready.',
          ),
          art: Art.welcome,
        ),
        Row(
          children: [
            Expanded(
              child: _pickTile(
                Icons.translate,
                tr('Language'),
                lang.native,
                _pickLanguage,
              ),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: _pickTile(
                Icons.payments_outlined,
                tr('Currency'),
                '${cur.symbol} ${cur.code}',
                _pickCurrency,
              ),
            ),
          ],
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../providers.dart';
import '../ui/art.dart';
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
  int _step = 0;
  String? _dataMode;
  String? _accountMode;
  bool _cashCard = false;
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  bool _saving = false;
  static const _steps = 4;

  bool get _canNext => switch (_step) {
    0 => _dataMode != null,
    1 => _accountMode != null,
    _ => true,
  };

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
            cashCard: _cashCard,
            openingCashMinor: cash,
            openingBankMinor: bank,
          );
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
                  _choicePage(
                    art: Art.welcome,
                    title: 'Where should your data live?',
                    body: 'You can change this later in Settings.',
                    options: [
                      _Opt(
                        'offline',
                        Icons.phonelink_lock_outlined,
                        'Offline Mode',
                        'Everything stays on this device. No cloud sync, no sign-in.',
                      ),
                      _Opt(
                        'online',
                        Icons.cloud_sync_outlined,
                        'Online Mode',
                        'Stored on this device and synced to your Google Drive (private app folder).',
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
                        'Combined account',
                        'One overall balance.',
                      ),
                      _Opt(
                        'split',
                        Icons.call_split,
                        'Split accounts',
                        'Separate balances for cash and each bank account.',
                      ),
                    ],
                    value: _accountMode,
                    onChanged: (v) => setState(() => _accountMode = v),
                  ),
                  _cashCardPage(),
                  _openingPage(),
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
                  Expanded(
                    child: FilledButton(
                      onPressed: !_canNext || _saving
                          ? null
                          : (_step == _steps - 1
                                ? _finish
                                : () => _go(_step + 1)),
                      child: Text(
                        _step == _steps - 1
                            ? 'Start using Cash Buddy'
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

  Widget _cashCardPage() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
    children: [
      _header(
        'Cash vs card?',
        'Optionally tag every transaction as cash or card to see the split on your dashboard.',
      ),
      Card(
        child: SwitchListTile.adaptive(
          title: const Text('Track cash and card separately'),
          subtitle: const Text('You can turn this off any time.'),
          value: _cashCard,
          onChanged: (v) => setState(() => _cashCard = v),
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
        AmountField(controller: _bank, label: 'Bank balance'),
      ],
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

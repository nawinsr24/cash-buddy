import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/access.dart';
import '../providers.dart';
import '../ui/theme.dart';
import 'backup_actions.dart';

/// Null (the usual build) means there is no server and nothing to check.
final accessProvider = Provider<Access?>((ref) {
  if (!AccessConfig.fromBuild.enabled) return null;
  return Access(ref.watch(repoProvider));
});

/// Shows the app at once and checks in the background.
class AccessGate extends ConsumerStatefulWidget {
  final Widget child;
  const AccessGate({super.key, required this.child});
  @override
  ConsumerState<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends ConsumerState<AccessGate>
    with WidgetsBindingObserver {
  var _blocked = false;
  var _needsNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check(startup: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  void _show(bool blocked) {
    if (mounted && blocked != _blocked) setState(() => _blocked = blocked);
  }

  Future<void> _check({bool startup = false}) async {
    final access = ref.read(accessProvider);
    if (access == null) return;
    if (startup) _show(await access.isBlocked); // what was saved
    // Nothing is sent before the user has been told and agreed.
    if (await access.repo.getSetting('serverNotice') != '1') {
      if (mounted) setState(() => _needsNotice = true);
      return;
    }
    _show(await access.check());
  }

  Future<void> _agree() async {
    await ref.read(accessProvider)!.repo.setSetting('serverNotice', '1');
    if (!mounted) return;
    setState(() => _needsNotice = false);
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return _BlockedScreen(onRetry: _check);
    return _needsNotice ? _NoticeScreen(onAgree: _agree) : widget.child;
  }
}

/// Shown once, before the app first contacts its server.
class _NoticeScreen extends StatelessWidget {
  final VoidCallback onAgree;
  const _NoticeScreen({required this.onAgree});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Before you continue'),
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final line in [
                'Cash++ now checks with its server that it may run.',
                'It sends a random ID for this phone. The server notes when it connected.',
                'Your entries, balances and notes are not sent.',
                'Access to the app can be turned off.',
              ])
                Padding(
                  padding: const EdgeInsets.only(top: Sp.x3),
                  child: Text(tr(line)),
                ),
              const SizedBox(height: Sp.x5),
              FilledButton(onPressed: onAgree, child: Text(tr('I agree'))),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BlockedScreen extends ConsumerWidget {
  final Future<void> Function() onRetry;
  const _BlockedScreen({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: Sp.x4),
              Text(
                tr('Access has been turned off'),
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Sp.x2),
              Text(
                tr('Your data is still on this phone.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.x5),
              FilledButton(onPressed: onRetry, child: Text(tr('Check again'))),
              TextButton(
                onPressed: () => saveBackup(context, ref),
                child: Text(tr('Back up now')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

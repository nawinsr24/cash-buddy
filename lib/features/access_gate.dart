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
    _show(await access.check());
  }

  @override
  Widget build(BuildContext context) =>
      _blocked ? _BlockedScreen(onRetry: _check) : widget.child;
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

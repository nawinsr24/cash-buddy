import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers.dart';
import '../ui/theme.dart';

/// Abstraction so tests can fake the OS biometric / device-credential prompt.
abstract class Authenticator {
  Future<bool> get available;
  Future<bool> authenticate(String reason);
}

class DeviceAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> get available async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometrics with fallback to the phone's PIN / pattern / password
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    }
  }
}

final authenticatorProvider = Provider<Authenticator>(
  (_) => DeviceAuthenticator(),
);

/// Blocks the app behind the device lock when "App lock" is on. Re-locks after
/// the app has been in the background for [relockAfter].
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  final Duration relockAfter;
  const AppLockGate({
    super.key,
    required this.child,
    this.relockAfter = const Duration(seconds: 30),
  });
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _prompting = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (p != null && DateTime.now().difference(p) >= widget.relockAfter) {
        setState(() => _unlocked = false);
      }
    }
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    final ok = await ref
        .read(authenticatorProvider)
        .authenticate('Unlock Cash Buddy');
    _prompting = false;
    if (mounted && ok) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).value?.appLock ?? false;
    if (!enabled || _unlocked) return widget.child;
    // First frame of a locked app: prompt immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: context.scheme.primary),
              const SizedBox(height: Sp.x4),
              Text('Cash Buddy is locked', style: context.text.titleLarge),
              const SizedBox(height: Sp.x2),
              Text(
                'Your finances are hidden until you unlock.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
              const SizedBox(height: Sp.x6),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                onPressed: _unlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

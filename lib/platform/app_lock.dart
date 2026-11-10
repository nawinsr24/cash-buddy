import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../ui/theme.dart';

/// Abstraction so tests can fake the OS biometric / device-credential prompt.
abstract class Authenticator {
  Future<bool> get available;
  Future<bool> authenticate(String reason);

  /// Closes a prompt that is still open (or stuck), so a new one can start.
  Future<void> stop() async {}

  /// Plain-words reason the last attempt failed (too many tries, no lock set
  /// up), or null when it was simply cancelled.
  String? get problem => null;
}

class DeviceAuthenticator extends Authenticator {
  final _auth = LocalAuthentication();
  String? _problem;

  @override
  String? get problem => _problem;

  @override
  Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }

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
    _problem = null;
    try {
      // biometrics with fallback to the phone's PIN / pattern / password
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException catch (e) {
      _problem = switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Too many tries. Wait a moment, or use your phone PIN.',
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          'Set up a screen lock in your phone settings first.',
        _ => null,
      };
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

final authenticatorProvider = Provider<Authenticator>(
  (_) => DeviceAuthenticator(),
);

/// Blocks the app behind the device lock when "App lock" is on. Re-locks after
/// the app has been in the background for the time chosen in Settings.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  /// Overrides the Settings value (tests).
  final Duration? relockAfter;
  const AppLockGate({super.key, required this.child, this.relockAfter});

  static DateTime? _holdUntil;

  /// Call right before the app opens a system screen of its own (a permission
  /// dialog, Google sign-in). Coming back from it will not re-lock the app.
  static void holdOff([Duration d = const Duration(seconds: 90)]) =>
      _holdUntil = DateTime.now().add(d);
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _prompting = false;
  bool _autoPrompted = false;
  String? _problem;
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
      final hold = AppLockGate._holdUntil;
      if (hold != null && DateTime.now().isBefore(hold)) return;
      final after =
          widget.relockAfter ??
          Duration(
            seconds: ref.read(settingsProvider).value?.lockAfterSeconds ?? 300,
          );
      if (!_prompting && p != null && DateTime.now().difference(p) >= after) {
        setState(() {
          _unlocked = false;
          _autoPrompted = false; // ask once when it locks again
        });
      }
    }
  }

  /// [force] is the Unlock button: it always closes anything stuck and opens
  /// a fresh prompt, so cancelling once never leaves the user with a dead button.
  Future<void> _unlock({bool force = false}) async {
    final auth = ref.read(authenticatorProvider);
    if (force) {
      await auth.stop();
      _prompting = false;
    } else if (_prompting) {
      return;
    }
    _prompting = true;
    var ok = false;
    try {
      ok = await auth.authenticate('Unlock Cash++');
    } catch (_) {
      ok = false; // never leave the lock screen stuck on an unexpected error
    } finally {
      _prompting = false;
    }
    if (!mounted) return;
    if (ok) {
      setState(() {
        _unlocked = true;
        _problem = null;
      });
    } else if (auth.problem != _problem) {
      setState(() => _problem = auth.problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).value?.appLock ?? false;
    if (!enabled || _unlocked) return widget.child;
    // First frame of a locked app: prompt once. After that only the Unlock
    // button asks again, so a cancelled prompt never loops or gets stuck.
    if (!_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: context.scheme.primary),
              const SizedBox(height: Sp.x4),
              Text(tr('Cash++ is locked'), style: context.text.titleLarge),
              const SizedBox(height: Sp.x2),
              Text(
                'Your finances are hidden until you unlock.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.cash.textMuted,
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: Sp.x3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
                  child: Text(
                    _problem!,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.cash.spending,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Sp.x6),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                icon: const Icon(Icons.fingerprint),
                label: Text(tr('Unlock')),
                onPressed: () => _unlock(force: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

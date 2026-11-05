import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/onboarding.dart';
import 'features/shell.dart';
import 'platform/app_lock.dart';
import 'providers.dart';
import 'ui/theme.dart';

class CashBuddyApp extends ConsumerWidget {
  const CashBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final mode = switch (s.value?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system, // follows the device appearance live
    };
    return MaterialApp(
      title: 'Cash++',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: mode,
      // Once settings have loaded, never swap back to a spinner: they reload
      // on every database write, and replacing the app would rebuild the
      // whole UI (and re-lock it) each time.
      home: s.hasValue
          ? (s.value!.onboarded
                ? const AppLockGate(child: Shell())
                : const OnboardingPage())
          : s.hasError
          ? Scaffold(body: Center(child: Text('${s.error}')))
          : const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            ),
    );
  }
}

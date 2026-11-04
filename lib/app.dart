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
      title: 'Cash Buddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: mode,
      home: s.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (v) => v.onboarded
            ? const AppLockGate(child: Shell())
            : const OnboardingPage(),
      ),
    );
  }
}

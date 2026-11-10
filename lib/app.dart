import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/money.dart';
import 'features/onboarding.dart';
import 'l10n/l10n.dart';
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
    final set = s.value;
    if (set != null) {
      L10n.use(set.language);
      Money.configure(code: set.currency);
    }
    return MaterialApp(
      // Changing language or currency rebuilds the whole app once. During
      // first-run setup the wizard keeps its own state, so no key then.
      key: set != null && set.onboarded
          ? ValueKey('${set.language}-${set.currency}')
          : null,
      locale: L10n.locale,
      supportedLocales: [for (final l in appLanguages) Locale(l.code)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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

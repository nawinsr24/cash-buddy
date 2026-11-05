import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Semantic colours that are not part of Material's ColorScheme.
@immutable
class CashColors extends ThemeExtension<CashColors> {
  final Color income,
      spending,
      debtIn,
      liability,
      surfaceRaised,
      textMuted,
      positiveBg,
      negativeBg;
  const CashColors({
    required this.income,
    required this.spending,
    required this.debtIn,
    required this.liability,
    required this.surfaceRaised,
    required this.textMuted,
    required this.positiveBg,
    required this.negativeBg,
  });

  static const light = CashColors(
    income: Color(0xFF12805C),
    spending: Color(0xFFD1344B),
    debtIn: Color(0xFFB7791F),
    liability: Color(0xFF6D4AD6),
    surfaceRaised: Color(0xFFFFFFFF),
    textMuted: Color(0xFF667085),
    positiveBg: Color(0xFFE6F6EF),
    negativeBg: Color(0xFFFDECEF),
  );
  static const dark = CashColors(
    income: Color(0xFF3DD6A0),
    spending: Color(0xFFFF7A8E),
    debtIn: Color(0xFFF5B547),
    liability: Color(0xFFA98BFF),
    surfaceRaised: Color(0xFF1B2230),
    textMuted: Color(0xFF9AA4B5),
    positiveBg: Color(0xFF12332A),
    negativeBg: Color(0xFF3A1D25),
  );

  @override
  CashColors copyWith({
    Color? income,
    Color? spending,
    Color? debtIn,
    Color? liability,
    Color? surfaceRaised,
    Color? textMuted,
    Color? positiveBg,
    Color? negativeBg,
  }) => CashColors(
    income: income ?? this.income,
    spending: spending ?? this.spending,
    debtIn: debtIn ?? this.debtIn,
    liability: liability ?? this.liability,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    textMuted: textMuted ?? this.textMuted,
    positiveBg: positiveBg ?? this.positiveBg,
    negativeBg: negativeBg ?? this.negativeBg,
  );

  @override
  CashColors lerp(CashColors? other, double t) => other == null
      ? this
      : CashColors(
          income: Color.lerp(income, other.income, t)!,
          spending: Color.lerp(spending, other.spending, t)!,
          debtIn: Color.lerp(debtIn, other.debtIn, t)!,
          liability: Color.lerp(liability, other.liability, t)!,
          surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
          textMuted: Color.lerp(textMuted, other.textMuted, t)!,
          positiveBg: Color.lerp(positiveBg, other.positiveBg, t)!,
          negativeBg: Color.lerp(negativeBg, other.negativeBg, t)!,
        );
}

extension CashTheme on BuildContext {
  CashColors get cash => Theme.of(this).extension<CashColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Spacing / radius tokens (4-pt grid).
class Sp {
  static const double x1 = 4,
      x2 = 8,
      x3 = 12,
      x4 = 16,
      x5 = 20,
      x6 = 24,
      x8 = 32;
  static const double rCard = 20, rChip = 12, rField = 14;
}

class AppTheme {
  static const _seed = Color(0xFF2F6BFF);

  static ThemeData build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b)
        .copyWith(
          surface: dark ? const Color(0xFF0E131C) : const Color(0xFFF5F7FB),
          primary: dark ? const Color(0xFF7FA2FF) : _seed,
        );
    final colors = dark ? CashColors.dark : CashColors.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.rCard),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: dark ? 0.4 : 0.6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rField),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rField),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceRaised,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.rChip),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.rField),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Tabular figures so money columns align.
const moneyFeatures = [FontFeature.tabularFigures()];

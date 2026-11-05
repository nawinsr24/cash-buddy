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
    income: Color(0xFF0B8A5F),
    spending: Color(0xFFD91A45),
    debtIn: Color(0xFFB45309),
    liability: Color(0xFF7C3AED),
    surfaceRaised: Color(0xFFFFFFFF),
    textMuted: Color(0xFF596070),
    positiveBg: Color(0xFFE7F7F0),
    negativeBg: Color(0xFFFDEBEF),
  );
  static const dark = CashColors(
    income: Color(0xFF34D399),
    spending: Color(0xFFFB7185),
    debtIn: Color(0xFFFBBF24),
    liability: Color(0xFFA78BFA),
    surfaceRaised: Color(0xFF14161B),
    textMuted: Color(0xFF9AA1AD),
    positiveBg: Color(0xFF0F2A21),
    negativeBg: Color(0xFF331820),
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
  static const double rCard = 22, rChip = 12, rField = 14;
}

class AppTheme {
  /// Ink-and-indigo: neutral surfaces, one accent, colour only where it means
  /// something (money in, money out, status).
  static const accentLight = Color(0xFF4F46E5);
  static const accentDark = Color(0xFF8B93FF);

  static ThemeData build(Brightness b) {
    final dark = b == Brightness.dark;
    final accent = dark ? accentDark : accentLight;
    final ink = dark ? const Color(0xFFF4F5F7) : const Color(0xFF0F1115);
    final bg = dark ? const Color(0xFF0B0C10) : const Color(0xFFF6F6F8);
    final hairline = dark ? const Color(0xFF23262D) : const Color(0xFFE6E7EB);
    final scheme = ColorScheme.fromSeed(seedColor: accentLight, brightness: b)
        .copyWith(
          primary: accent,
          onPrimary: dark ? const Color(0xFF0B0C10) : Colors.white,
          primaryContainer: accent.withValues(alpha: dark ? 0.22 : 0.12),
          onPrimaryContainer: ink,
          surface: bg,
          onSurface: ink,
          outlineVariant: hairline,
          outline: dark ? const Color(0xFF3A3E47) : const Color(0xFFC9CCD3),
        );
    final colors = dark ? CashColors.dark : CashColors.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
    );
    final tt = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      extensions: [colors],
      textTheme: tt.copyWith(
        headlineLarge: tt.headlineLarge?.copyWith(
          letterSpacing: -1.0,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: tt.headlineMedium?.copyWith(
          letterSpacing: -0.8,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: tt.headlineSmall?.copyWith(
          letterSpacing: -0.5,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: tt.titleLarge?.copyWith(
          letterSpacing: -0.3,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: tt.titleMedium?.copyWith(
          letterSpacing: -0.1,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.rCard),
          side: BorderSide(color: hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rField),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rField),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rField),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: accent.withValues(alpha: dark ? 0.2 : 0.1),
        labelTextStyle: WidgetStatePropertyAll(
          tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : colors.textMuted,
            size: 24,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.rChip),
        ),
        side: BorderSide(color: hairline),
        backgroundColor: colors.surfaceRaised,
        selectedColor: accent.withValues(alpha: dark ? 0.24 : 0.12),
        labelStyle: tt.labelLarge,
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          textStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.rField),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: hairline),
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.rField),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide(color: hairline),
          selectedBackgroundColor: accent.withValues(alpha: dark ? 0.24 : 0.12),
          selectedForegroundColor: ink,
          foregroundColor: colors.textMuted,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: bg,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: ListTileThemeData(iconColor: colors.textMuted),
      // Every popup surface is set explicitly so dialogs, sheets, menus and
      // pickers look right in both light and dark (no default tinting).
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        contentTextStyle: tt.bodyMedium?.copyWith(color: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surfaceRaised,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colors.surfaceRaised,
        headerForegroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? scheme.onPrimary
              : (dark ? const Color(0xFF9AA1AD) : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? accent
              : (dark ? const Color(0xFF2B2E36) : const Color(0xFFD5D8DF)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: hairline,
        circularTrackColor: hairline,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2B2E36) : const Color(0xFF1F2330),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: tt.bodyMedium?.copyWith(color: bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Tabular figures so money columns align.
const moneyFeatures = [FontFeature.tabularFigures()];

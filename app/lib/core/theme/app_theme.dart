import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:flutter/material.dart';

/// Light and dark themes, matching the prototype.
///
/// The prototype specifies both, so both ship. Dark mode matters more than
/// usual here — the app is used in the evening at restaurants and bars.
abstract final class AppTheme {
  static ThemeData light = _build(AppPalette.light);
  static ThemeData dark = _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.red,
      primary: p.red,
      onPrimary: p.onRed,
      secondary: p.gold,
      onSecondary: p.goldInk,
      tertiary: p.blue,
      surface: p.surface,
      onSurface: p.ink,
      error: p.bad,
      onError: p.surface,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
    );

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Corners.lg),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.app,
      canvasColor: p.app,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: p.line,

      extensions: [AppPaletteTheme(p)],

      textTheme: TextTheme(
        displayLarge: AppText.displayLarge.copyWith(color: p.ink),
        displayMedium: AppText.displayMedium.copyWith(color: p.ink),
        titleLarge: AppText.titleLarge.copyWith(color: p.ink),
        titleMedium: AppText.titleMedium.copyWith(color: p.ink),
        titleSmall: AppText.titleSmall.copyWith(color: p.ink),
        bodyLarge: AppText.bodyLarge.copyWith(color: p.ink),
        bodyMedium: AppText.bodyMedium.copyWith(color: p.ink),
        labelLarge: AppText.labelLarge.copyWith(color: p.ink),
        labelMedium: AppText.labelMedium.copyWith(color: p.ink),
        bodySmall: AppText.caption.copyWith(color: p.muted),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.titleLarge.copyWith(color: p.ink),
      ),

      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.xxl),
          side: BorderSide(color: p.line),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Touch.minimum),
          // Red, as in the design's primary actions (Call, Save Event).
          backgroundColor: p.red,
          foregroundColor: p.onRed,
          disabledBackgroundColor: p.red.withValues(alpha: 0.35),
          textStyle: AppText.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.xxl),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Touch.minimum),
          foregroundColor: p.red,
          backgroundColor: p.surface,
          side: BorderSide(color: p.red),
          textStyle: AppText.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.xxl),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.blue,
          textStyle: AppText.labelMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.giant,
          vertical: Insets.xl,
        ),
        hintStyle: AppText.bodyLarge.copyWith(color: p.muted),
        labelStyle: AppText.labelMedium.copyWith(color: p.muted),
        enabledBorder: border(p.line),
        focusedBorder: border(p.blue),
        border: border(p.line),
      ),

      // A selected chip is filled with the ink colour, so its label must
      // flip to the background colour. With one label colour for both
      // states, dark mode drew selected chips white on white (ink is white
      // there); light mode only worked because the default flipped it.
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.ink,
        checkmarkColor: p.app,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => AppText.labelMedium.copyWith(
            color: states.contains(WidgetState.selected) ? p.app : p.ink,
          ),
        ),
        secondaryLabelStyle: AppText.labelMedium.copyWith(color: p.app),
        side: BorderSide(color: p.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.sm,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? p.red : p.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.labelMedium.copyWith(
            fontSize: 11,
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: AppText.bodyMedium.copyWith(color: p.app),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.xl),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.app,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.xxl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.app,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Corners.xxl),
          ),
        ),
      ),
    );
  }
}

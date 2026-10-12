import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'semantic_colors.dart';

export 'app_tokens.dart';
export 'intent_button.dart';
export 'semantic_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme(base) : _lightScheme(base);
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      extensions: [
        brightness == Brightness.dark
            ? AppSemanticColors.dark
            : AppSemanticColors.light,
      ],
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        selectedLabelTextStyle: TextStyle(color: scheme.onSurface),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(scheme.outline),
        thickness: const WidgetStatePropertyAll<double>(8),
        radius: const Radius.circular(8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : scheme.onInverseSurface,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
      ),
    );
  }

  /// Paleta clara arena Sahara con controles taupe y superficies cálidas.
  static ColorScheme _lightScheme(ColorScheme base) => base.copyWith(
    primary: const Color(0xFF665C49),
    onPrimary: const Color(0xFFFFFCF6),
    primaryContainer: const Color(0xFFE3D7C0),
    onPrimaryContainer: const Color(0xFF2F2A21),
    secondary: const Color(0xFF766B57),
    onSecondary: const Color(0xFFFFFCF6),
    secondaryContainer: const Color(0xFFE6DCC8),
    onSecondaryContainer: const Color(0xFF332E24),
    tertiary: const Color(0xFF74684F),
    onTertiary: const Color(0xFFFFFCF6),
    surface: const Color(0xFFF3EDDF),
    surfaceDim: const Color(0xFFE4DAC7),
    surfaceContainerLowest: const Color(0xFFFFFCF6),
    surfaceContainerLow: const Color(0xFFF8F3E8),
    surfaceContainer: const Color(0xFFF1EADB),
    surfaceContainerHigh: const Color(0xFFEAE1D0),
    surfaceContainerHighest: const Color(0xFFDED3BE),
    onSurface: const Color(0xFF29271F),
    onSurfaceVariant: const Color(0xFF514B3F),
    outline: const Color(0xFF756C5B),
    outlineVariant: const Color(0xFFB4A78E),
  );

  /// Paleta oscura carbón-oliva con superficies cálidas y selección gris salvia.
  static ColorScheme _darkScheme(ColorScheme base) => base.copyWith(
    primary: const Color(0xFFACADA2),
    onPrimary: const Color(0xFF24251F),
    primaryContainer: const Color(0xFF45463F),
    onPrimaryContainer: const Color(0xFFE5E6DF),
    secondary: const Color(0xFF999A8F),
    onSecondary: const Color(0xFF24251F),
    secondaryContainer: const Color(0xFF41423B),
    onSecondaryContainer: const Color(0xFFEBECE4),
    tertiary: const Color(0xFFB8B9AE),
    onTertiary: const Color(0xFF24251F),
    surface: const Color(0xFF252620),
    surfaceDim: const Color(0xFF20211D),
    surfaceContainerLowest: const Color(0xFF20211D),
    surfaceContainerLow: const Color(0xFF2B2C26),
    surfaceContainer: const Color(0xFF30312B),
    surfaceContainerHigh: const Color(0xFF383932),
    surfaceContainerHighest: const Color(0xFF41423B),
    onSurface: const Color(0xFFE1E2DC),
    onSurfaceVariant: const Color(0xFFB9BAB2),
    outline: const Color(0xFF92938A),
    outlineVariant: const Color(0xFF55564E),
  );
}

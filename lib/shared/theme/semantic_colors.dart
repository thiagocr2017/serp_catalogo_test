import 'package:flutter/material.dart';

/// Roles semanticos que Material ColorScheme no define directamente.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.successBackground,
    required this.successForeground,
    required this.warningBackground,
    required this.warningForeground,
    required this.infoBackground,
    required this.infoForeground,
  });

  final Color successBackground;
  final Color successForeground;
  final Color warningBackground;
  final Color warningForeground;
  final Color infoBackground;
  final Color infoForeground;

  static const light = AppSemanticColors(
    successBackground: Color(0xFFDCFCE7),
    successForeground: Color(0xFF166534),
    warningBackground: Color(0xFFFEF3C7),
    warningForeground: Color(0xFF854D0E),
    infoBackground: Color(0xFFDBEAFE),
    infoForeground: Color(0xFF1E40AF),
  );

  static const dark = AppSemanticColors(
    successBackground: Color(0xFF173D2A),
    successForeground: Color(0xFFB7E4C7),
    warningBackground: Color(0xFF4B3517),
    warningForeground: Color(0xFFFFD08A),
    infoBackground: Color(0xFF183A55),
    infoForeground: Color(0xFFA8D8FF),
  );

  @override
  AppSemanticColors copyWith({
    Color? successBackground,
    Color? successForeground,
    Color? warningBackground,
    Color? warningForeground,
    Color? infoBackground,
    Color? infoForeground,
  }) => AppSemanticColors(
    successBackground: successBackground ?? this.successBackground,
    successForeground: successForeground ?? this.successForeground,
    warningBackground: warningBackground ?? this.warningBackground,
    warningForeground: warningForeground ?? this.warningForeground,
    infoBackground: infoBackground ?? this.infoBackground,
    infoForeground: infoForeground ?? this.infoForeground,
  );

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      successBackground: Color.lerp(
        successBackground,
        other.successBackground,
        t,
      )!,
      successForeground: Color.lerp(
        successForeground,
        other.successForeground,
        t,
      )!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      warningForeground: Color.lerp(
        warningForeground,
        other.warningForeground,
        t,
      )!,
      infoBackground: Color.lerp(infoBackground, other.infoBackground, t)!,
      infoForeground: Color.lerp(infoForeground, other.infoForeground, t)!,
    );
  }
}

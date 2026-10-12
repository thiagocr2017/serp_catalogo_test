import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/shared/theme/app_theme.dart';

void main() {
  for (final entry in {
    'claro': AppTheme.light,
    'oscuro': AppTheme.dark,
  }.entries) {
    test(
      'el tema ${entry.key} conserva contraste en información y botones',
      () {
        final colors = entry.value.colorScheme;
        final semantic = entry.value.extension<AppSemanticColors>()!;
        expect(_contrast(colors.onSurface, colors.surface), greaterThan(4.5));
        expect(_contrast(colors.onPrimary, colors.primary), greaterThan(4.5));
        expect(
          _contrast(colors.onSecondaryContainer, colors.secondaryContainer),
          greaterThan(4.5),
        );
        expect(
          _contrast(colors.onErrorContainer, colors.errorContainer),
          greaterThan(4.5),
        );
        expect(
          _contrast(semantic.successForeground, semantic.successBackground),
          greaterThan(4.5),
        );
        expect(
          _contrast(semantic.warningForeground, semantic.warningBackground),
          greaterThan(4.5),
        );
        expect(
          _contrast(semantic.infoForeground, semantic.infoBackground),
          greaterThan(4.5),
        );
      },
    );
  }

  darkModeChecks();
  lightModeChecks();
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + .05) / (darker + .05);
}

void darkModeChecks() {
  test('tema oscuro usa la paleta carbón-oliva y selección gris salvia', () {
    final colors = AppTheme.dark.colorScheme;
    expect(colors.surface, const Color(0xFF252620));
    expect(colors.surfaceContainerHighest, const Color(0xFF41423B));
    expect(colors.secondaryContainer, const Color(0xFF41423B));
    expect(colors.primary, const Color(0xFFACADA2));
  });

  test('el tema oscuro mejora legibilidad y jerarquía de superficies', () {
    final colors = AppTheme.dark.colorScheme;
    expect(
      _contrast(colors.onSurfaceVariant, colors.surface),
      greaterThan(4.5),
    );
    expect(_contrast(colors.outlineVariant, colors.surface), greaterThan(1.8));
    expect(
      _contrast(colors.outline, colors.surfaceContainerLowest),
      greaterThan(4.5),
    );
    final steps = [
      colors.surfaceContainerLowest,
      colors.surface,
      colors.surfaceContainerLow,
      colors.surfaceContainer,
      colors.surfaceContainerHigh,
      colors.surfaceContainerHighest,
    ];
    for (var i = 1; i < steps.length; i++) {
      expect(
        steps[i].computeLuminance(),
        greaterThan(steps[i - 1].computeLuminance()),
      );
    }
  });
}

void lightModeChecks() {
  test('tema claro usa la paleta arena Sahara monocromatica', () {
    final colors = AppTheme.light.colorScheme;
    expect(colors.surface, const Color(0xFFF3EDDF));
    expect(colors.surfaceContainerHighest, const Color(0xFFDED3BE));
    expect(colors.primary, const Color(0xFF665C49));
    expect(colors.secondaryContainer, const Color(0xFFE6DCC8));
  });

  test('tema claro conserva legibilidad y jerarquia de superficies', () {
    final colors = AppTheme.light.colorScheme;
    expect(
      _contrast(colors.onSurfaceVariant, colors.surface),
      greaterThan(4.5),
    );
    expect(_contrast(colors.outlineVariant, colors.surface), greaterThan(1.8));
    expect(
      _contrast(colors.onSecondaryContainer, colors.secondaryContainer),
      greaterThan(4.5),
    );
    final steps = [
      colors.surfaceContainerLowest,
      colors.surfaceContainerLow,
      colors.surface,
      colors.surfaceContainer,
      colors.surfaceContainerHigh,
      colors.surfaceContainerHighest,
    ];
    for (var i = 1; i < steps.length; i++) {
      expect(
        steps[i].computeLuminance(),
        lessThan(steps[i - 1].computeLuminance()),
      );
    }
  });
}

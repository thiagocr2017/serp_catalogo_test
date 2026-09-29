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
      },
    );
  }
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

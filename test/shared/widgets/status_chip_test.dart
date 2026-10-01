import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/shared/theme/app_theme.dart';
import 'package:serp/shared/widgets/status_chip.dart';

void main() {
  testWidgets('StatusChip usa colores adaptados al tema', (tester) async {
    Future<(Color background, Color foreground)> render(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: StatusChip(label: 'Activo', tone: StatusTone.success),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = tester.widget<Chip>(find.byType(Chip));
      final text = tester.widget<Text>(find.text('Activo'));
      return (chip.backgroundColor!, text.style!.color!);
    }

    final (lightBg, lightFg) = await render(AppTheme.light);
    final (darkBg, darkFg) = await render(AppTheme.dark);

    expect(lightBg, isNot(darkBg));
    expect(lightFg, isNot(darkFg));
    expect(_contrast(lightFg, lightBg), greaterThan(4.5));
    expect(_contrast(darkFg, darkBg), greaterThan(4.5));
  });
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

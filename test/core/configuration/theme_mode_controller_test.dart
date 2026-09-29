import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/configuration/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses dark mode when the user has no saved preference', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(themeModeProvider.future), ThemeMode.dark);
  });

  test('persists the user theme selection', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    await container.read(themeModeProvider.future);
    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.light);
    container.dispose();

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(themeModeProvider.future), ThemeMode.light);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModePreferenceKey = 'serp_theme_mode';

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(themeModePreferenceKey) == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) return;
    state = AsyncData(mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      themeModePreferenceKey,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }
}

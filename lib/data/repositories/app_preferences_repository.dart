import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appPreferencesRepositoryProvider =
    Provider<AppPreferencesRepository>((ref) {
  return AppPreferencesRepository();
});

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(appPreferencesRepositoryProvider));
});

class AppPreferencesRepository {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _themeModeKey = 'theme_mode';

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_themeModeKey)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._repository) : super(ThemeMode.light) {
    _load();
  }

  final AppPreferencesRepository _repository;
  bool _changed = false;

  Future<void> _load() async {
    final mode = await _repository.themeMode();
    if (mounted && !_changed) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    _changed = true;
    state = mode;
    await _repository.setThemeMode(mode);
  }

  Future<void> setDarkMode(bool enabled) async {
    await setMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }
}

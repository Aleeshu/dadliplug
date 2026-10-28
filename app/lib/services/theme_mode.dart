import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'theme_mode';

/// Dark, light, or following the phone (the redesign's Settings >
/// Accessibility). Remembered on the phone, not the account: a shared
/// tablet at a business can be light while the owner's phone is dark.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = ThemeMode.values
          .where((m) => m.name == prefs.getString(_key))
          .firstOrNull;
      if (saved != null) state = saved;
    } on Object {
      // No storage (tests, a failing plugin): follow the phone.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } on Object {
      // Applied for this session even if it cannot be remembered.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

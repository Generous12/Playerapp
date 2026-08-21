import 'dart:async';
import 'package:flutter/material.dart';
import 'package:playerapp1/clases/configuracion.dart';
import 'package:playerapp1/colores/appcolors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppPalette _palette = AppPalette.aurora;

  ThemeMode get themeMode => _themeMode;
  AppPalette get palette => _palette;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final mode = await ConfigService.instance.getThemeMode();

    if (mode == "dark") {
      _themeMode = ThemeMode.dark;
    } else if (mode == "light") {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    final paletteId = await ConfigService.instance.getValue('palette_id');
    if (paletteId != null) {
      _palette = AppPalette.fromId(paletteId);
      AppColors.setPalette(_palette);
    }

    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    String value = "system";
    if (mode == ThemeMode.dark) value = "dark";
    if (mode == ThemeMode.light) value = "light";

    unawaited(ConfigService.instance.setThemeMode(value));
  }

  void setPalette(AppPalette newPalette) {
    if (_palette.id == newPalette.id) return;
    _palette = newPalette;
    AppColors.setPalette(newPalette);
    notifyListeners();

    unawaited(ConfigService.instance.setValue('palette_id', newPalette.id));
  }
}

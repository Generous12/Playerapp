import 'package:flutter/material.dart';

class AppPalette {
  final String id;
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color accentDark;
  final Color accentLight;

  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.accentDark,
    required this.accentLight,
  });

  // 1. 💎 Nordic Aurora (Cyan + Mint)
  static const AppPalette aurora = AppPalette(
    id: 'aurora',
    name: 'Nordic Aurora',
    primary: Color(0xFF00D2FF),
    primaryDark: Color(0xFF0098BA),
    primaryLight: Color(0xFF6BE6FF),
    accent: Color(0xFF00F5A0),
    accentDark: Color(0xFF00BA7A),
    accentLight: Color(0xFF6BFFC9),
  );

  // 2. ⚡ Cyber Violet (Ultra Violet + Neon Coral)
  static const AppPalette violet = AppPalette(
    id: 'violet',
    name: 'Cyber Violet',
    primary: Color(0xFF7C3AED),
    primaryDark: Color(0xFF5B21B6),
    primaryLight: Color(0xFFA78BFA),
    accent: Color(0xFFFF3366),
    accentDark: Color(0xFFCC1144),
    accentLight: Color(0xFFFF6688),
  );

  // 3. 🌅 Sunset Flare (Solar Amber + Coral)
  static const AppPalette sunset = AppPalette(
    id: 'sunset',
    name: 'Sunset Flare',
    primary: Color(0xFFFF9F43),
    primaryDark: Color(0xFFE07A18),
    primaryLight: Color(0xFFFFBF80),
    accent: Color(0xFFFF5252),
    accentDark: Color(0xFFD63031),
    accentLight: Color(0xFFFF8585),
  );

  // 4. 🌿 Neon Emerald (Crisp Emerald + Teal)
  static const AppPalette emerald = AppPalette(
    id: 'emerald',
    name: 'Neon Emerald',
    primary: Color(0xFF10B981),
    primaryDark: Color(0xFF059669),
    primaryLight: Color(0xFF34D399),
    accent: Color(0xFF00E5FF),
    accentDark: Color(0xFF00B4D8),
    accentLight: Color(0xFF80F0FF),
  );

  // 5. 🌊 Royal Cobalt (Electric Blue + Cyan Sky)
  static const AppPalette cobalt = AppPalette(
    id: 'cobalt',
    name: 'Royal Cobalt',
    primary: Color(0xFF2563EB),
    primaryDark: Color(0xFF1D4ED8),
    primaryLight: Color(0xFF60A5FA),
    accent: Color(0xFF00D2D3),
    accentDark: Color(0xFF01A3A4),
    accentLight: Color(0xFF48DBFB),
  );

  // 6. 🌸 Sakura Glow (Vivid Magenta + Rose)
  static const AppPalette sakura = AppPalette(
    id: 'sakura',
    name: 'Sakura Glow',
    primary: Color(0xFFE11D48),
    primaryDark: Color(0xFFBE123C),
    primaryLight: Color(0xFFFB7185),
    accent: Color(0xFFFF70A6),
    accentDark: Color(0xFFFF3385),
    accentLight: Color(0xFFFFA3C2),
  );

  static const List<AppPalette> all = [
    aurora,
    violet,
    sunset,
    emerald,
    cobalt,
    sakura,
  ];

  static AppPalette fromId(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => aurora);
  }
}

class AppColors {
  static AppPalette _activePalette = AppPalette.aurora;

  static AppPalette get activePalette => _activePalette;

  static void setPalette(AppPalette palette) {
    _activePalette = palette;
  }

  static Color get primary => _activePalette.primary;
  static Color get primaryDark => _activePalette.primaryDark;
  static Color get primaryLight => _activePalette.primaryLight;

  static Color get accent => _activePalette.accent;
  static Color get accentDark => _activePalette.accentDark;
  static Color get accentLight => _activePalette.accentLight;

  static Color get tertiary => _activePalette.primaryDark;

  // 🌑 Superficies Modo Oscuro (Obsidian & Titanium Void)
  static const Color dark = Color(0xFF08090D);           // Deep Obsidian Void
  static const Color darkCard = Color(0xFF11131B);       // Dark Titanium Surface
  static const Color darkSecondary = Color(0xFF181B26);  // Deep Slate Surface
  static const Color darkCardHighlight = Color(0xFF202434);

  // ☀️ Superficies Modo Claro (Ice Pearl & Snow)
  static const Color light = Color(0xFFF6F8FC);          // Ice Pearl
  static const Color lightCard = Color(0xFFFFFFFF);      // White Pure
  static const Color lightSecondary = Color(0xFFECEEF6); // Soft Cloud
  static const Color lightCardHighlight = Color(0xFFE2E6F2);

  // 🚨 Estados y Alertas
  static const Color danger = Color(0xFFFF3366);         // Neon Coral Red
  static const Color warning = Color(0xFFFFB800);        // Amber Gold
  static const Color success = Color(0xFF00F5A0);        // Neon Mint

  // ⚪ Básicos
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}
import 'package:flutter/material.dart';

class CoverStyle {
  final String id;
  final String name;
  final List<Color> gradientColors;
  final IconData icon;
  final String patternType; // 'circle', 'vinyl', 'wave', 'geometric', 'retro'

  const CoverStyle({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.icon,
    required this.patternType,
  });
}

class CoverArtService {
  CoverArtService._internal();
  static final CoverArtService instance = CoverArtService._internal();

  static const List<CoverStyle> styles = [
    CoverStyle(
      id: "cyberpunk",
      name: "Neon Cyberpunk",
      gradientColors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
      icon: Icons.electric_bolt_rounded,
      patternType: "geometric",
    ),
    CoverStyle(
      id: "sunset",
      name: "Sunset Lo-fi",
      gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFF7928CA)],
      icon: Icons.wb_sunny_rounded,
      patternType: "circle",
    ),
    CoverStyle(
      id: "space",
      name: "Deep Space",
      gradientColors: [Color(0xFF000428), Color(0xFF004E92), Color(0xFF1CB5E0)],
      icon: Icons.nights_stay_rounded,
      patternType: "vinyl",
    ),
    CoverStyle(
      id: "obsidian",
      name: "Dark Obsidian",
      gradientColors: [Color(0xFF141414), Color(0xFF232526), Color(0xFF414345)],
      icon: Icons.diamond_rounded,
      patternType: "geometric",
    ),
    CoverStyle(
      id: "pastel",
      name: "Pastel Aurora",
      gradientColors: [Color(0xFFA8EDEA), Color(0xFFFED6E3), Color(0xFFD4FC79)],
      icon: Icons.auto_awesome_rounded,
      patternType: "circle",
    ),
    CoverStyle(
      id: "retro",
      name: "Retro Vinyl 80s",
      gradientColors: [Color(0xFFF857A6), Color(0xFFFF5858), Color(0xFFFFCC00)],
      icon: Icons.album_rounded,
      patternType: "retro",
    ),
    CoverStyle(
      id: "emerald",
      name: "Emerald Acoustic",
      gradientColors: [Color(0xFF0BA360), Color(0xFF3CBA92), Color(0xFF30E8BF)],
      icon: Icons.eco_rounded,
      patternType: "wave",
    ),
  ];
}

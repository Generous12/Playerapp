import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/musicservice.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = [
      _TabInfo(icon: LucideIcons.music, activeIcon: LucideIcons.music, label: "Biblioteca", index: 0),
      _TabInfo(icon: LucideIcons.folder, activeIcon: LucideIcons.folderOpen, label: "Carpetas", index: 1),
      _TabInfo(icon: LucideIcons.disc, activeIcon: LucideIcons.disc, label: "Reproductor", index: 2, isCenter: true),
      _TabInfo(icon: LucideIcons.heart, activeIcon: LucideIcons.heartHandshake, label: "Favoritos", index: 3),
      _TabInfo(icon: LucideIcons.slidersHorizontal, activeIcon: LucideIcons.slidersHorizontal, label: "Ajustes", index: 4),
    ];

    return SafeArea(
      bottom: true,
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10131E).withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              if (isDark)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: tabs.map((tab) {
                  return _buildNavItem(context, tab, isDark);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _TabInfo tab, bool isDark) {
    final isSelected = currentIndex == tab.index;

    if (tab.isCenter) {
      return AnimatedBuilder(
        animation: MusicService.instance,
        builder: (context, _) {
          final isPlaying = MusicService.instance.isPlaying;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(tab.index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: isSelected ? 52 : 48,
              height: isSelected ? 52 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [AppColors.primary, AppColors.accent]
                      : isDark
                          ? [const Color(0xFF1E2436), const Color(0xFF141926)]
                          : [const Color(0xFFE0F7FE), const Color(0xFFE6FCF5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : Colors.transparent,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: isPlaying ? 1.0 : 0.0,
                  duration: const Duration(seconds: 4),
                  child: Icon(
                    isPlaying ? Icons.graphic_eq_rounded : LucideIcons.disc,
                    color: isSelected
                        ? const Color(0xFF08090D)
                        : isDark
                            ? AppColors.primaryLight
                            : AppColors.primaryDark,
                    size: isSelected ? 24 : 22,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(tab.index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? tab.activeIcon : tab.icon,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 4 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final bool isCenter;

  _TabInfo({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    this.isCenter = false,
  });
}
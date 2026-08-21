import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class ImportandoOverlay extends StatefulWidget {
  const ImportandoOverlay({super.key});

  @override
  State<ImportandoOverlay> createState() => _ImportandoOverlayState();
}

class _ImportandoOverlayState extends State<ImportandoOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: AbsorbPointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.35),
            child: Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF11131B).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🌟 Visualizador de ecualizador animado
                    SizedBox(
                      height: 52,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final delay = index * 0.2;
                              final val = ((_animController.value + delay) % 1.0);
                              final height = 12.0 + (32.0 * (1.0 - (val - 0.5).abs() * 2));

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 4,
                                height: height,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    CustomText(
                      text: "Importando canciones",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 6),
                    CustomText(
                      text: "Indexando tu biblioteca...",
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
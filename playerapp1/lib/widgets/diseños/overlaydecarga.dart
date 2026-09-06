import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:playerapp1/colores/appcolors.dart';

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

    return PopScope(
      canPop: false,
      child: Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // Bloquea toques hacia capas inferiores
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.35),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF11131B).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      height: 40,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final delay = index * 0.2;
                              final val = ((_animController.value + delay) % 1.0);
                              final height = 10.0 + (26.0 * (1.0 - (val - 0.5).abs() * 2));

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
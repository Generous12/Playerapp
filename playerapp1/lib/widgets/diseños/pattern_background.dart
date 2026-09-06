import 'package:flutter/material.dart';

class PatternBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final bool enablePattern;

  const PatternBackground({
    super.key,
    required this.child,
    this.opacity = 0.22,
    this.enablePattern = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBgColor = isDark ? const Color(0xFF0C0E15) : const Color(0xFFF4F5F9);
    final assetPath = isDark ? 'images/pattern_doodle_dark.jpg' : 'images/pattern_doodle_light.jpg';

    if (!enablePattern) {
      return Container(
        color: baseBgColor,
        child: child,
      );
    }

    return Stack(
      children: [
        // 1. Color base
        Positioned.fill(
          child: Container(color: baseBgColor),
        ),

        // 2. Patrón de formas (Doodle / Keith Haring / Memphis)
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? opacity : (opacity * 0.75),
            child: Image.asset(
              assetPath,
              repeat: ImageRepeat.repeat,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ),

        // 3. Degradado suave para asegurar lectura clara de textos y tarjetas
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.50),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.55),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 4. Contenido de la pantalla
        Positioned.fill(child: child),
      ],
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:playerapp1/services/theme_provider.dart';
import 'package:provider/provider.dart';

class ThemeReveal extends StatefulWidget {
  final Widget child;

  const ThemeReveal({super.key, required this.child});

  static ThemeRevealState? of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeRevealState>();
  }

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal> with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  ui.Image? _oldThemeImage;
  Offset _center = Offset.zero;
  double _maxRadius = 0.0;
  Color _accentColor = Colors.transparent;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _oldThemeImage?.dispose();
    super.dispose();
  }

  Future<void> changeTheme(ThemeMode targetMode, {Offset? tapOffset}) async {
    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.themeMode == targetMode || _isAnimating) return;

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final center = tapOffset ?? Offset(size.width / 2, size.height / 2);
    final accent = themeProvider.palette.primary;
    final maxDist = _calculateMaxRadius(center, size);

    // 1. Capturar pantalla antes de cambiar el tema (optimizado a pixelRatio 1.2 para rendimiento instantáneo a 60/120fps)
    ui.Image? snapshot;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final captureRatio = math.min(mediaQuery.devicePixelRatio, 1.2);
        snapshot = await boundary.toImage(pixelRatio: captureRatio);
      }
    } catch (_) {}

    _oldThemeImage?.dispose();

    if (!mounted) {
      snapshot?.dispose();
      return;
    }

    // 2. Colocar la captura fija del tema anterior en pantalla
    setState(() {
      _oldThemeImage = snapshot;
      _center = center;
      _maxRadius = maxDist;
      _accentColor = accent;
      _isAnimating = true;
    });

    _controller.reset();

    // 3. Ahora que la captura está protegiendo la pantalla, cambiar el tema real debajo
    themeProvider.setTheme(targetMode);

    // 4. Iniciar la expansión de la gota de agua
    try {
      await _controller.forward();
    } finally {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
      _oldThemeImage?.dispose();
      _oldThemeImage = null;
    }
  }

  double _calculateMaxRadius(Offset center, Size size) {
    final d1 = (center - const Offset(0, 0)).distance;
    final d2 = (center - Offset(size.width, 0)).distance;
    final d3 = (center - Offset(0, size.height)).distance;
    final d4 = (center - Offset(size.width, size.height)).distance;
    return math.max(math.max(d1, d2), math.max(d3, d4)) + 30.0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Árbol de widgets en vivo renderizando los nuevos componentes y colores
        RepaintBoundary(
          key: _boundaryKey,
          child: widget.child,
        ),

        // Máscara circular con onda de agua revelando los componentes reales
        if (_isAnimating && _oldThemeImage != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = Curves.easeInOutCubic.transform(_controller.value);
                  final currentRadius = progress * _maxRadius;

                  return CustomPaint(
                    painter: _CircularRevealWithWaterRipplePainter(
                      oldImage: _oldThemeImage!,
                      center: _center,
                      radius: currentRadius,
                      accentColor: _accentColor,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CircularRevealWithWaterRipplePainter extends CustomPainter {
  final ui.Image oldImage;
  final Offset center;
  final double radius;
  final Color accentColor;
  final double progress;

  _CircularRevealWithWaterRipplePainter({
    required this.oldImage,
    required this.center,
    required this.radius,
    required this.accentColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Recortar la imagen del tema anterior:
    // El círculo en expansión es un agujero transparente por donde se revela el nuevo tema debajo.
    // Fuera del círculo se dibuja la imagen del tema anterior, por lo que los cards no cambian hasta que la onda los toque.
    final clipPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.clipPath(clipPath);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: oldImage,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
    );

    canvas.restore();

    // Efecto estético de anillo de agua luminiscente y refracción en el borde
    if (radius > 2.0 && progress < 0.99) {
      final ringAlpha = (1.0 - progress * 0.8).clamp(0.0, 1.0);

      // Anillo principal de la gota de agua
      final borderPaint = Paint()
        ..color = accentColor.withValues(alpha: (0.90 * ringAlpha).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.5 * (1.0 - progress)).clamp(1.5, 4.0);
      canvas.drawCircle(center, radius, borderPaint);

      // Onda concéntrica exterior 1
      final wave1Radius = radius + (18.0 * (1.0 - progress));
      final wave1Paint = Paint()
        ..color = accentColor.withValues(alpha: (0.45 * ringAlpha).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.0 * (1.0 - progress)).clamp(1.0, 2.5);
      canvas.drawCircle(center, wave1Radius, wave1Paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularRevealWithWaterRipplePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.progress != progress;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';

/// 💿 Disco de Vinilo animado que gira al reproducir y se frena suavemente al pausar
class VinylRecordDisk extends StatefulWidget {
  final Widget? child;
  final bool isPlaying;
  final double size;
  final VoidCallback? onLongPress;

  const VinylRecordDisk({
    super.key,
    this.child,
    required this.isPlaying,
    this.size = 220,
    this.onLongPress,
  });

  @override
  State<VinylRecordDisk> createState() => _VinylRecordDiskState();
}

class _VinylRecordDiskState extends State<VinylRecordDisk> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _tonearmController;
  late final Animation<double> _tonearmAnimation;

  @override
  void initState() {
    super.initState();
    // Controlador de rotación continua del vinilo (33 RPM aprox)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // Controlador del brazo del tocadiscos (Tonearm)
    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _tonearmAnimation = Tween<double>(begin: -0.38, end: 0.0).animate(
      CurvedAnimation(parent: _tonearmController, curve: Curves.easeInOutCubic),
    );

    if (widget.isPlaying) {
      _spinController.repeat();
      _tonearmController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant VinylRecordDisk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _spinController.repeat();
        _tonearmController.forward();
      } else {
        _spinController.stop(); // Frena en el ángulo exacto sin saltos
        _tonearmController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diskSize = widget.size;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: diskSize + 30,
        height: diskSize + 30,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 🌌 Resplandor / Aura ambiental reactiva al reproducir
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: diskSize,
              height: diskSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: widget.isPlaying ? (isDark ? 0.35 : 0.22) : 0.08,
                    ),
                    blurRadius: widget.isPlaying ? 36 : 14,
                    spreadRadius: widget.isPlaying ? 4 : 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: widget.isPlaying ? (isDark ? 0.20 : 0.12) : 0.04,
                    ),
                    blurRadius: widget.isPlaying ? 48 : 20,
                  ),
                ],
              ),
            ),

            // 💿 Disco de Vinilo Giratorio
            AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: Container(
                width: diskSize,
                height: diskSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pintura personalizada de los surcos y reflejos tornasolados
                    CustomPaint(
                      size: Size(diskSize, diskSize),
                      painter: _VinylRecordPainter(isDark: isDark),
                    ),

                    // 🎨 Galleta / Carátula Central del Disco
                    Container(
                      width: diskSize * 0.38,
                      height: diskSize * 0.38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.accent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: widget.child ??
                            const Icon(
                              LucideIcons.music,
                              size: 28,
                              color: Color(0xFF08090D),
                            ),
                      ),
                    ),

                    // 🕳 Orificio Central del Eje (Spindle Hole)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF07080C),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🪡 Brazo de Tocadiscos (Tonearm) elegante en la esquina superior derecha
            Positioned(
              top: -8,
              right: 4,
              child: AnimatedBuilder(
                animation: _tonearmAnimation,
                builder: (context, _) {
                  return Transform.rotate(
                    angle: _tonearmAnimation.value,
                    alignment: Alignment.topRight,
                    child: _buildTonearm(isDark),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTonearm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Base / Pivote del brazo
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFE5E7EB), Color(0xFF4B5563), Color(0xFF1F2937)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ),
        // Brazo metálico curvo
        Container(
          margin: const EdgeInsets.only(right: 9),
          width: 3.2,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF), Color(0xFF6B7280)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(1, 2),
              ),
            ],
          ),
        ),
        // Cápsula / Aguja fonocaptora
        Transform.rotate(
          angle: 0.25,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            width: 9,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter de precisión para el disco de vinilo con surcos microscópicos y brillo especular
class _VinylRecordPainter extends CustomPainter {
  final bool isDark;

  _VinylRecordPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Cuerpo principal negro vinilo azabache
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF222533),
                const Color(0xFF11131C),
                const Color(0xFF07080C),
              ]
            : [
                const Color(0xFF33384C),
                const Color(0xFF1A1C28),
                const Color(0xFF0A0B10),
              ],
        stops: const [0.15, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Surcos acústicos concéntricos finos (Grooves)
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    for (double r = radius * 0.42; r < radius - 4; r += 3.8) {
      final isMajor = ((r * 10).toInt() % 19 == 0);
      groovePaint.color = Colors.white.withValues(alpha: isMajor ? 0.20 : 0.065);
      canvas.drawCircle(center, r, groovePaint);
    }

    // 3. Brillo especular y reflejo de luz radial en forma de mariposa (Anisotropic Sheen)
    final reflectionPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.16 : 0.22),
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.08 : 0.12),
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.16 : 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.35, 0.50, 0.72, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 1, reflectionPaint);

    // 4. Borde exterior biselado
    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFF374151) : const Color(0xFF4B5563)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius - 1, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylRecordPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Alias para mantener compatibilidad total con código existente
typedef MusicVisualizerRing = VinylRecordDisk;

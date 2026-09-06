import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/coverartservice.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class AICoverArtWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final CoverStyle style;
  final double size;

  const AICoverArtWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.style,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.12),
        gradient: LinearGradient(
          colors: style.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: style.gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.12),
        child: Stack(
          children: [
            // Patrón geométrico de fondo
            Positioned.fill(
              child: CustomPaint(
                painter: _CoverPatternPainter(
                  patternType: style.patternType,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Icono / Símbolo central
            Center(
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  style.icon,
                  size: size * 0.18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),

            // Tipografía de título
            Positioned(
              left: size * 0.08,
              right: size * 0.08,
              bottom: size * 0.08,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size * 0.08,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: size * 0.055,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  final String patternType;
  final Color color;

  _CoverPatternPainter({required this.patternType, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);

    if (patternType == "vinyl" || patternType == "circle") {
      for (double r = 20; r < size.width; r += 24) {
        canvas.drawCircle(center, r, paint);
      }
    } else if (patternType == "geometric") {
      for (double i = 0; i < size.width; i += 30) {
        canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
        canvas.drawLine(Offset(size.width, i), Offset(i, size.height), paint);
      }
    } else {
      final path = Path();
      for (double y = 20; y < size.height; y += 40) {
        path.moveTo(0, y);
        path.quadraticBezierTo(size.width * 0.5, y + 25, size.width, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AICoverGeneratorModal extends StatefulWidget {
  final String initialTitle;
  final Function(CoverStyle selectedStyle)? onStyleSelected;

  const AICoverGeneratorModal({
    super.key,
    required this.initialTitle,
    this.onStyleSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialTitle,
    Function(CoverStyle)? onStyleSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AICoverGeneratorModal(
        initialTitle: initialTitle,
        onStyleSelected: onStyleSelected,
      ),
    );
  }

  @override
  State<AICoverGeneratorModal> createState() => _AICoverGeneratorModalState();
}

class _AICoverGeneratorModalState extends State<AICoverGeneratorModal> {
  int _selectedStyleIndex = 0;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentStyle = CoverArtService.styles[_selectedStyleIndex];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11131B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.sparkles, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  CustomText(
                    text: "Generador de Carátulas IA",
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Preview Canvas Central
          AICoverArtWidget(
            title: _titleController.text.isNotEmpty ? _titleController.text : "MI PLAYLIST",
            subtitle: "VibePlus AI Edition",
            style: currentStyle,
            size: 190,
          ),

          const SizedBox(height: 16),

          // Selector de Estilos
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CoverArtService.styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final st = CoverArtService.styles[i];
                final isSelected = (_selectedStyleIndex == i);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _selectedStyleIndex = i;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF1E2232) : const Color(0xFFF1F4F9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      st.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? const Color(0xFF08090D) : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Botón de Aplicar Carátula
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF08090D),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text(
                "Guardar Carátula Generada",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                widget.onStyleSelected?.call(currentStyle);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

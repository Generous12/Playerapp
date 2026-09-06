import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/sleeptimerservice.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class SleepTimerModal {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _SleepTimerBottomSheet(),
    );
  }
}

class _SleepTimerBottomSheet extends StatefulWidget {
  const _SleepTimerBottomSheet();

  @override
  State<_SleepTimerBottomSheet> createState() => _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState extends State<_SleepTimerBottomSheet> {
  double _customMinutes = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sleepTimer = SleepTimerService.instance;

    return AnimatedBuilder(
      animation: sleepTimer,
      builder: (context, _) {
        final isActive = sleepTimer.isActive;
        final maxHeight = MediaQuery.of(context).size.height * 0.85;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141627) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastre superior
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cabecera
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1),
                              const Color(0xFFA855F7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.moon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              text: "Temporizador de Sueño",
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            CustomText(
                              text: "Fade out progresivo en los últimos segundos",
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6366F1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "ACTIVO",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Si está activo: Card con Cuenta Regresiva
                  if (isActive) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B1E34)
                            : const Color(0xFFF1F4FA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "MÚSICA SE PAUSARÁ EN",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        sleepTimer.formattedRemainingTime,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón +5 min
                                  IconButton.filledTonal(
                                    tooltip: "Añadir 5 min",
                                    onPressed: () => sleepTimer.addMinutes(5),
                                    icon: const Icon(LucideIcons.plus, size: 16),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(
                                        0xFF6366F1,
                                      ).withValues(alpha: 0.15),
                                      foregroundColor: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Botón Cancelar
                                  IconButton.filledTonal(
                                    tooltip: "Cancelar temporizador",
                                    onPressed: () => sleepTimer.cancelTimer(),
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.danger.withValues(
                                        alpha: 0.15,
                                      ),
                                      foregroundColor: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: sleepTimer.progress,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.black12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          if (sleepTimer.isFadingOut) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.volumeX,
                                  size: 13,
                                  color: Color(0xFFA855F7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Desvaneciendo volumen suavemente...",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFA855F7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

              // Opciones Rápidas de Minutos
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "TIEMPO PREDETERMINADO",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildOptionChip(context, "10 min", 10, isDark),
                  _buildOptionChip(context, "15 min", 15, isDark),
                  _buildOptionChip(context, "30 min", 30, isDark),
                  _buildOptionChip(context, "45 min", 45, isDark),
                  _buildOptionChip(context, "60 min", 60, isDark),
                  _buildOptionChip(context, "90 min", 90, isDark),
                ],
              ),

              const SizedBox(height: 16),

              // Botón Fin de la Canción
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B1E34)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sleepTimer.isEndOfSongMode
                        ? const Color(0xFF6366F1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05)),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.music,
                      color: Color(0xFF6366F1),
                      size: 18,
                    ),
                  ),
                  title: CustomText(
                    text: "Al terminar la canción actual",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  subtitle: CustomText(
                    text:
                        "Pausar exactamente cuando termine la pista en reproducción",
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    sleepTimer.startEndOfSongTimer();
                    Navigator.pop(context);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Tiempo personalizado con Slider
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B1E34)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.timer,
                              size: 16,
                              color: Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Tiempo Personalizado",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${_customMinutes.toInt()} min",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF6366F1),
                        inactiveTrackColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        thumbColor: const Color(0xFF6366F1),
                      ),
                      child: Slider(
                        value: _customMinutes,
                        min: 5,
                        max: 120,
                        divisions: 23,
                        onChanged: (val) {
                          setState(() {
                            _customMinutes = val;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          sleepTimer.startTimer(_customMinutes.toInt());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Temporizador fijado en ${_customMinutes.toInt()} minutos.",
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Text(
                          "Iniciar (${_customMinutes.toInt()} min)",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}

  Widget _buildOptionChip(
    BuildContext context,
    String title,
    int minutes,
    bool isDark,
  ) {
    return ActionChip(
      label: Text(title),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      backgroundColor: isDark
          ? const Color(0xFF1B1E34)
          : const Color(0xFFF1F4FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      onPressed: () {
        SleepTimerService.instance.startTimer(minutes);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Temporizador de sueño fijado en $title."),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

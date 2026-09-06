import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/equalizerservice.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/services/theme_provider.dart';
import 'package:playerapp1/widgets/diseños/pattern_background.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final equalizer = EqualizerService.instance;
    final musicService = MusicService.instance;

    return PatternBackground(
      child: AnimatedBuilder(
        animation: Listenable.merge([equalizer, musicService]),
        builder: (context, _) {
          final isEnabled = equalizer.isEnabled;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 4,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141727) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.chevronLeft,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 19,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "ECUALIZADOR",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "DSP 10-BAND",
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? const Color(0xFF00FF9D)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: isEnabled
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00FF9D,
                                      ).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isEnabled ? "PROCESAMIENTO ACTIVO" : "DESACTIVADO",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: isEnabled
                                ? (isDark
                                      ? const Color(0xFF00FF9D)
                                      : const Color(0xFF059669))
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                // Botón Restablecer
                IconButton(
                  tooltip: "Restablecer a Plano",
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141727) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.rotateCcw,
                      size: 15,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  onPressed: () {
                    equalizer.reset();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Ecualizador restablecido a Plano (Flat)",
                        ),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                // Master Power Toggle
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 2),
                  child: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(
                        alpha: 0.4,
                      ),
                      inactiveThumbColor: isDark
                          ? Colors.white38
                          : Colors.black38,
                      inactiveTrackColor: isDark
                          ? Colors.white12
                          : Colors.black12,
                      onChanged: (_) => equalizer.toggleEnabled(),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Curva Espectral HD con Estilo Neón Urbano
                        _buildFrequencyCurveCard(equalizer, isDark, isEnabled),

                        const SizedBox(height: 16),

                        // 2. Control Maestro de Ganancia (Preamp)
                        _buildPreampCard(equalizer, isDark, isEnabled),

                        const SizedBox(height: 18),

                        // 3. Selector de Presets Urbanos y Profesionales
                        _buildSectionHeader(
                          "PRESETS URBANOS & PRO",
                          LucideIcons.disc,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildPresetsHorizontalList(
                          equalizer,
                          isDark,
                          isEnabled,
                        ),

                        const SizedBox(height: 20),

                        // 4. 10 Bandas HD Espectro Completo
                        _buildSectionHeader(
                          "ESPECTRO 10 BANDAS",
                          LucideIcons.slidersHorizontal,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildBandsFadersCard(equalizer, isDark, isEnabled),

                        const SizedBox(height: 20),

                        // 5. Procesadores DSP Urbanos (Sub Bass 808, 3D Spatial, Cristal HD, Dynamic Punch)
                        _buildSectionHeader(
                          "PROCESADORES DSP URBANOS",
                          LucideIcons.sparkles,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildDspProcessorsGrid(equalizer, isDark, isEnabled),

                        const SizedBox(height: 20),

                        // 6. Entorno & Espacialidad (Reverb)
                        _buildSectionHeader(
                          "ESPACIALIDAD & REVERB",
                          LucideIcons.building2,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildReverbSection(equalizer, isDark, isEnabled),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

                  // Si el ecualizador está apagado, banner informativo sutil superior
                  if (!isEnabled)
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? const Color(0xFF181B2C) : Colors.white)
                                  .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.powerOff,
                              size: 18,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Ecualizador apagado. Actívalo para aplicar efectos.",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => equalizer.toggleEnabled(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "ACTIVAR",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ENCABEZADO DE SECCIÓN MINIMALISTA URBANO
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isDark
                ? Colors.white.withValues(alpha: 0.85)
                : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. CURVA ESPECTRAL HD (RESPUESTA DE FRECUENCIA)
  // ---------------------------------------------------------------------------
  Widget _buildFrequencyCurveCard(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    final gains = equalizer.bandGains;
    final preamp = equalizer.preampGain;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111422) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.05)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.activity,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "CURVA DE RESPUESTA ACÚSTICA",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1D30)
                      : const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  equalizer.currentPreset.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _UrbanSpectrumPainter(
                  gains: gains,
                  preamp: preamp,
                  isEnabled: isEnabled,
                  isDark: isDark,
                  primaryColor: AppColors.primary,
                  accentColor: AppColors.accent,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PREAMP MASTER & AUTO LIMITER
  // ---------------------------------------------------------------------------
  Widget _buildPreampCard(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    final preamp = equalizer.preampGain;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111422) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.gauge, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "PREAMP MASTER",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "${preamp >= 0 ? '+' : ''}${preamp.toStringAsFixed(1)} dB",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: isDark
                        ? Colors.white10
                        : Colors.black12,
                    thumbColor: AppColors.accent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: preamp,
                    min: -12.0,
                    max: 12.0,
                    onChanged: isEnabled
                        ? (val) => equalizer.setPreampGain(val)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. LISTA HORIZONTAL DE PRESETS URBANOS & PRO
  // ---------------------------------------------------------------------------
  Widget _buildPresetsHorizontalList(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: EqualizerService.presets.length,
        itemBuilder: (context, index) {
          final p = EqualizerService.presets[index];
          final isSelected = equalizer.currentPreset == p.name;

          return Padding(
            padding: EdgeInsets.only(right: 8, left: index == 0 ? 0 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF141727) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isEnabled
                      ? () {
                          equalizer.setPreset(p.name);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. 10 BANDAS DE FRECUENCIA HD (VERTICAL FADERS)
  // ---------------------------------------------------------------------------
  Widget _buildBandsFadersCard(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    final gains = equalizer.bandGains;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111422) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                final gain = gains[index];
                final label = EqualizerService.bandLabels[index];

                return _buildSingleBandFader(
                  index: index,
                  gain: gain,
                  label: label,
                  equalizer: equalizer,
                  isDark: isDark,
                  isEnabled: isEnabled,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBandFader({
    required int index,
    required double gain,
    required String label,
    required EqualizerService equalizer,
    required bool isDark,
    required bool isEnabled,
  }) {
    return Column(
      children: [
        // dB Label
        GestureDetector(
          onDoubleTap: isEnabled
              ? () => equalizer.setBandGain(index, 0.0)
              : null,
          child: Text(
            "${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: gain.abs() > 0.5
                  ? AppColors.primary
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Vertical Slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                thumbColor: AppColors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: gain,
                min: -12.0,
                max: 12.0,
                onChanged: isEnabled
                    ? (val) => equalizer.setBandGain(index, val)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Freq Label
        Text(
          label.replaceAll(" Hz", "H").replaceAll(" kHz", "k"),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. PROCESADORES DSP URBANOS (4 CARDS)
  // ---------------------------------------------------------------------------
  Widget _buildDspProcessorsGrid(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _buildDspCard(
          title: "SUB BASS 808",
          subtitle: "Pegada sub-grave profunda",
          icon: LucideIcons.speaker,
          value: equalizer.bassBoost,
          color: const Color(0xFFFF5252),
          isDark: isDark,
          isEnabled: isEnabled,
          onChanged: (val) => equalizer.setBassBoost(val),
        ),
        _buildDspCard(
          title: "SPATIAL 3D",
          subtitle: "Inmersión y surround",
          icon: LucideIcons.radio,
          value: equalizer.virtualizer,
          color: const Color(0xFF00F0FF),
          isDark: isDark,
          isEnabled: isEnabled,
          onChanged: (val) => equalizer.setVirtualizer(val),
        ),
        _buildDspCard(
          title: "CRISTAL HD",
          subtitle: "Brillo & armónicos",
          icon: LucideIcons.gem,
          value: equalizer.crystalEffect,
          color: const Color(0xFFB388FF),
          isDark: isDark,
          isEnabled: isEnabled,
          onChanged: (val) => equalizer.setCrystalEffect(val),
        ),
        _buildDspCard(
          title: "Punch",
          subtitle: "Limiter & transient 808",
          icon: LucideIcons.zap,
          value: equalizer.dynamicPunch,
          color: const Color(0xFFFF9100),
          isDark: isDark,
          isEnabled: isEnabled,
          onChanged: (val) => equalizer.setDynamicPunch(val),
        ),
      ],
    );
  }

  Widget _buildDspCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required Color color,
    required bool isDark,
    required bool isEnabled,
    required ValueChanged<double> onChanged,
  }) {
    final pct = (value * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111422) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                "$pct%",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.5,
              activeTrackColor: color,
              inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: isEnabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. ESPACIALIDAD & REVERB
  // ---------------------------------------------------------------------------
  Widget _buildReverbSection(
    EqualizerService equalizer,
    bool isDark,
    bool isEnabled,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111422) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EqualizerService.reverbPresets.map((r) {
              final isSel = equalizer.currentReverbId == r.id;
              return ChoiceChip(
                label: Text(r.name),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  color: isSel
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                selected: isSel,
                selectedColor: AppColors.accent,
                backgroundColor: isDark
                    ? const Color(0xFF191D30)
                    : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: isEnabled
                    ? (_) => equalizer.setReverbPreset(r.id)
                    : null,
              );
            }).toList(),
          ),
          if (equalizer.currentReverbId != "off") ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  "Nivel de Mezcla Reverb:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Text(
                  "${(equalizer.reverbLevel * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                thumbColor: AppColors.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: equalizer.reverbLevel,
                min: 0.0,
                max: 1.0,
                onChanged: isEnabled
                    ? (val) => equalizer.setReverbLevel(val)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAINTER DE LA CURVA ESPECTRAL CON ESTILO NEÓN
// ---------------------------------------------------------------------------
class _UrbanSpectrumPainter extends CustomPainter {
  final List<double> gains;
  final double preamp;
  final bool isEnabled;
  final bool isDark;
  final Color primaryColor;
  final Color accentColor;

  _UrbanSpectrumPainter({
    required this.gains,
    required this.preamp,
    required this.isEnabled,
    required this.isDark,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Líneas de referencia de dB
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), gridPaint);
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), gridPaint);

    if (gains.isEmpty) return;

    final n = gains.length;
    final points = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      final effectiveGain = isEnabled
          ? (gains[i] + preamp).clamp(-12.0, 12.0)
          : 0.0;
      // Normalizar [-12dB, +12dB] -> [h, 0]
      final y = midY - (effectiveGain / 12.0) * (h * 0.42);
      points.add(Offset(x, y));
    }

    // Curva suave Bezier
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Relleno degradado bajo la curva
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isEnabled
          ? [
              primaryColor.withValues(alpha: isDark ? 0.35 : 0.2),
              accentColor.withValues(alpha: isDark ? 0.15 : 0.05),
              Colors.transparent,
            ]
          : [Colors.grey.withValues(alpha: 0.1), Colors.transparent],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Línea de trazo brillante
    final strokePaint = Paint()
      ..color = isEnabled
          ? primaryColor
          : (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Dibujar nodos circulares con brillo
    for (final pt in points) {
      if (isEnabled) {
        final glowPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(pt, 5, glowPaint);
      }

      final dotPaint = Paint()
        ..color = isEnabled
            ? primaryColor
            : (isDark ? Colors.white54 : Colors.black45)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 3, dotPaint);

      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 1.2, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UrbanSpectrumPainter oldDelegate) {
    return oldDelegate.gains != gains ||
        oldDelegate.preamp != preamp ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.isDark != isDark;
  }
}

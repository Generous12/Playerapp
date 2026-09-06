import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/historial.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/crossfadeservice.dart';
import 'package:playerapp1/services/equalizerservice.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/services/permissioservice.dart';
import 'package:playerapp1/services/sleeptimerservice.dart';
import 'package:playerapp1/services/theme_provider.dart';
import 'package:playerapp1/vista/equalizer_screen.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/sleeptimer_dialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';
import 'package:playerapp1/widgets/diseños/theme_reveal.dart';
import 'package:provider/provider.dart';

//En favoritos ,no me gusta tener grande el container q dice Mis Favoritos, igual que en la pantalla detalle carpeta
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String audioQuality = "Alta (320 kbps)";
  double defaultVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            /// 🔝 CABECERA INTEGRADA
            CustomText(
              text: "Configuración",
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            CustomText(
              text: "Personaliza tu experiencia de reproducción.",
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),

            /// 🎨 APARIENCIA
            _sectionTitle("Apariencia"),
            Builder(
              builder: (tileContext) {
                final currentMode = themeProvider.themeMode;
                String currentText = "Tema del sistema";
                if (currentMode == ThemeMode.dark) currentText = "Modo oscuro";
                if (currentMode == ThemeMode.light) currentText = "Modo claro";

                IconData currentIcon = LucideIcons.laptop;
                if (currentMode == ThemeMode.dark) currentIcon = LucideIcons.moon;
                if (currentMode == ThemeMode.light) currentIcon = LucideIcons.sun;

                return _card(
                  isDark: isDark,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    initiallyExpanded: true,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentIcon,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: CustomText(
                      text: "Tema de la aplicación",
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    subtitle: CustomText(
                      text: currentText,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          children: [
                            _themeOptionChip(
                              context: tileContext,
                              title: "Sistema",
                              icon: LucideIcons.laptop,
                              mode: ThemeMode.system,
                              isSelected: currentMode == ThemeMode.system,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _themeOptionChip(
                              context: tileContext,
                              title: "Oscuro",
                              icon: LucideIcons.moon,
                              mode: ThemeMode.dark,
                              isSelected: currentMode == ThemeMode.dark,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _themeOptionChip(
                              context: tileContext,
                              title: "Claro",
                              icon: LucideIcons.sun,
                              mode: ThemeMode.light,
                              isSelected: currentMode == ThemeMode.light,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _card(
              isDark: isDark,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.palette,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: CustomText(
                  text: "Color de tema de la app",
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                subtitle: CustomText(
                  text: themeProvider.palette.name,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _mostrarSelectorPaleta(context),
              ),
            ),

            const SizedBox(height: 24),

            /// 🎵 AUDIO Y REPRODUCCIÓN
            _sectionTitle("Audio y Reproducción"),
            AnimatedBuilder(
              animation: EqualizerService.instance,
              builder: (context, _) {
                final eq = EqualizerService.instance;
                return _settingTile(
                  icon: LucideIcons.sliders,
                  title: "Ecualizador DSP Pro",
                  subtitle: eq.isEnabled
                      ? "Activo • ${eq.currentPreset}"
                      : "Desactivado (Bypass)",
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EqualizerScreen(),
                      ),
                    );
                  },
                );
              },
            ),
            AnimatedBuilder(
              animation: SleepTimerService.instance,
              builder: (context, _) {
                final timer = SleepTimerService.instance;
                return _settingTile(
                  icon: LucideIcons.moon,
                  title: "Temporizador de sueño",
                  subtitle: timer.isActive
                      ? "Música se pausará en ${timer.formattedRemainingTime} (Fade out)"
                      : "Desactivado",
                  isDark: isDark,
                  onTap: () => SleepTimerModal.show(context),
                );
              },
            ),
            AnimatedBuilder(
              animation: CrossfadeService.instance,
              builder: (context, _) {
                final cf = CrossfadeService.instance;
                return _settingTile(
                  icon: LucideIcons.blend,
                  title: "Crossfade inteligente",
                  subtitle: cf.isEnabled
                      ? "${cf.crossfadeSeconds} segundos de transición suave"
                      : "Desactivado",
                  isDark: isDark,
                  onTap: () => _mostrarCrossfadeSelector(context),
                );
              },
            ),
            _settingTile(
              icon: LucideIcons.music4,
              title: "Calidad de audio",
              subtitle: audioQuality,
              isDark: isDark,
              onTap: () => _mostrarCalidadAudio(context),
            ),
            _settingTile(
              icon: LucideIcons.volume2,
              title: "Volumen de reproducción",
              subtitle: "${(defaultVolume * 100).toInt()}%",
              isDark: isDark,
              onTap: () => _mostrarAjusteVolumen(context),
            ),
            _settingTile(
              icon: LucideIcons.history,
              title: "Historial de reproducción",
              subtitle: "Ver o limpiar canciones recientes",
              isDark: isDark,
              onTap: () => _mostrarHistorial(context),
            ),

            const SizedBox(height: 24),

            /// 📁 BIBLIOTECA Y DATOS
            _sectionTitle("Biblioteca y Datos"),
            _settingTile(
              icon: LucideIcons.hardDrive,
              title: "Almacenamiento y descargas",
              subtitle: "Ver espacio usado por la biblioteca",
              isDark: isDark,
              onTap: () => _mostrarInfoAlmacenamiento(context),
            ),
            _settingTile(
              icon: LucideIcons.shieldCheck,
              title: "Privacidad y permisos",
              subtitle: "Acceso al almacenamiento y audio",
              isDark: isDark,
              onTap: () => _mostrarPrivacidad(context),
            ),

            const SizedBox(height: 24),

            /// ℹ️ INFORMACIÓN Y SISTEMA
            _sectionTitle("Información y Sistema"),
            _settingTile(
              icon: LucideIcons.info,
              title: "Acerca de VibePlus",
              subtitle: "Versión 1.0.0 (Build 2026)",
              isDark: isDark,
              onTap: () => _mostrarAcercaDe(context),
            ),

            const SizedBox(height: 24),

            /// ⚠️ LIMPIEZA Y CACHÉ
            _card(
              isDark: isDark,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                title: CustomText(
                  text: "Eliminar caché y datos",
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
                subtitle: CustomText(
                  text: "Libera espacio y restablece el historial",
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.danger,
                ),
                onTap: () => _eliminarCache(context),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: CustomText(
        text: text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        isDark: isDark,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: CustomText(
            text: title,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          subtitle: CustomText(
            text: subtitle,
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _themeOptionChip({
    required BuildContext context,
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSelected) return;

          final renderBox = context.findRenderObject() as RenderBox?;
          Offset? offset;
          if (renderBox != null) {
            final size = renderBox.size;
            offset = renderBox.localToGlobal(
              Offset(size.width / 2, size.height / 2),
            );
          }

          final themeReveal = ThemeReveal.of(context);
          if (themeReveal != null) {
            themeReveal.changeTheme(mode, tapOffset: offset);
          } else {
            context.read<ThemeProvider>().setTheme(mode);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? const Color(0xFF1E2132)
                    : const Color(0xFFF1F4F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 4),
              CustomText(
                text: title,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11131B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- MODALES Y ACCIONES ---

  void _mostrarSelectorPaleta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF11131B) : const Color(0xFFFFFFFF);

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomText(
                        text: "Paleta de Colores de la App",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 6),
                      CustomText(
                        text:
                            "Elige el estilo visual principal para toda la aplicación.",
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: AppPalette.all.length,
                          itemBuilder: (context, index) {
                            final palette = AppPalette.all[index];
                            final isSelected =
                                themeProvider.palette.id == palette.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primary.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      )
                                    : (isDark
                                          ? const Color(0xFF181B26)
                                          : const Color(0xFFF3F5FA)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? palette.primary
                                      : (isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              )),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: palette.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: palette.primary.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                title: CustomText(
                                  text: palette.name,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        LucideIcons.check,
                                        color: palette.primary,
                                        size: 18,
                                      )
                                    : null,
                                onTap: () {
                                  themeProvider.setPalette(palette);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarCalidadAudio(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF11131B) : const Color(0xFFFFFFFF);

            final opciones = [
              "Baja (128 kbps)",
              "Media (192 kbps)",
              "Alta (320 kbps) - Recomendado",
              "Lossless (FLAC)",
            ];

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomText(
                        text: "Calidad de Audio",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: opciones.map((opcion) {
                          final isSelected = audioQuality == opcion;
                          return RadioListTile<String>(
                            activeColor: AppColors.primary,
                            title: CustomText(
                              text: opcion,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: theme.colorScheme.onSurface,
                            ),
                            value: opcion,
                            groupValue: audioQuality,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => audioQuality = val);
                                Navigator.pop(ctx);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarAjusteVolumen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF18181E) : const Color(0xFFFFFFFF);

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomText(
                        text: "Volumen de Reproducción",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 8),
                      CustomText(
                        text: "${(defaultVolume * 100).toInt()}%",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        activeColor: AppColors.primary,
                        inactiveColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        value: defaultVolume,
                        onChanged: (val) {
                          setState(() {
                            defaultVolume = val;
                          });
                          MusicService.instance.player.setVolume(val);
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Guardar",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarInfoAlmacenamiento(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF18181E) : const Color(0xFFFFFFFF);

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: FutureBuilder<List<Cancion>>(
                  future: CancionRepository().obtenerTodas(),
                  builder: (context, snapshot) {
                    final canciones = snapshot.data ?? [];
                    double mbTotal = 0;
                    for (final c in canciones) {
                      mbTotal += (c.tamanoArchivo ?? 0) / (1024 * 1024);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomText(
                            text: "Almacenamiento de Música",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  CustomText(
                                    text: "${canciones.length}",
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  CustomText(
                                    text: "Canciones",
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  CustomText(
                                    text: "${mbTotal.toStringAsFixed(1)} MB",
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  CustomText(
                                    text: "Espacio Usado",
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (mbTotal / 1000).clamp(0.05, 1.0),
                              minHeight: 10,
                              backgroundColor: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarHistorial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF11131B) : const Color(0xFFFFFFFF);
            final dao = HistorialDao();

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: dao.getHistorialCompleto(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 250,
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                    }

                    final items = snapshot.data ?? [];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CustomText(
                                text: "Historial reciente",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              if (items.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    final confirm = await CustomDialog.show(
                                      context: context,
                                      title: "Limpiar historial",
                                      message:
                                          "¿Deseas borrar el historial completo de reproducción?",
                                      confirmText: "Limpiar",
                                      cancelText: "Cancelar",
                                    );

                                    if (confirm == true) {
                                      await dao.clearHistorial();
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
                                    }
                                  },
                                  child: CustomText(
                                    text: "Limpiar todo",
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            const SizedBox(
                              height: 180,
                              child: Center(
                                child: CustomText(
                                  text: "No hay canciones reproducidas recientemente.",
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final titulo = item['titulo'] ?? 'Desconocida';
                                  final fecha = DateTime.fromMillisecondsSinceEpoch(
                                    item['fecha_reproduccion'] ?? 0,
                                  );
                                  final fechaStr =
                                      "${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: CustomText(
                                      text: titulo,
                                      overflow: TextOverflow.ellipsis,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    subtitle: CustomText(
                                      text: fechaStr,
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarPrivacidad(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final theme = Theme.of(context);
            final isDark = themeProvider.themeMode == ThemeMode.dark;
            final sheetBg = isDark ? const Color(0xFF18181E) : const Color(0xFFFFFFFF);

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomText(
                        text: "Privacidad y Permisos",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 12),
                      CustomText(
                        text:
                            "VibePlus solicita acceso únicamente al almacenamiento multimedia local para escanear y reproducir tus canciones. Ningún dato es transferido a servidores externos.",
                        textAlign: TextAlign.center,
                        fontSize: 13,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await PermissionService.solicitarPermisosAudio();
                        },
                        icon: const Icon(
                          LucideIcons.shieldCheck,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "Verificar Permisos",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarCrossfadeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final cf = CrossfadeService.instance;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141627) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(LucideIcons.blend, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: "Crossfade Inteligente",
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        CustomText(
                          text: "Transición suave entre pistas sin silencios",
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...CrossfadeService.availableDurations.map((sec) {
                final isSelected = cf.crossfadeSeconds == sec;
                final text = sec == 0 ? "Desactivado (Corte normal)" : "$sec Segundos";

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    onTap: () {
                      cf.setCrossfadeSeconds(sec);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sec == 0
                                ? "Crossfade desactivado."
                                : "Crossfade fijado en $sec segundos.",
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _mostrarAcercaDe(BuildContext context) {
    CustomDialog.show(
      context: context,
      title: "VibePlus Audio",
      message:
          "VibePlus v1.0.0 (Build 2026)\n\nReproductor de música nativo de alto rendimiento desarrollado con Flutter y SQLite. Ofrece visualizadores rítmicos, ordenación inteligente y modo oscuro adaptativo.",
      confirmText: "Entendido",
      showCancelButton: false,
    );
  }

  Future<void> _eliminarCache(BuildContext context) async {
    final confirm = await CustomDialog.show(
      context: context,
      title: "Eliminar Caché",
      message:
          "¿Deseas borrar el historial de reproducción y limpiar los datos temporales de la app?",
      confirmText: "Eliminar",
      cancelText: "Cancelar",
      confirmButtonColor: AppColors.danger,
    );

    if (confirm == true) {
      await HistorialDao().clearHistorial();
    }
  }
}

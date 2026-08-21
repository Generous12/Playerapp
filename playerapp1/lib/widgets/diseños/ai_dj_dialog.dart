import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/djservice.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class AIDJModal extends StatefulWidget {
  final List<Cancion> allSongs;

  const AIDJModal({super.key, required this.allSongs});

  static Future<void> show(BuildContext context, List<Cancion> allSongs) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AIDJModal(allSongs: allSongs),
    );
  }

  @override
  State<AIDJModal> createState() => _AIDJModalState();
}

class _AIDJModalState extends State<AIDJModal> {
  final _djService = DJService.instance;
  final _music = MusicService.instance;
  final TextEditingController _promptController = TextEditingController();

  String _selectedMoodId = "party";
  List<Cancion> _generatedSongs = [];

  @override
  void initState() {
    super.initState();
    _generarMix(_selectedMoodId);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generarMix(String moodOrPrompt) async {
    final result = await _djService.generateMoodMix(
      allSongs: widget.allSongs,
      moodPrompt: moodOrPrompt,
    );

    if (!mounted) return;
    setState(() {
      _generatedSongs = result;
    });
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de arrastre superior (Drag Handle)
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cabecera Principal del DJ IA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      size: 20,
                      color: Color(0xFF08090D),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "DJ Inteligente IA",
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                      Text(
                        "Selección musical por estado de ánimo",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(LucideIcons.x, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Selector de estados de ánimo (Chips horizontales)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: DJService.predefinedMoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, i) {
                final mood = DJService.predefinedMoods[i];
                final isSelected = (_selectedMoodId == mood.id);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _selectedMoodId = mood.id;
                      _promptController.clear();
                    });
                    _generarMix(mood.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF1B1E2C) : const Color(0xFFF0F3FA)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mood.icon,
                          size: 15,
                          color: isSelected
                              ? const Color(0xFF08090D)
                              : (isDark ? AppColors.primary : AppColors.accent),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          mood.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF08090D)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Campo de texto para prompt personalizado
          TextField(
            controller: _promptController,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: "Escribe tu propio mood (ej: 'Pop de carretera')",
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161824) : const Color(0xFFF5F7FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(LucideIcons.search, size: 16, color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: IconButton(
                icon: Icon(
                  LucideIcons.sparkles,
                  size: 17,
                  color: AppColors.accent,
                ),
                onPressed: () {
                  if (_promptController.text.trim().isNotEmpty) {
                    setState(() {
                      _selectedMoodId = "custom";
                    });
                    _generarMix(_promptController.text.trim());
                  }
                },
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                setState(() {
                  _selectedMoodId = "custom";
                });
                _generarMix(val.trim());
              }
            },
          ),

          const SizedBox(height: 16),

          // Título de la sección de canciones generadas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MEZCLA GENERADA POR IA",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white38 : Colors.black45,
                  letterSpacing: 0.8,
                ),
              ),
              if (!_djService.isGenerating && _generatedSongs.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_generatedSongs.length} pistas",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Lista fluida de canciones generadas
          Expanded(
            child: _djService.isGenerating
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.8),
                        const SizedBox(height: 14),
                        Text(
                          "El DJ con IA está analizando tu biblioteca...",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _generatedSongs.isEmpty
                    ? Center(
                        child: Text(
                          "No hay canciones en tu biblioteca que coincidan con este estilo.",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _generatedSongs.length,
                        itemBuilder: (context, index) {
                          final song = _generatedSongs[index];
                          final durStr = _formatDuration(song.duracion);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141724) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              onTap: () async {
                                Navigator.pop(context);
                                await _music.playPlaylist(
                                  _generatedSongs,
                                  index,
                                  context: "ai_dj",
                                );
                              },
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                song.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    song.rutaArchivo.split('.').last.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                  if (durStr.isNotEmpty) ...[
                                    Text(" • ", style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                                    Text(
                                      durStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white38 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.play,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          const SizedBox(height: 14),

          // Botón de acción principal: Reproducir Mix con IA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF08090D),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.35),
              ),
              icon: const Icon(LucideIcons.play, size: 19),
              label: const Text(
                "Reproducir Mix con IA",
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              onPressed: _generatedSongs.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _music.playPlaylist(
                        _generatedSongs,
                        0,
                        context: "ai_dj",
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

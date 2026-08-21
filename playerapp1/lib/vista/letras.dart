import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/lyricsservice.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class LyricsScreen extends StatefulWidget {
  final Cancion song;

  const LyricsScreen({super.key, required this.song});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> with SingleTickerProviderStateMixin {
  final _lyricsService = LyricsService.instance;
  final _music = MusicService.instance;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  late Cancion _currentSong;
  LyricsResult? _lyricsResult;
  List<LyricsResult> _candidateResults = [];
  bool _isLoading = true;
  int _activeLineIndex = -1;
  bool _isKaraokeMode = true;
  double _fontSize = 17.0;
  bool _userIsScrolling = false;
  Timer? _resumeAutoScrollTimer;
  Duration? _dragPosition;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _currentSong = _music.currentSong ?? widget.song;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Escuchar cambios de canción en tiempo real
    _music.currentSongIdNotifier.addListener(_onSongChanged);

    _buscarLetra();
  }

  @override
  void dispose() {
    _music.currentSongIdNotifier.removeListener(_onSongChanged);
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onSongChanged() {
    final newSong = _music.currentSong;
    if (newSong != null && (newSong.id != _currentSong.id || newSong.rutaArchivo != _currentSong.rutaArchivo)) {
      if (!mounted) return;
      setState(() {
        _currentSong = newSong;
      });
      _buscarLetra();
    }
  }

  int _effectiveDuration() {
    final playerDur = _music.player.duration?.inSeconds;
    if (playerDur != null && playerDur > 5) return playerDur;
    if (_currentSong.duracion > 5) return _currentSong.duracion;
    return 180;
  }

  String _cleanDisplayTitle() {
    final meta = _lyricsService.extractMetadata(_currentSong.titulo, null);
    return meta['title'] ?? _currentSong.titulo;
  }

  String _cleanDisplayArtist() {
    final meta = _lyricsService.extractMetadata(_currentSong.titulo, null);
    final artist = meta['artist'] ?? "";
    return artist.isNotEmpty ? artist : "Artista local";
  }

  Future<bool> _verificarInternet() async {
    final online = await _lyricsService.hasInternetConnection();
    if (!online && mounted) {
      await CustomDialog.show(
        context: context,
        title: "Sin conexión a Internet",
        message:
            "No se detecta conexión a Internet. Por favor, conéctate a una red Wi-Fi o datos móviles para buscar o traducir letras con IA en línea.",
        confirmText: "Entendido",
        showCancelButton: false,
        icon: const Icon(LucideIcons.wifiOff, size: 28, color: AppColors.danger),
      );
      return false;
    }
    return true;
  }

  /// Búsqueda autónoma e inteligente: descubre candidatos automáticamente para que el usuario no tenga que escribir
  Future<void> _buscarLetra({String? customQuery}) async {
    if (!mounted) return;

    // ⭐ 0. Si la letra ya fue precargada en segundo plano y no es una búsqueda manual con customQuery, mostrar de inmediato
    if (customQuery == null) {
      final cached = _lyricsService.getCachedResult(_currentSong.titulo, null);
      if (cached != null) {
        setState(() {
          _lyricsResult = cached;
          _isLoading = false;
          _isKaraokeMode = cached.isSynced;
          _lineKeys.clear();
          _activeLineIndex = -1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _lyricsResult != null) {
            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
          }
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _lineKeys.clear();
      _activeLineIndex = -1;
      _candidateResults = [];
      _lyricsResult = null;
    });

    final query = customQuery?.trim().isNotEmpty == true ? customQuery!.trim() : _currentSong.titulo;

    // 1. Obtener candidatos relevantes de múltiples fuentes
    final candidates = await _lyricsService.searchLyricsCandidates(
      query,
      filePath: _currentSong.rutaArchivo,
      durationSeconds: _effectiveDuration(),
    );

    if (!mounted) return;

    // ⚠️ Filtrar estrictamente solo versiones sincronizadas (modo karaoke). Excluir textos planos.
    final syncedCandidates = candidates.where((c) => c.isSynced).toList();

    final meta = _lyricsService.extractMetadata(query, null);
    final cleanTitle = meta['title']!;
    final cleanArtist = meta['artist']!;

    // 2. Comprobar si hay una coincidencia exacta de alta confianza entre las sincronizadas
    LyricsResult? exactMatch;
    if (syncedCandidates.isNotEmpty) {
      final first = syncedCandidates.first;
      if (_lyricsService.isHighConfidenceMatch(first, cleanTitle, cleanArtist)) {
        exactMatch = first;
      }
    }

    if (exactMatch != null) {
      // ✅ Alinear marcas de tiempo a la duración exacta del archivo de audio local
      final alignedLines = _lyricsService.alignLinesToAudioDuration(exactMatch.lines, _effectiveDuration());
      final alignedMatch = exactMatch.copyWith(lines: alignedLines);

      setState(() {
        _lyricsResult = alignedMatch;
        _candidateResults = syncedCandidates;
        _isLoading = false;
        _isKaraokeMode = true;
      });
    } else {
      // ⚠️ NO se encontró la canción exacta: NO mostrar una letra equivocada de primera.
      // Listar en el área central únicamente las versiones sincronizadas para que el usuario elija.
      setState(() {
        _lyricsResult = null;
        _candidateResults = syncedCandidates;
        _isLoading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lyricsResult != null) {
        _syncCurrentPositionWithLyrics(_music.player.position, force: true);
      }
    });
  }

  Future<void> _generarConIA({String? customQuery}) async {
    if (!await _verificarInternet()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lineKeys.clear();
      _activeLineIndex = -1;
    });

    final res = await _lyricsService.generateLyricsWithAI(
      trackName: customQuery?.trim().isNotEmpty == true ? customQuery!.trim() : _currentSong.titulo,
      filePath: _currentSong.rutaArchivo,
      durationSeconds: _effectiveDuration(),
    );

    if (!mounted) return;
    setState(() {
      _lyricsResult = res;
      _isLoading = false;
      _isKaraokeMode = res.isSynced;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncCurrentPositionWithLyrics(_music.player.position, force: true);
      }
    });
  }

  Future<void> _traducirConIA(String langCode) async {
    if (_lyricsResult == null) return;
    if (!await _verificarInternet()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final res = await _lyricsService.translateLyricsWithAI(
      currentResult: _lyricsResult!,
      targetLanguageCode: langCode,
    );

    if (!mounted) return;
    setState(() {
      _lyricsResult = res;
      _isLoading = false;
    });
  }

  void _mostrarMenuTraduccion(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(LucideIcons.languages, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      CustomText(
                        text: "Traducir Letra con IA",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Traducción automática y sincronizada verso a verso:",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 14),
              _langTile(ctx, "Español", "es", "🇪🇸"),
              _langTile(ctx, "English", "en", "🇺🇸"),
              _langTile(ctx, "Português", "pt", "🇧🇷"),
              _langTile(ctx, "Français", "fr", "🇫🇷"),
              _langTile(ctx, "Italiano", "it", "🇮🇹"),
              _langTile(ctx, "Deutsch", "de", "🇩🇪"),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _langTile(BuildContext ctx, String name, String code, String flag) {
    final isCurrent = _lyricsResult?.activeTranslationLang?.toLowerCase().contains(name.toLowerCase()) ?? false;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          color: isCurrent ? AppColors.primary : null,
        ),
      ),
      trailing: isCurrent ? Icon(LucideIcons.check, size: 18, color: AppColors.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        _traducirConIA(code);
      },
    );
  }

  /// Modal interactivo de cambio rápido entre versiones sugeridas sin escribir
  void _mostrarSelectorVersiones(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131522) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(LucideIcons.listMusic, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      CustomText(
                        text: "Versiones Encontradas",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Toca cualquier versión para cambiar de letra al instante:",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _candidateResults.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  itemBuilder: (context, i) {
                    final item = _candidateResults[i];
                    final isCurrent = item.title == _lyricsResult?.title && item.artist == _lyricsResult?.artist;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Icon(
                        item.isSynced ? LucideIcons.micVocal : LucideIcons.alignLeft,
                        color: isCurrent ? AppColors.primary : (item.isSynced ? AppColors.accent : Colors.grey),
                        size: 20,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13.5,
                          color: isCurrent ? AppColors.primary : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.artist.isNotEmpty ? item.artist : "Artista desconocido",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? Icon(LucideIcons.check, color: AppColors.primary, size: 18)
                          : Icon(LucideIcons.chevronRight, color: isDark ? Colors.white24 : Colors.black26, size: 16),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _lyricsResult = item;
                          _isKaraokeMode = item.isSynced;
                          _lineKeys.clear();
                          _activeLineIndex = -1;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Abre un modal minimalista para calibrar el tiempo (offset) de la letra milimétricamente
  void _mostrarAjusteDesfase(BuildContext context) {
    if (_lyricsResult == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131520) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentOffset = _lyricsResult!.timeOffsetMs;
            final offsetSeconds = (currentOffset / 1000.0).toStringAsFixed(1);
            final sign = currentOffset > 0 ? "+" : "";

            void updateOffset(int deltaMs) {
              final newOffset = currentOffset + deltaMs;
              setState(() {
                _lyricsResult!.timeOffsetMs = newOffset;
              });
              setModalState(() {});
              _lyricsService.cacheSelectedResult(_currentSong.titulo, null, _lyricsResult!);
              _syncCurrentPositionWithLyrics(_music.player.position, force: true);
            }

            void resetOffset() {
              setState(() {
                _lyricsResult!.timeOffsetMs = 0;
              });
              setModalState(() {});
              _lyricsService.cacheSelectedResult(_currentSong.titulo, null, _lyricsResult!);
              _syncCurrentPositionWithLyrics(_music.player.position, force: true);
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.timer, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      CustomText(
                        text: "Calibración de Tiempo",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Ajusta si la letra de la canción va muy adelantada o muy retrasada:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Indicador del Desfase Actual
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "Desfase: $sign${offsetSeconds}s (${currentOffset > 0 ? '+' : ''}$currentOffset ms)",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Botones de calibración rápida
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => updateOffset(-300),
                        child: const Text("-0.3s"),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => updateOffset(-100),
                        child: const Text("-0.1s"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: resetOffset,
                        child: const Text("0s"),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => updateOffset(100),
                        child: const Text("+0.1s"),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => updateOffset(300),
                        child: const Text("+0.3s"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarBuscadorManual(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initialCleanTitle = _cleanDisplayTitle();
    final controller = TextEditingController(text: initialCleanTitle);

    Timer? debounce;
    List<LyricsResult> candidateResults = [];
    bool isSearchingCandidates = false;
    bool hasSearched = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131522) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void performSearch(String query) async {
              final q = query.trim();
              if (q.isEmpty) {
                setModalState(() {
                  candidateResults = [];
                  isSearchingCandidates = false;
                  hasSearched = false;
                });
                return;
              }

              setModalState(() {
                isSearchingCandidates = true;
                hasSearched = true;
              });

              final results = await _lyricsService.searchLyricsCandidates(
                q,
                filePath: _currentSong.rutaArchivo,
                durationSeconds: _effectiveDuration(),
              );

              final syncedResults = results.where((r) => r.isSynced).toList();

              if (ctx.mounted) {
                setModalState(() {
                  candidateResults = syncedResults;
                  isSearchingCandidates = false;
                });
              }
            }

            if (!hasSearched && controller.text.trim().isNotEmpty) {
              Future.microtask(() => performSearch(controller.text));
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(LucideIcons.search, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            CustomText(
                              text: "Búsqueda de Letras",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            debounce?.cancel();
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Escribe el nombre de la canción o artista (sin .mp3 ni nombres feos):",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "Ej: Bohemian Rhapsody Queen",
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF2F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  controller.clear();
                                  setModalState(() {
                                    candidateResults = [];
                                    hasSearched = false;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        debounce?.cancel();
                        debounce = Timer(const Duration(milliseconds: 250), () {
                          performSearch(val);
                        });
                      },
                      onSubmitted: (val) {
                        debounce?.cancel();
                        performSearch(val);
                      },
                    ),
                    const SizedBox(height: 8),

                    if (isSearchingCandidates)
                      LinearProgressIndicator(
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        color: AppColors.primary,
                        minHeight: 2.5,
                      )
                    else
                      const SizedBox(height: 2.5),

                    const SizedBox(height: 8),

                    // LISTA DE RESULTADOS CANDIDATOS
                    Expanded(
                      child: candidateResults.isNotEmpty
                          ? ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: candidateResults.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                              itemBuilder: (context, i) {
                                final item = candidateResults[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: item.isSynced
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item.isSynced ? LucideIcons.micVocal : LucideIcons.fileText,
                                      size: 18,
                                      color: item.isSynced
                                          ? AppColors.primary
                                          : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    item.artist.isNotEmpty ? item.artist : "Artista desconocido",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Icon(
                                    LucideIcons.chevronRight,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    debounce?.cancel();
                                    Navigator.pop(ctx);
                                    _lyricsService.cacheSelectedResult(_currentSong.titulo, null, item);
                                    setState(() {
                                      _lyricsResult = item;
                                      _candidateResults = candidateResults;
                                      _lineKeys.clear();
                                      _activeLineIndex = -1;
                                      _isLoading = false;
                                      _isKaraokeMode = item.isSynced;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                                      }
                                    });
                                  },
                                );
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  isSearchingCandidates
                                      ? "Buscando en catálogo musical mundial..."
                                      : (hasSearched
                                          ? "No se encontraron coincidencias exactas. Puedes generar la letra con IA."
                                          : "Escribe el título para ver sugerencias en tiempo real."),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: AppColors.accent),
                            ),
                            icon: Icon(LucideIcons.sparkles, size: 16, color: AppColors.accent),
                            label: Text(
                              "Generar IA",
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12),
                            ),
                            onPressed: () async {
                              final q = controller.text.trim();
                              if (q.isEmpty) return;
                              if (!await _verificarInternet()) return;
                              debounce?.cancel();
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _generarConIA(customQuery: q);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF08090D),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(LucideIcons.search, size: 16),
                            label: const Text(
                              "Buscar en Internet",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () async {
                              final q = controller.text.trim();
                              if (q.isEmpty) return;
                              if (!await _verificarInternet()) return;
                              debounce?.cancel();
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _buscarLetra(customQuery: q);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Calcula el índice de la línea activa considerando el offset de calibración
  int _calculateActiveIndex(List<LyricLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;

    final offsetMs = _lyricsResult?.timeOffsetMs ?? 0;
    final adjustedMs = currentPosition.inMilliseconds + offsetMs;

    int activeIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (adjustedMs >= lines[i].timestamp.inMilliseconds) {
        activeIdx = i;
      } else {
        break;
      }
    }

    return activeIdx;
  }

  /// Sincroniza la posición de audio con las letras y centra la línea activa considerando el desfase milimétrico y pausas de baladas
  void _syncCurrentPositionWithLyrics(Duration currentPosition, {bool force = false}) {
    if (_lyricsResult == null) return;
    final lines = _lyricsResult!.lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final activeIdx = _calculateActiveIndex(lines, currentPosition);

    if (activeIdx != _activeLineIndex || force) {
      setState(() {
        _activeLineIndex = activeIdx;
      });
      if (activeIdx >= 0) {
        _scrollToActiveLine(activeIdx, force: force);
      }
    }
  }

  /// Desplaza la línea activa para que se mantenga exactamente en el CENTRO vertical de la pantalla
  void _scrollToActiveLine(int index, {bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients || index < 0) return;
    if (_userIsScrolling && !force) return;

    final keyContext = _lineKeys[index]?.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.45,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    } else {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;
      const avgItemHeight = 68.0;
      final target = (index * avgItemHeight) - (viewportHeight * 0.35);

      if (animate) {
        _scrollController.animateTo(
          target.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target.clamp(0.0, maxScroll));
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newContext = _lineKeys[index]?.currentContext;
        if (newContext != null && mounted) {
          Scrollable.ensureVisible(
            newContext,
            alignment: 0.45,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090A10) : const Color(0xFFF4F6FC),
      body: Stack(
        children: [
          // 🌌 Resplandor ambiental de fondo reactivo
          Positioned(
            top: -60,
            left: -40,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: isDark ? _glowAnimation.value : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 120,
            right: -50,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: isDark ? _glowAnimation.value * 0.8 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 🔝 Barra superior personalizada de alta gama
                _buildAppBar(context, theme, isDark),

                // 🏷 Barra de insignias de estado (Sincronizada, Versiones alternativas, Traducción, IA)
                if (!_isLoading && _lyricsResult != null) _buildStatusHeader(isDark),

                // 📜 Área central de letras (Karaoke, Texto o Lista de Candidatos Sugeridos)
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState(isDark)
                      : (_lyricsResult == null ||
                              (_lyricsResult!.lines.isEmpty && _lyricsResult!.plainLyrics.isEmpty))
                          ? _buildEmptyState(context, isDark)
                          : _isKaraokeMode && _lyricsResult!.lines.isNotEmpty
                              ? _buildSyncedLyricsView(context, isDark)
                              : _buildPlainLyricsView(context, isDark),
                ),

                // 🎛 Mini-reproductor y controles rítmicos integrados al pie
                _buildBottomPlaybackBar(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.chevronDown,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomText(
                  text: "LETRAS & IA",
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  _cleanDisplayTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _cleanDisplayArtist(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Botón Buscar
          IconButton(
            icon: Icon(LucideIcons.search, color: isDark ? Colors.white70 : Colors.black87, size: 20),
            tooltip: "Buscar letra",
            onPressed: () => _mostrarBuscadorManual(context),
          ),
          // Botón Traducir
          IconButton(
            icon: Icon(
              LucideIcons.languages,
              color: _lyricsResult?.activeTranslationLang != null ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
              size: 20,
            ),
            tooltip: "Traducir con IA",
            onPressed: () => _mostrarMenuTraduccion(context),
          ),
          // Botón Modo Karaoke / Texto
          IconButton(
            icon: Icon(
              _isKaraokeMode ? LucideIcons.alignLeft : LucideIcons.micVocal,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            tooltip: _isKaraokeMode ? "Ver texto plano" : "Modo Karaoke sincronizado",
            onPressed: () {
              setState(() {
                _isKaraokeMode = !_isKaraokeMode;
              });
            },
          ),
        ],
      ),
    );
  }

  void _mostrarAjusteTiempo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentOffset = _lyricsResult?.timeOffsetMs ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.sliders, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Calibrar Tiempo de Letra",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Si la letra va desfasada por milisegundos respecto al audio, ajústala aquí:",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF1F8),
                          ),
                          onPressed: () {
                            final newOffset = currentOffset - 250;
                            setState(() {
                              _lyricsResult = _lyricsResult?.copyWith(timeOffsetMs: newOffset);
                            });
                            setModalState(() {});
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          },
                          child: Text("-250ms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF1F8),
                          ),
                          onPressed: () {
                            final newOffset = currentOffset - 100;
                            setState(() {
                              _lyricsResult = _lyricsResult?.copyWith(timeOffsetMs: newOffset);
                            });
                            setModalState(() {});
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          },
                          child: Text("-100ms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "${currentOffset >= 0 ? '+' : ''}${currentOffset}ms",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF1F8),
                          ),
                          onPressed: () {
                            final newOffset = currentOffset + 100;
                            setState(() {
                              _lyricsResult = _lyricsResult?.copyWith(timeOffsetMs: newOffset);
                            });
                            setModalState(() {});
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          },
                          child: Text("+100ms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF1F8),
                          ),
                          onPressed: () {
                            final newOffset = currentOffset + 250;
                            setState(() {
                              _lyricsResult = _lyricsResult?.copyWith(timeOffsetMs: newOffset);
                            });
                            setModalState(() {});
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          },
                          child: Text("+250ms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (currentOffset != 0)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _lyricsResult = _lyricsResult?.copyWith(timeOffsetMs: 0);
                        });
                        setModalState(() {});
                        _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                      },
                      child: const Text("Restablecer a 0ms"),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusHeader(bool isDark) {
    final transLang = _lyricsResult?.activeTranslationLang;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Badge de Tipo (Sincronizada / Texto / Local / IA)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _mostrarAjusteTiempo(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _lyricsResult!.isEmbedded
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : (_lyricsResult!.isAI
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : (_lyricsResult!.isSynced ? AppColors.primary.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15))),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _lyricsResult!.isEmbedded
                                ? LucideIcons.hardDrive
                                : (_lyricsResult!.isAI ? LucideIcons.sparkles : (_lyricsResult!.isSynced ? LucideIcons.micVocal : LucideIcons.alignLeft)),
                            size: 11,
                            color: _lyricsResult!.isAI
                                ? AppColors.accent
                                : (_lyricsResult!.isSynced ? AppColors.primary : Colors.orange),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _lyricsResult!.isEmbedded
                                ? "Etiqueta Local"
                                : (_lyricsResult!.isAI
                                    ? "Letra IA"
                                    : (_lyricsResult!.isSynced ? "Sincronizada" : "Texto Oficial")),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _lyricsResult!.isAI
                                  ? AppColors.accent
                                  : (_lyricsResult!.isSynced ? AppColors.primary : Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Chip de Calibración de Desfase
                  if (_lyricsResult != null && _lyricsResult!.isSynced) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _mostrarAjusteDesfase(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: _lyricsResult!.timeOffsetMs != 0
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.timer, size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _lyricsResult!.timeOffsetMs == 0
                                  ? "Calibrar"
                                  : "${_lyricsResult!.timeOffsetMs > 0 ? '+' : ''}${_lyricsResult!.timeOffsetMs}ms",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Chip de versiones alternativas encontradas
                  if (_candidateResults.length > 1) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _mostrarSelectorVersiones(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.listMusic, size: 11, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              "${_candidateResults.length} versiones",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (transLang != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Traducido: $transLang",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Control de tamaño de fuente
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  if (_fontSize > 13) {
                    setState(() => _fontSize -= 1.5);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(LucideIcons.minus, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "${_fontSize.toInt()}pt",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  if (_fontSize < 24) {
                    setState(() => _fontSize += 1.5);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(LucideIcons.plus, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.8),
    );
  }

  /// Vista de sugerencias directas: muestra las posibles letras descubiertas para evitar que el usuario tenga que escribir
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    if (_candidateResults.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "Letras posibles para tu canción",
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      Text(
                        "Selecciona la versión que coincida con tu audio:",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Lista de tarjetas interactivas de candidatos encontrados
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _candidateResults.length,
                itemBuilder: (context, i) {
                  final candidate = _candidateResults[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131622) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: candidate.isSynced
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : (isDark ? Colors.white10 : Colors.black12),
                        width: candidate.isSynced ? 1.4 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      onTap: () {
                        _lyricsService.cacheSelectedResult(_currentSong.titulo, null, candidate);
                        setState(() {
                          _lyricsResult = candidate;
                          _isKaraokeMode = candidate.isSynced;
                          _lineKeys.clear();
                          _activeLineIndex = -1;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                          }
                        });
                      },
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: candidate.isSynced
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          candidate.isSynced ? LucideIcons.micVocal : LucideIcons.alignLeft,
                          color: candidate.isSynced ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        candidate.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          candidate.artist.isNotEmpty ? candidate.artist : "Artista desconocido",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF08090D),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _lyricsService.cacheSelectedResult(_currentSong.titulo, null, candidate);
                          setState(() {
                            _lyricsResult = candidate;
                            _isKaraokeMode = candidate.isSynced;
                            _lineKeys.clear();
                            _activeLineIndex = -1;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _syncCurrentPositionWithLyrics(_music.player.position, force: true);
                            }
                          });
                        },
                        child: const Text("Usar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                ),
                onPressed: _generarConIA,
                icon: Icon(LucideIcons.sparkles, size: 15, color: AppColors.accent),
                label: Text(
                  "Generar con IA si ninguna coincide",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161928) : const Color(0xFFE6F8F4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.music,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            CustomText(
              text: "Sin letra encontrada",
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 6),
            Text(
              "No se encontraron coincidencias automáticas en internet. Puedes buscar con otro nombre o generar la letra con IA.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            // Botón 1: Buscar otro término manualmente
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.7)),
                ),
                onPressed: () => _mostrarBuscadorManual(context),
                icon: Icon(LucideIcons.search, size: 17, color: AppColors.primary),
                label: Text(
                  "Buscar canción o artista manualmente 🔍",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Botón 2: Generar con IA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF08090D),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _generarConIA,
                icon: const Icon(LucideIcons.sparkles, size: 17),
                label: const Text(
                  "Generar letra con IA (1 toque)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedLyricsView(BuildContext context, bool isDark) {
    final lines = _lyricsResult!.lines.where((l) => l.text.trim().isNotEmpty).toList();
    final screenHeight = MediaQuery.of(context).size.height;
    final verticalPadding = screenHeight * 0.32;

    return StreamBuilder<Duration>(
      initialData: _music.player.position,
      stream: _music.positionStream,
      builder: (context, snapshot) {
        final currentPosition = _dragPosition ?? snapshot.data ?? _music.player.position;

        final activeIdx = _calculateActiveIndex(lines, currentPosition);

        if (activeIdx != _activeLineIndex) {
          _activeLineIndex = activeIdx;
          if (activeIdx >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_userIsScrolling) {
                _scrollToActiveLine(activeIdx);
              }
            });
          }
        }

        final bool isIntro = (activeIdx == -1 && lines.isNotEmpty && lines[0].timestamp > const Duration(seconds: 4));

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo is ScrollStartNotification && scrollInfo.dragDetails != null) {
              _userIsScrolling = true;
              _resumeAutoScrollTimer?.cancel();
            } else if (scrollInfo is ScrollEndNotification) {
              _resumeAutoScrollTimer?.cancel();
              _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 2500), () {
                if (mounted) {
                  setState(() {
                    _userIsScrolling = false;
                  });
                  _scrollToActiveLine(_activeLineIndex);
                }
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            cacheExtent: 10000.0,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
            physics: const BouncingScrollPhysics(),
            itemCount: lines.length + (isIntro ? 1 : 0),
            itemBuilder: (context, idx) {
              if (isIntro && idx == 0) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.music, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        "♪ [Intro Instrumental]",
                        style: TextStyle(
                          fontSize: _fontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final i = isIntro ? idx - 1 : idx;
              final line = lines[i];
              if (line.text.trim().isEmpty) return const SizedBox.shrink();

              final isActive = (i == _activeLineIndex);
              final isPassed = (i < _activeLineIndex);
              final lineKey = _lineKeys.putIfAbsent(i, () => GlobalKey());

              return GestureDetector(
                key: lineKey,
                onTap: () async {
                  _resumeAutoScrollTimer?.cancel();
                  setState(() {
                    _userIsScrolling = false;
                  });
                  await _music.seek(line.timestamp);
                  _scrollToActiveLine(i, animate: true, force: true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: isDark ? 0.40 : 0.28)
                          : Colors.transparent,
                      width: 1.4,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isActive ? _fontSize + 2.5 : _fontSize,
                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                          color: isActive
                              ? AppColors.primary
                              : (isPassed
                                  ? (isDark ? Colors.white60 : Colors.black54)
                                  : (isDark ? Colors.white30 : Colors.black26)),
                          height: 1.32,
                        ),
                      ),
                      if (line.translatedText != null && line.translatedText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          line.translatedText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isActive ? _fontSize - 1.5 : _fontSize - 3,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            color: isActive
                                ? AppColors.accent
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlainLyricsView(BuildContext context, bool isDark) {
    final plainText = _lyricsResult?.translatedPlainLyrics ?? _lyricsResult?.plainLyrics ?? "Sin letra";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _lyricsResult?.activeTranslationLang != null
                    ? "Letra Traducida (${_lyricsResult!.activeTranslationLang})"
                    : "Letra en Texto Plano",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.languages, size: 18, color: AppColors.primary),
                    tooltip: "Traducir texto",
                    onPressed: () => _mostrarMenuTraduccion(context),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.copy,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    tooltip: "Copiar letra",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: plainText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Letra copiada al portapapeles"), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            plainText,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomPlaybackBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10121A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: StreamBuilder<PositionData>(
        stream: _music.positionDataStream,
        builder: (context, snapshot) {
          final posData = snapshot.data;
          final pos = _dragPosition ?? posData?.position ?? Duration.zero;
          final dur = posData?.duration ?? Duration(seconds: _effectiveDuration());
          final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
          final curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de progreso y tiempos
              Row(
                children: [
                  Text(
                    _formatDuration(pos),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                        thumbColor: AppColors.primary,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: curSec,
                        min: 0.0,
                        max: maxSec,
                        onChanged: (v) {
                          setState(() {
                            _dragPosition = Duration(seconds: v.toInt());
                            _userIsScrolling = false;
                          });
                          _syncCurrentPositionWithLyrics(_dragPosition!, force: true);
                        },
                        onChangeEnd: (v) async {
                          _resumeAutoScrollTimer?.cancel();
                          final target = Duration(seconds: v.toInt());
                          await _music.seek(target);
                          setState(() {
                            _dragPosition = null;
                            _userIsScrolling = false;
                          });
                          _syncCurrentPositionWithLyrics(target, force: true);
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),

              // Botones de reproducción
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.skipBack, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                    onPressed: () async => await _music.previous(),
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: _music,
                    builder: (context, _) {
                      final playing = _music.isPlaying;
                      return GestureDetector(
                        onTap: () async {
                          if (playing) {
                            await _music.pause();
                          } else {
                            await _music.play();
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            playing ? LucideIcons.pause : LucideIcons.play,
                            size: 20,
                            color: const Color(0xFF08090D),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(LucideIcons.skipForward, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                    onPressed: () async => await _music.next(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:marquee/marquee.dart';
import 'package:playerapp1/clases/favorito.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/connectivity_service.dart';
import 'package:playerapp1/services/equalizerservice.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/vista/letras.dart';
import 'package:playerapp1/widgets/diseños/ai_cover_generator.dart';
import 'package:playerapp1/widgets/diseños/text.dart';
import 'package:playerapp1/widgets/diseños/visualizador.dart';

class PlayerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PlayerScreen({super.key, this.onBack});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final music = MusicService.instance;
  final equalizer = EqualizerService.instance;
  final FavoritoDao _favoritoDao = FavoritoDao();
  bool esFavorito = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarEstadoFavorito();
    });
    music.currentSongIdNotifier.addListener(_onSongChanged);
  }

  @override
  void dispose() {
    music.currentSongIdNotifier.removeListener(_onSongChanged);
    super.dispose();
  }

  void _onSongChanged() {
    _cargarEstadoFavorito();
  }

  Future<void> _cargarEstadoFavorito() async {
    final id = music.currentSong?.id;

    if (id == null) {
      if (!mounted) return;
      setState(() {
        esFavorito = false;
      });
      return;
    }

    final favorito = await _favoritoDao.isFavorito(id);

    if (!mounted) return;
    setState(() {
      esFavorito = favorito;
    });
  }

  String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (h > 0) {
      return "$h:$m:$s";
    }
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF11131B),
                    const Color(0xFF08090D),
                    const Color(0xFF08090D),
                  ]
                : [
                    const Color(0xFFE8FAF6),
                    const Color(0xFFF6F8FC),
                    const Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: music,
            builder: (context, _) {
              final song = music.currentSong;
              final isPlaying = music.isPlaying;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 6,
                            bottom:
                                92, // Espacio para que CustomBottomBar no tape los controles
                          ),
                          child: Column(
                            children: [
                              /// 🔝 CABECERA MINIMALISTA Y ACCIONES SUPERIORES
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.chevronDown,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      if (widget.onBack != null) {
                                        widget.onBack!();
                                      } else if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  Column(
                                    children: [
                                      CustomText(
                                        text: "REPRODUCIENDO",
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(height: 2),
                                      CustomText(
                                        text: music.context.toUpperCase(),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Botón Letras IA & Estrella
                                      ValueListenableBuilder<bool>(
                                        valueListenable: ConnectivityService
                                            .instance
                                            .isOnlineNotifier,
                                        builder: (context, isOnline, _) {
                                          return IconButton(
                                            icon: Icon(
                                              LucideIcons.sparkles,
                                              color: isOnline
                                                  ? AppColors.accent
                                                  : (isDark
                                                        ? Colors.white24
                                                        : Colors.black26),
                                              size: 20,
                                            ),
                                            tooltip: isOnline
                                                ? "Letras con IA"
                                                : "Sin conexión a internet",
                                            onPressed: () {
                                              if (!isOnline) {
                                                return;
                                              }
                                              if (song != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        LyricsScreen(
                                                          song: song,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      // Botón Cola de Reproducción
                                      IconButton(
                                        icon: Badge(
                                          isLabelVisible:
                                              music.userQueueCount > 0,
                                          label: Text(
                                            music.userQueueCount.toString(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor: AppColors.primary,
                                          textColor: const Color(0xFF08090D),
                                          child: Icon(
                                            LucideIcons.listMusic,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                            size: 22,
                                          ),
                                        ),
                                        onPressed: () {
                                          _mostrarColaReproduccion(context);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const Spacer(flex: 1),

                              /// 💿 DISCO DE VINILO GIRATORIO CON BRAZO TOCADISCOS Y RESPLANDOR
                              RepaintBoundary(
                                child: VinylRecordDisk(
                                  isPlaying: isPlaying,
                                  size: 215,
                                  onLongPress: () {
                                    if (song != null) {
                                      AICoverGeneratorModal.show(
                                        context,
                                        initialTitle: song.titulo,
                                      );
                                    }
                                  },
                                ),
                              ),

                              const Spacer(flex: 1),

                              /// 🎵 TÍTULO + FORMATO + FAVORITO
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 30,
                                          child: song != null
                                              ? Marquee(
                                                  text: song.titulo,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  scrollAxis: Axis.horizontal,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  blankSpace: 40.0,
                                                  velocity: 30.0,
                                                  pauseAfterRound:
                                                      const Duration(
                                                        seconds: 2,
                                                      ),
                                                )
                                              : CustomText(
                                                  text: "Sin reproducción",
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                song != null
                                                    ? song.rutaArchivo
                                                          .split('.')
                                                          .last
                                                          .toUpperCase()
                                                    : "AUDIO",
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CustomText(
                                                text:
                                                    song != null &&
                                                        song.tamanoArchivo !=
                                                            null
                                                    ? "${(song.tamanoArchivo! / (1024 * 1024)).toStringAsFixed(1)} MB"
                                                    : "0.0 MB",
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      esFavorito
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: esFavorito
                                          ? AppColors.accent
                                          : (isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                      size: 26,
                                    ),
                                    onPressed: () async {
                                      final current = music.currentSong;
                                      if (current?.id == null) return;
                                      await _favoritoDao.toggleFavorito(
                                        current!.id!,
                                      );
                                      await _cargarEstadoFavorito();
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              /// 🎚 LÍNEA DE TIEMPO CON ONDAS SONORAS
                              RepaintBoundary(
                                child: StreamBuilder<PositionData>(
                                  stream: music.positionDataStream,
                                  builder: (context, snapshot) {
                                  final positionData = snapshot.data;
                                  final pos =
                                      positionData?.position ?? Duration.zero;
                                  final dur =
                                      positionData?.duration ?? Duration.zero;

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: WaveformSlider(
                                          position: pos,
                                          duration: dur,
                                          songId: music.currentSong?.id ?? 0,
                                          songTitle:
                                              music.currentSong?.titulo ??
                                              "Sin reproducción",
                                          onChanged: (v) async {
                                            await music.seek(
                                              Duration(seconds: v.toInt()),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            CustomText(
                                              text: format(pos),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                            CustomText(
                                              text: format(dur),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                              const Spacer(flex: 1),

                              /// 🎮 FILA PRINCIPAL HERO: ALEATORIO, PREV, PLAY/PAUSE, NEXT, BUCLE (ORGANICO, SIN CONTAINER)
                              StreamBuilder<PlayerState>(
                                stream: music.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing =
                                      snapshot.data?.playing ?? music.isPlaying;

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 🔀 Shuffle
                                      AnimatedBuilder(
                                        animation: music,
                                        builder: (context, _) {
                                          final isShuffle =
                                              music.shuffleEnabled;
                                          return IconButton(
                                            icon: Icon(
                                              LucideIcons.shuffle,
                                              size: 22,
                                              color: isShuffle
                                                  ? AppColors.primary
                                                  : (isDark
                                                        ? Colors.white38
                                                        : Colors.black38),
                                            ),
                                            tooltip: "Aleatorio",
                                            onPressed: () {
                                              music.toggleShuffle();
                                            },
                                          );
                                        },
                                      ),

                                      // ⏮ Previous
                                      _circleBtn(
                                        context: context,
                                        icon: LucideIcons.skipBack,
                                        size: 48,
                                        iconSize: 20,
                                        onTap: () async {
                                          await music.previous();
                                        },
                                      ),

                                      // ⏯ Play / Pause Central
                                      _playBtn(
                                        context: context,
                                        playing: playing,
                                        onTap: () async {
                                          if (playing) {
                                            await music.pause();
                                          } else {
                                            await music.play();
                                          }
                                        },
                                      ),

                                      // ⏭ Next
                                      _circleBtn(
                                        context: context,
                                        icon: LucideIcons.skipForward,
                                        size: 48,
                                        iconSize: 20,
                                        onTap: () async {
                                          await music.next();
                                        },
                                      ),

                                      // 🔁 Loop
                                      AnimatedBuilder(
                                        animation: music,
                                        builder: (context, _) {
                                          final loopMode = music.loopMode;
                                          IconData loopIcon =
                                              LucideIcons.repeat;
                                          bool isActive = true;

                                          if (loopMode == LoopMode.one) {
                                            loopIcon = LucideIcons.repeat1;
                                          } else if (loopMode == LoopMode.all) {
                                            loopIcon = LucideIcons.repeat;
                                          } else {
                                            isActive = false;
                                          }

                                          return IconButton(
                                            icon: Icon(
                                              loopIcon,
                                              size: 22,
                                              color: isActive
                                                  ? AppColors.primary
                                                  : (isDark
                                                        ? Colors.white38
                                                        : Colors.black38),
                                            ),
                                            tooltip: "Bucle",
                                            onPressed: () {
                                              music.changeLoopMode();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 14),

                              /// 🎛 FILA DE HERRAMIENTAS RÁPIDAS FLOTANTES (ORGANICO, SIN CONTAINER)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // 1. Velocidad
                                  AnimatedBuilder(
                                    animation: music,
                                    builder: (context, _) {
                                      final speed = music.speed;
                                      final isCustom =
                                          (speed - 1.0).abs() > 0.01;
                                      return _ModernToolButton(
                                        icon: LucideIcons.gauge,
                                        label: "${speed}x",
                                        isActive: isCustom,
                                        onTap: () {
                                          _mostrarSelectorVelocidad(context);
                                        },
                                      );
                                    },
                                  ),

                                  // 2. Volumen
                                  AnimatedBuilder(
                                    animation: music,
                                    builder: (context, _) {
                                      final vol = (music.volume * 100).toInt();
                                      return _ModernToolButton(
                                        icon: LucideIcons.volume2,
                                        label: "$vol%",
                                        onTap: () {
                                          _mostrarDialogoVolumen(context);
                                        },
                                      );
                                    },
                                  ),

                                  // 3. Ecualizador
                                  AnimatedBuilder(
                                    animation: equalizer,
                                    builder: (context, _) {
                                      return _ModernToolButton(
                                        icon: LucideIcons.sliders,
                                        label: "EQ Pro",
                                        isActive: equalizer.isEnabled,
                                        onTap: () {
                                          _mostrarEcualizador(context);
                                        },
                                      );
                                    },
                                  ),

                                  // 4. Letras con IA
                                  ValueListenableBuilder<bool>(
                                    valueListenable: ConnectivityService
                                        .instance
                                        .isOnlineNotifier,
                                    builder: (context, isOnline, _) {
                                      return _ModernToolButton(
                                        icon: LucideIcons.micVocal,
                                        label: "Letras IA",
                                        isActive: isOnline,
                                        onTap: () {
                                          if (!isOnline) {
                                            return;
                                          }
                                          if (song != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    LyricsScreen(song: song),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),

                                  // 5. Cola
                                  AnimatedBuilder(
                                    animation: music,
                                    builder: (context, _) {
                                      final count = music.userQueueCount;
                                      return _ModernToolButton(
                                        icon: LucideIcons.listMusic,
                                        label: "Cola ($count)",
                                        isActive: count > 0,
                                        onTap: () {
                                          _mostrarColaReproduccion(context);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _mostrarSelectorVelocidad(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final velocidades = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentSpeed = music.speed;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomText(
                          text: "Velocidad de Reproducción",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${currentSpeed}x",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: velocidades.map((v) {
                        final isSelected = (currentSpeed - v).abs() < 0.01;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await music.setSpeed(v);
                            setModalState(() {});
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? const Color(0xFF1F2335)
                                        : const Color(0xFFF1F3F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.black12),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              "${v}x",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF08090D)
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarColaReproduccion(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11131B) : Colors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final userQueue = music.userQueue;
            final currentSong = music.currentSong;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.listMusic,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            CustomText(
                              text: "Cola de Reproducción",
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ],
                        ),
                        if (userQueue.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              await music.clearUserQueue();
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.trash2,
                                    size: 13,
                                    color: AppColors.danger,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Vaciar cola",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Canción actual reproduciéndose
                    if (currentSong != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: Color(0xFF08090D),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "REPRODUCIENDO AHORA",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    currentSong.titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Título de sección de la cola
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "A CONTINUACIÓN EN LA COLA (${userQueue.length})",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white38 : Colors.black45,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: userQueue.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF181B26)
                                            : const Color(0xFFF1F3F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        LucideIcons.listPlus,
                                        size: 28,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black26,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    CustomText(
                                      text: "Tu cola está vacía",
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Añade canciones desde cualquier lista usando 'Añadir a la cola' (⋮) para crear tu sesión al vuelo.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black45,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: userQueue.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (newIndex > oldIndex) newIndex--;
                                await music.reorderUserQueue(
                                  oldIndex,
                                  newIndex,
                                );
                                setModalState(() {});
                              },
                              itemBuilder: (context, index) {
                                final song = userQueue[index];

                                return Container(
                                  key: ValueKey(
                                    "user_queue_${song.id ?? song.rutaArchivo}_$index",
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF181B26)
                                        : const Color(0xFFF6F8FC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 2,
                                    ),
                                    onTap: () async {
                                      await music.playSong(song);
                                      setModalState(() {});
                                    },
                                    leading: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (index + 1).toString().padLeft(
                                            2,
                                            '0',
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      song.titulo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      song.rutaArchivo
                                          .split('.')
                                          .last
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black45,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            LucideIcons.x,
                                            size: 16,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                          onPressed: () async {
                                            await music.removeUserQueueItemAt(
                                              index,
                                            );
                                            setModalState(() {});
                                          },
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Icon(
                                            LucideIcons.gripVertical,
                                            size: 18,
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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

  void _mostrarEcualizador(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11131B) : Colors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header con Switch de activación
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.sliders,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText(
                                  text: "Ecualizador Pro",
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                Text(
                                  equalizer.isEnabled
                                      ? "Activo"
                                      : "Desactivado",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: equalizer.isEnabled
                                        ? AppColors.primary
                                        : (isDark
                                              ? Colors.white38
                                              : Colors.black38),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                LucideIcons.rotateCcw,
                                size: 18,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              onPressed: () {
                                equalizer.reset();
                                setModalState(() {});
                              },
                            ),
                            Switch(
                              value: equalizer.isEnabled,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) {
                                equalizer.toggleEnabled();
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Selector horizontal de Presets
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: EqualizerService.presets.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final p = EqualizerService.presets[i];
                          final isSelected = equalizer.currentPreset == p.name;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              equalizer.setPreset(p.name);
                              setModalState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                          ? const Color(0xFF1E2232)
                                          : const Color(0xFFF1F4F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF08090D)
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 5 Bandas Verticales de Frecuencia
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF181B26)
                            : const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(5, (index) {
                          final label = EqualizerService.bandLabels[index];
                          final gain = equalizer.bandGains[index];

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: gain.abs() > 0.1
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white38
                                            : Colors.black45),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 130,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: gain,
                                    min: -12.0,
                                    max: 12.0,
                                    activeColor: AppColors.primary,
                                    inactiveColor: isDark
                                        ? const Color(0xFF282C3E)
                                        : const Color(0xFFE2E8F0),
                                    onChanged: equalizer.isEnabled
                                        ? (val) {
                                            equalizer.setBandGain(index, val);
                                            setModalState(() {});
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Sliders de Efectos Especiales (Bass Boost y Virtualizer)
                    Row(
                      children: [
                        // Bass Boost
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF181B26)
                                  : const Color(0xFFF6F8FC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Bajos (Bass)",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      "${(equalizer.bassBoost * 100).toInt()}%",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: equalizer.bassBoost,
                                  activeColor: AppColors.primary,
                                  inactiveColor: isDark
                                      ? const Color(0xFF282C3E)
                                      : const Color(0xFFE2E8F0),
                                  onChanged: equalizer.isEnabled
                                      ? (v) {
                                          equalizer.setBassBoost(v);
                                          setModalState(() {});
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 3D Virtualizer
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF181B26)
                                  : const Color(0xFFF6F8FC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Sonido 3D",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      "${(equalizer.virtualizer * 100).toInt()}%",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: equalizer.virtualizer,
                                  activeColor: AppColors.accent,
                                  inactiveColor: isDark
                                      ? const Color(0xFF282C3E)
                                      : const Color(0xFFE2E8F0),
                                  onChanged: equalizer.isEnabled
                                      ? (v) {
                                          equalizer.setVirtualizer(v);
                                          setModalState(() {});
                                        }
                                      : null,
                                ),
                              ],
                            ),
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

  void _mostrarDialogoVolumen(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final vol = MusicService.instance.volume;
            return Padding(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomText(
                        text: "Volumen del Reproductor",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      CustomText(
                        text: "${(vol * 100).toInt()}%",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.volume1,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      Expanded(
                        child: Slider(
                          value: vol,
                          activeColor: AppColors.primary,
                          inactiveColor: isDark
                              ? const Color(0xFF222538)
                              : const Color(0xFFE2E8F0),
                          onChanged: (val) {
                            MusicService.instance.setVolume(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      Icon(
                        LucideIcons.volume2,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _circleBtn({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    double size = 52,
    double iconSize = 20,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2D) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: iconSize,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _playBtn({
    required BuildContext context,
    required bool playing,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          playing ? LucideIcons.pause : LucideIcons.play,
          color: const Color(0xFF08090D),
          size: 30,
        ),
      ),
    );
  }
}

class _ModernToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ModernToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppColors.primary
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.primary
                    : (isDark ? Colors.white38 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformSlider extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onChanged;
  final int songId;
  final String songTitle;

  const WaveformSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.songId,
    required this.songTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const int barsCount = 38;
    final List<double> heights = List.generate(barsCount, (index) {
      final hash = (songTitle.hashCode + index * 31) ^ songId;
      final double normalized = (hash.abs() % 24 + 6).toDouble();
      return normalized;
    });

    final double progressPercent = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final dx = details.localPosition.dx;
        final width = box.size.width;
        final double percent = (dx / width).clamp(0.0, 1.0);
        onChanged(percent * duration.inSeconds);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final dx = details.localPosition.dx;
        final width = box.size.width;
        final double percent = (dx / width).clamp(0.0, 1.0);
        onChanged(percent * duration.inSeconds);
      },
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barsCount, (index) {
            final double barHeight = heights[index];
            final double barProgress = index / barsCount;
            final bool isActive = barProgress <= progressPercent;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark
                            ? const Color(0xFF222538)
                            : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

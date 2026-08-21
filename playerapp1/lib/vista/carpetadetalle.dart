import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/diseños/modalamplio2.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Cancion> songs = [];
  bool loading = true;
  int totalCanciones = 0;
  double totalMB = 0;
  final CancionRepository _cancionDao = CancionRepository();

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final data = await _cancionDao.obtenerPorAlbum(widget.album.id!);

    double mb = 0;
    for (final cancion in data) {
      mb += (cancion.tamanoArchivo ?? 0) / (1024 * 1024);
    }

    if (!mounted) return;
    setState(() {
      songs = data;
      totalCanciones = data.length;
      totalMB = mb;
      loading = false;
    });
  }

  void _reproducirTodo({bool aleatorio = false}) async {
    if (songs.isEmpty) return;
    final playlist = List<Cancion>.from(songs);
    if (aleatorio) {
      playlist.shuffle();
    }
    await MusicService.instance.playPlaylist(
      playlist,
      0,
      context: "album_${widget.album.id}",
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: CustomText(
          text: widget.album.titulo,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 📂 CABECERA MINIMALISTA
          _buildHeaderCompact(context, theme, isDark),

          const SizedBox(height: 12),

          /// 🎵 LISTA DE CANCIONES
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : songs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.music4,
                                size: 34,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            CustomText(
                              text: "Esta carpeta está vacía",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(height: 4),
                            CustomText(
                              text: "Asigna canciones desde la biblioteca usando el menú de opciones (⋮).",
                              textAlign: TextAlign.center,
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ],
                        ),
                      )
                    : AnimatedBuilder(
                        animation: MusicService.instance,
                        builder: (context, _) {
                          final music = MusicService.instance;
                          final currentId = music.currentSong?.id;

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(left: 18, right: 18, bottom: 100),
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              final isSelected = song.id != null && currentId == song.id;
                              final mb = ((song.tamanoArchivo ?? 0) / (1024 * 1024))
                                  .toStringAsFixed(1);
                              final extension = song.rutaArchivo.contains('.')
                                  ? song.rutaArchivo.split('.').last.toUpperCase()
                                  : "AUDIO";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.primary.withValues(alpha: 0.08))
                                      : (isDark
                                          ? const Color(0xFF11131B)
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black.withValues(alpha: 0.04)),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  onTap: () async {
                                    final realIndex = songs.indexWhere((e) => e.id == song.id);
                                    if (realIndex == -1) return;

                                    await music.playPlaylist(
                                      songs,
                                      realIndex,
                                      context: "album_${widget.album.id}",
                                    );
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 2,
                                  ),
                                  leading: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Center(
                                      child: isSelected
                                          ? Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.graphic_eq_rounded,
                                                color: AppColors.primary,
                                                size: 16,
                                              ),
                                            )
                                          : CustomText(
                                              text: (index + 1)
                                                  .toString()
                                                  .padLeft(2, '0'),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                    ),
                                  ),
                                  title: CustomText(
                                    overflow: TextOverflow.ellipsis,
                                    text: song.titulo,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            extension,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        CustomText(
                                          text: "$mb MB",
                                          fontSize: 11,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.folderMinus,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                        onPressed: () async {
                                          if (song.id == null) return;

                                          final confirmar = await CustomDialog.show(
                                            context: context,
                                            title: "Quitar de carpeta",
                                            message:
                                                "¿Deseas quitar '${song.titulo}' de esta carpeta?",
                                            confirmText: "Quitar",
                                            cancelText: "Cancelar",
                                          );

                                          if (confirmar != true) return;

                                          await _cancionDao.removeFromAlbum(
                                            song.id!,
                                          );
                                          await _loadSongs();

                                          if (MusicService.instance.context ==
                                              "album_${widget.album.id}") {
                                            await MusicService.instance
                                                .refreshPlaylist(
                                              songs,
                                              context:
                                                  "album_${widget.album.id}",
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.ellipsisVertical,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                        onPressed: () {
                                          ActionBottomSheet.show(
                                            context,
                                            songTitle: song.titulo,
                                            songId: song.id!,
                                            actions: [
                                              ActionItem(
                                                title: "Reproducir",
                                                icon: LucideIcons.play,
                                                onTap: () async {
                                                  final realIndex = songs
                                                      .indexWhere(
                                                    (e) => e.id == song.id,
                                                  );
                                                  if (realIndex == -1) return;
                                                  await MusicService.instance
                                                      .playPlaylist(
                                                    songs,
                                                    realIndex,
                                                    context:
                                                        "album_${widget.album.id}",
                                                  );
                                                },
                                              ),
                                              ActionItem(
                                                title: "Reproducir siguiente",
                                                icon: LucideIcons.listStart,
                                                onTap: () async {
                                                  await MusicService.instance
                                                      .playNext(song);
                                                },
                                              ),
                                              ActionItem(
                                                title: "Añadir a la cola",
                                                icon: LucideIcons.listPlus,
                                                onTap: () async {
                                                  await MusicService.instance
                                                      .addToQueue(song);
                                                },
                                              ),
                                              ActionItem(
                                                title: "Quitar de esta carpeta",
                                                icon: LucideIcons.folderMinus,
                                                textColor: AppColors.danger,
                                                iconColor: AppColors.danger,
                                                darkTextColor:
                                                    AppColors.danger,
                                                darkIconColor:
                                                    AppColors.danger,
                                                onTap: () async {
                                                  await _cancionDao
                                                      .removeFromAlbum(
                                                    song.id!,
                                                  );
                                                  await _loadSongs();
                                                  if (MusicService
                                                          .instance.context ==
                                                      "album_${widget.album.id}") {
                                                    await MusicService.instance
                                                        .refreshPlaylist(
                                                      songs,
                                                      context:
                                                          "album_${widget.album.id}",
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCompact(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: "$totalCanciones ${totalCanciones == 1 ? 'canción' : 'canciones'} • ${totalMB.toStringAsFixed(1)} MB",
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (songs.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reproducirTodo(aleatorio: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(LucideIcons.play, size: 16, color: Colors.white),
                    label: const Text(
                      "Reproducir",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reproducirTodo(aleatorio: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(LucideIcons.shuffle, size: 16),
                    label: const Text(
                      "Aleatorio",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

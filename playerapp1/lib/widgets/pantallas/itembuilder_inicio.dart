import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/favorito.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/diseños/marqueeanimacion.dart';
import 'package:playerapp1/widgets/diseños/modalamplio2.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.cancion,
    required this.index,
    required this.canciones,
    required this.cancionesFiltradas,
    required this.favoritosIds,
    required this.favoritoDao,
    required this.repo,
    required this.onAsignarCancionAAlbum,
  });

  final Cancion cancion;
  final int index;
  final List<Cancion> canciones;
  final List<Cancion> cancionesFiltradas;
  final Set<int> favoritosIds;
  final FavoritoDao favoritoDao;
  final CancionRepository repo;
  final Future<void> Function(int songId, int albumId) onAsignarCancionAAlbum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<int?>(
      valueListenable: MusicService.instance.currentSongIdNotifier,
      builder: (context, currentId, _) {
        final music = MusicService.instance;
        final isPlaying = music.isPlaying;

        final isSelected =
            music.context == "general" &&
            cancion.id != null &&
            cancion.id == (currentId ?? music.currentSong?.id);

        final mb = ((cancion.tamanoArchivo ?? 0) / (1024 * 1024))
            .toStringAsFixed(1);
        final extension = cancion.rutaArchivo.contains('.')
            ? cancion.rutaArchivo.split('.').last.toUpperCase()
            : "AUDIO";
        final isFav = favoritosIds.contains(cancion.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.08))
                : (isDark ? const Color(0xFF11131B) : Colors.white),
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
              final realIndex = canciones.indexWhere((e) => e.id == cancion.id);
              if (realIndex != -1) {
                await MusicService.instance.playPlaylist(
                  canciones,
                  realIndex,
                  context: "general",
                );
              }
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            leading: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: isSelected
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.graphic_eq_rounded
                              : LucideIcons.play,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      )
                    : CustomText(
                        text: (index + 1).toString().padLeft(2, '0'),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
              ),
            ),
            title: isSelected
                ? SongMarqueeTitle(
                    text: cancion.titulo,
                    color: AppColors.primary,
                  )
                : CustomText(
                    text: cancion.titulo,
                    overflow: TextOverflow.ellipsis,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      extension,
                      style: TextStyle(
                        fontSize: 7,
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
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav
                        ? AppColors.danger
                        : (isDark ? Colors.white38 : Colors.black38),
                    size: 20,
                  ),
                  onPressed: () async {
                    if (cancion.id == null) return;
                    await favoritoDao.toggleFavorito(cancion.id!);
                    FavoritosNotifier.instance.actualizar();
                  },
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: () {
                    ActionBottomSheet.show(
                      context,
                      songTitle: cancion.titulo,
                      songId: cancion.id!,
                      actions: [
                        ActionItem(
                          title: "Reproducir",
                          icon: LucideIcons.play,
                          onTap: () async {
                            final realIndex = cancionesFiltradas.indexWhere(
                              (e) => e.id == cancion.id,
                            );
                            if (realIndex == -1) return;
                            await MusicService.instance.playPlaylist(
                              canciones,
                              realIndex,
                              context: "general",
                            );
                          },
                        ),
                        ActionItem(
                          title: "Reproducir siguiente",
                          icon: LucideIcons.listStart,
                          onTap: () async {
                            await MusicService.instance.playNext(cancion);
                          },
                        ),
                        ActionItem(
                          title: "Añadir a la cola",
                          icon: LucideIcons.listPlus,
                          onTap: () async {
                            await MusicService.instance.addToQueue(cancion);
                          },
                        ),
                        ActionItem(
                          title: "Asignar a Carpeta",
                          icon: LucideIcons.folderPlus,
                          onTap: () async {
                            await onAsignarCancionAAlbum(cancion.id!, 1);
                          },
                        ),
                        ActionItem(
                          title: "Eliminar de biblioteca",
                          icon: LucideIcons.trash2,
                          textColor: AppColors.danger,
                          iconColor: AppColors.danger,
                          darkTextColor: AppColors.danger,
                          darkIconColor: AppColors.danger,
                          onTap: () async {
                            if (cancion.id == null) return;
                            final confirmar = await CustomDialog.show(
                              context: context,
                              title: "Eliminar canción",
                              message:
                                  "¿Estás seguro de que deseas eliminar '${cancion.titulo}' de la biblioteca?",
                              confirmText: "Eliminar",
                              cancelText: "Cancelar",
                              confirmButtonColor: AppColors.danger,
                            );

                            if (confirmar != true) return;
                            await repo.eliminar(cancion.id!);
                            await MusicService.instance.removeSongFromPlaylist(
                              cancion.id!,
                            );
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
  }
}

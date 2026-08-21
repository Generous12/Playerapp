import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/vista/carpetadetalle.dart';
import 'package:playerapp1/widgets/diseños/ai_cover_generator.dart';
import 'package:playerapp1/widgets/diseños/modalcrearcarpeta.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';
import 'package:sqflite/sqflite.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  List<Album> albums = [];
  Map<int, int> albumSongCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final data = await Album.getAll();
    final db = await DatabaseHelper.instance.database;
    final Map<int, int> counts = {};

    for (final album in data) {
      if (album.id != null) {
        final res = await db.rawQuery(
          'SELECT COUNT(*) FROM canciones WHERE id_album = ?',
          [album.id],
        );
        counts[album.id!] = Sqflite.firstIntValue(res) ?? 0;
      }
    }

    if (!mounted) return;
    setState(() {
      albums = data;
      albumSongCounts = counts;
      _isLoading = false;
    });
  }

  void _mostrarCrearAlbum(BuildContext context) {
    CreateAlbumModal.show(
      context: context,
      title: "Nueva Carpeta",
      hintText: "Nombre de la colección",
      buttonColor: AppColors.primary,
      onCreate: (album) async {
        await Album.create(album);
        await _loadAlbums();
      },
    );
  }

  Future<void> _eliminarAlbum(Album album) async {
    final confirm = await CustomDialog.show(
      context: context,
      title: "Eliminar Carpeta",
      message: "¿Deseas eliminar la carpeta '${album.titulo}'? Las canciones no se borrarán de tu biblioteca.",
      confirmText: "Eliminar",
      cancelText: "Cancelar",
      confirmButtonColor: AppColors.danger,
    );

    if (confirm == true && album.id != null) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'canciones',
        {'id_album': null},
        where: 'id_album = ?',
        whereArgs: [album.id],
      );
      await Album.delete(album.id!);
      await _loadAlbums();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔝 CABECERA MINIMALISTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomText(
                        text: "Carpetas",
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CustomText(
                          text: "${albums.length}",
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarCrearAlbum(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(LucideIcons.plus, color: Colors.white, size: 16),
                    label: const Text(
                      "Nueva",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              CustomText(
                text: "Organiza tus canciones en listas y álbumes locales.",
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : albums.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.folderClosed,
                                    size: 38,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CustomText(
                                  text: "No tienes carpetas aún",
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(height: 6),
                                CustomText(
                                  text: "Crea carpetas personalizadas para agrupar tus pistas favoritas.",
                                  textAlign: TextAlign.center,
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              final songCount = albumSongCounts[album.id] ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF11131B)
                                      : Colors.white,
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
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AlbumDetailScreen(album: album),
                                      ),
                                    ).then((_) => _loadAlbums());
                                  },
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [
                                                AppColors.primary.withValues(alpha: 0.25),
                                                AppColors.accent.withValues(alpha: 0.15),
                                              ]
                                            : [
                                                const Color(0xFFE0F7FE),
                                                const Color(0xFFE6FCF5),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      LucideIcons.folder,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  title: CustomText(
                                    text: album.titulo,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  subtitle: CustomText(
                                    text: "$songCount ${songCount == 1 ? 'canción' : 'canciones'}",
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.sparkles,
                                          size: 17,
                                          color: AppColors.accent,
                                        ),
                                        tooltip: "Carátula con IA",
                                        onPressed: () {
                                          AICoverGeneratorModal.show(
                                            context,
                                            initialTitle: album.titulo,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.trash2,
                                          size: 18,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                        onPressed: () => _eliminarAlbum(album),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: isDark ? Colors.white30 : Colors.black26,
                                        size: 22,
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
      ),
    );
  }
}

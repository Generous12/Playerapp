import 'package:family_bottom_sheet/family_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/widgets/diseños/marqueeanimacion.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class ActionItem {
  final String title;
  final IconData icon;

  // Fondo
  final Color? backgroundColor;
  final Color? darkBackgroundColor;

  // Borde
  final Color? borderColor;
  final Color? darkBorderColor;

  // Texto
  final Color? textColor;
  final Color? darkTextColor;

  // Icono
  final Color? iconColor;
  final Color? darkIconColor;

  final double borderWidth;
  final double borderRadius;

  final Future Function() onTap;

  ActionItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.darkBackgroundColor,
    this.borderColor,
    this.darkBorderColor,
    this.textColor,
    this.darkTextColor,
    this.iconColor,
    this.darkIconColor,
    this.borderWidth = 1.0,
    this.borderRadius = 16,
  });
}

class ActionBottomSheet {
  static void show(
    BuildContext context, {
    required List<ActionItem> actions,
    required String songTitle,
    int? songId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    FamilyModalSheet.show<void>(
      context: context,
      contentBackgroundColor: isDark
          ? const Color(0xFF11131B)
          : Colors.white,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return _ActionSheetBody(
          actions: actions,
          songTitle: songTitle,
          songId: songId,
        );
      },
    );
  }
}

class _ActionSheetBody extends StatefulWidget {
  final List<ActionItem> actions;
  final String songTitle;
  final int? songId;

  const _ActionSheetBody({
    required this.actions,
    required this.songTitle,
    this.songId,
  });

  @override
  State<_ActionSheetBody> createState() => _ActionSheetBodyState();
}

class _ActionSheetBodyState extends State<_ActionSheetBody> {
  final PageController _controller = PageController();

  List<Album> albums = [];
  bool loadingAlbums = true;

  Cancion? currentSong;
  final Set<int> selectedAlbums = {};

  bool inAlbumMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await Album.getAll();

    Cancion? song;
    if (widget.songId != null) {
      song = await CancionRepository().obtenerPorId(widget.songId!);
    }

    if (!mounted) return;
    setState(() {
      albums = data;
      currentSong = song;
      loadingAlbums = false;
    });
  }

  bool songAlreadyInAlbum(int albumId) {
    if (currentSong == null) return false;
    return currentSong!.idAlbum == albumId;
  }

  void goToAlbums() {
    setState(() => inAlbumMode = true);

    _controller.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void goBack() {
    setState(() => inAlbumMode = false);

    _controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        minHeight: 240,
        maxHeight: inAlbumMode ? 430 : 380,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// ➖ HANDLE BAR
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          /// 🎵 PREVIEW HEADER DE LA CANCIÓN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF181B26)
                  : const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.music,
                      color: const Color(0xFF08090D),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SongMarqueeTitle(
                        text: widget.songTitle,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Opciones de Pista",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildActions(), _buildAlbums()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: widget.actions.map((action) {
        final isAlbum = action.title.toLowerCase().contains("álbum") ||
            action.title.toLowerCase().contains("carpeta");

        final isDanger = action.textColor == AppColors.danger ||
            action.title.toLowerCase().contains("eliminar");
        final primaryColor = isDanger ? AppColors.danger : AppColors.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isDark
                ? const Color(0xFF141722)
                : const Color(0xFFF9FAFD),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (isAlbum) {
                  goToAlbums();
                  return;
                }
                Navigator.pop(context);
                action.onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDanger
                        ? AppColors.danger.withValues(alpha: isDark ? 0.25 : 0.2)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        action.icon,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDanger
                              ? AppColors.danger
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlbums() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (loadingAlbums) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Column(
      children: [
        CustomText(
          text: "Elegir Carpeta / Álbum",
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),

        const SizedBox(height: 12),

        Expanded(
          child: albums.isEmpty
              ? Center(
                  child: CustomText(
                    text: "No tienes carpetas creadas.",
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              : ListView.builder(
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final already = songAlreadyInAlbum(album.id!);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2132)
                            : const Color(0xFFF1F3F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        dense: true,
                        title: CustomText(
                          text: album.titulo,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: already
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                )
                              : theme.colorScheme.onSurface,
                        ),
                        subtitle: already
                            ? CustomText(
                                text: "Ya agregada",
                                fontSize: 11,
                                color: AppColors.primary,
                              )
                            : null,
                        trailing: Checkbox(
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          value: already || selectedAlbums.contains(album.id),
                          onChanged: already
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedAlbums.add(album.id!);
                                    } else {
                                      selectedAlbums.remove(album.id);
                                    }
                                  });
                                },
                        ),
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.1 : 0.12,
                      ),
                    ),
                  ),
                ),
                onPressed: goBack,
                child: Text(
                  "Atrás",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedAlbums.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: selectedAlbums.isEmpty
                    ? null
                    : () async {
                        if (widget.songId == null) return;

                        for (final id in selectedAlbums) {
                          await CancionRepository().asignarAAlbum(
                            widget.songId!,
                            id,
                          );
                        }

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: CustomText(
                  text: "Agregar",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selectedAlbums.isEmpty
                      ? (isDark ? Colors.white30 : Colors.black26)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/favorito.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/dise%C3%B1os/app_dropdown_menu.dart';
import 'package:playerapp1/widgets/dise%C3%B1os/marqueeanimacion.dart';
import 'package:playerapp1/widgets/dise%C3%B1os/showdialog.dart';
import 'package:playerapp1/widgets/dise%C3%B1os/text.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  final FavoritoDao _favoritoDao = FavoritoDao();
  final TextEditingController _searchController = TextEditingController();

  List<Cancion> canciones = [];
  List<Cancion> cancionesFiltradas = [];
  String textoBusqueda = "";
  bool _isLoading = true;
  bool get filtroActivo => textoBusqueda.trim().isNotEmpty;
  int totalCanciones = 0;
  double totalMB = 0;

  @override
  void initState() {
    super.initState();
    cargarFavoritos();
    FavoritosNotifier.instance.addListener(_onFavoritosChanged);
    CancionesNotifier.instance.addListener(_onFavoritosChanged);
  }

  void _onFavoritosChanged() {
    if (!mounted) return;
    cargarFavoritos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    FavoritosNotifier.instance.removeListener(_onFavoritosChanged);
    CancionesNotifier.instance.removeListener(_onFavoritosChanged);
    super.dispose();
  }

  Future<void> cargarFavoritos({bool showLoading = false}) async {
    if (showLoading && canciones.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _favoritoDao.getCancionesFavoritas();

      canciones =
          data
              .map(
                (e) =>
                    Cancion.fromMap({...e, 'posicion': e['fav_posicion'] ?? 0}),
              )
              .toList()
            ..sort((a, b) => a.posicion.compareTo(b.posicion));

      totalCanciones = canciones.length;

      totalMB = canciones.fold(
        0,
        (sum, item) => sum + ((item.tamanoArchivo ?? 0) / (1024 * 1024)),
      );

      if (filtroActivo) {
        cancionesFiltradas = canciones.where((c) {
          return c.titulo.toLowerCase().contains(textoBusqueda.toLowerCase());
        }).toList();
      } else {
        cancionesFiltradas = List.from(canciones);
      }
    } catch (e) {
      debugPrint("Error al cargar favoritos: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void filtrarCanciones(String texto) {
    setState(() {
      textoBusqueda = texto;
      if (texto.trim().isEmpty) {
        cancionesFiltradas = List.from(canciones);
      } else {
        cancionesFiltradas = canciones.where((c) {
          return c.titulo.toLowerCase().contains(texto.toLowerCase());
        }).toList();
      }
    });
  }

  Future eliminarFavorito(int idCancion) async {
    // Actualización inmediata en memoria para CERO parpadeo
    setState(() {
      canciones.removeWhere((c) => c.id == idCancion);
      cancionesFiltradas.removeWhere((c) => c.id == idCancion);
      totalCanciones = canciones.length;
      totalMB = canciones.fold(
        0,
        (sum, item) => sum + ((item.tamanoArchivo ?? 0) / (1024 * 1024)),
      );
    });

    await _favoritoDao.deleteFavoritoByCancion(idCancion);
    FavoritosNotifier.instance.actualizar();
    if (MusicService.instance.context == "favorites") {
      await MusicService.instance.refreshPlaylist(
        canciones,
        context: "favorites",
      );
    }
  }

  void _reproducirTodo({bool aleatorio = false}) async {
    FocusScope.of(context).unfocus();
    if (canciones.isEmpty) return;
    final playlist = List<Cancion>.from(canciones);
    if (aleatorio) {
      playlist.shuffle();
    }
    await MusicService.instance.playPlaylist(playlist, 0, context: "favorites");
  }

  @override
  Widget build(BuildContext context) {
    final hayCanciones = canciones.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ValueListenableBuilder<int?>(
            valueListenable: MusicService.instance.currentSongIdNotifier,
            builder: (context, currentId, _) {
              return _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : !hayCanciones
                  ? _buildEmptyState(context, theme, isDark)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: ReorderableListView.builder(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 120),
                      header: _buildHeader(context, theme, isDark),
                      itemCount: cancionesFiltradas.length,
                      buildDefaultDragHandles: !filtroActivo,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: isDark
                              ? const Color(0xFF1E2132)
                              : Colors.white,
                          elevation: 12,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        );
                      },
                      onReorder: filtroActivo
                          ? (_, _) {}
                          : (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex--;

                              final item = cancionesFiltradas.removeAt(
                                oldIndex,
                              );
                              cancionesFiltradas.insert(newIndex, item);

                              setState(() {
                                canciones = List.from(cancionesFiltradas);
                              });

                              await MusicService.instance.reorderPlaylist(
                                oldIndex,
                                newIndex,
                                context: "favorites",
                              );

                              await _favoritoDao.reordenarFavoritos(
                                cancionesFiltradas.map((c) {
                                  return Favorito(
                                    idCancion: c.id!,
                                    fechaAgregado:
                                        DateTime.now().millisecondsSinceEpoch,
                                  );
                                }).toList(),
                              );
                            },
                      itemBuilder: (context, index) {
                        final c = cancionesFiltradas[index];
                        final isSelected =
                            MusicService.instance.context == "favorites" &&
                            currentId == c.id;
                        final mb = ((c.tamanoArchivo ?? 0) / (1024 * 1024))
                            .toStringAsFixed(1);
                        final extension = c.rutaArchivo.contains('.')
                            ? c.rutaArchivo.split('.').last.toUpperCase()
                            : "AUDIO";

                        return Container(
                          key: ValueKey(c.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? AppColors.accent.withValues(alpha: 0.15)
                                      : AppColors.accent.withValues(
                                          alpha: 0.10,
                                        ))
                                : (isDark
                                      ? const Color(0xFF11131B)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.22 : 0.02,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            onTap: () async {
                              FocusScope.of(context).unfocus();
                              final realIndex = canciones.indexWhere(
                                (e) => e.id == c.id,
                              );
                              if (realIndex == -1) return;

                              await MusicService.instance.playPlaylist(
                                canciones,
                                realIndex,
                                context: "favorites",
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
                                          color: AppColors.accent.withValues(
                                            alpha: 0.2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.graphic_eq_rounded,
                                          color: AppColors.accent,
                                          size: 16,
                                        ),
                                      )
                                    : CustomText(
                                        text: (index + 1).toString().padLeft(
                                          2,
                                          '0',
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                              ),
                            ),
                            title: isSelected
                                ? SongMarqueeTitle(
                                    text: c.titulo,
                                    color: AppColors.accent,
                                  )
                                : CustomText(
                                    text: c.titulo,
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      extension,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CustomText(
                                    text: "$mb MB",
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.favorite_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    if (c.id == null) return;
                                    await eliminarFavorito(c.id!);
                                  },
                                ),
                                AppDropdownMenu<String>(
                                  icon: Icon(
                                    LucideIcons.ellipsisVertical,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                  items: [
                                    AppDropdownItem(
                                      value: "play",
                                      text: "Reproducir",
                                      icon: LucideIcons.play,
                                      iconColor: AppColors.primary,
                                    ),
                                    AppDropdownItem(
                                      value: "next",
                                      text: "Reproducir siguiente",
                                      icon: LucideIcons.listStart,
                                      iconColor: AppColors.primary,
                                    ),
                                    AppDropdownItem(
                                      value: "queue",
                                      text: "Añadir a la cola",
                                      icon: LucideIcons.listPlus,
                                      iconColor: AppColors.primary,
                                    ),
                                    AppDropdownItem(
                                      value: "rename",
                                      text: "Renombrar canción",
                                      icon: LucideIcons.pencil,
                                    ),
                                    AppDropdownItem(
                                      value: "remove_fav",
                                      text: "Quitar de Favoritos",
                                      icon: LucideIcons.heartOff,
                                      isDestructive: true,
                                      isDividerBefore: true,
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value == "play") {
                                      final realIndex = canciones.indexWhere(
                                        (e) => e.id == c.id,
                                      );
                                      if (realIndex == -1) return;
                                      await MusicService.instance.playPlaylist(
                                        canciones,
                                        realIndex,
                                        context: "favorites",
                                      );
                                    } else if (value == "next") {
                                      await MusicService.instance.playNext(c);
                                    } else if (value == "queue") {
                                      await MusicService.instance.addToQueue(c);
                                    } else if (value == "rename") {
                                      final res =
                                          await CustomDialog.showRenameSongDialog(
                                        context: context,
                                        currentTitle: c.titulo,
                                      );
                                      if (res != null &&
                                          res.newTitle.isNotEmpty) {
                                        await CancionRepository().renombrar(
                                          c.id!,
                                          res.newTitle,
                                          renombrarArchivoFisico:
                                              res.renamePhysicalFile,
                                        );
                                        cargarFavoritos();
                                      }
                                    } else if (value == "remove_fav") {
                                      await eliminarFavorito(c.id!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        /// 💖 CABECERA MINIMALISTA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                CustomText(
                  text: "Favoritos",
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomText(
                    text: "$totalCanciones",
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            CustomText(
              text: "${totalMB.toStringAsFixed(1)} MB guardados",
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ],
        ),

        const SizedBox(height: 16),

        /// ⚡ BOTONES DE ACCIÓN RÁPIDA ("Reproducir todo" / "Aleatorio")
        if (canciones.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _reproducirTodo(aleatorio: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.play,
                    size: 16,
                    color: Colors.white,
                  ),
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
          const SizedBox(height: 16),
        ],

        /// 🔍 BARRA DE BÚSQUEDA MINIMALISTA
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141624) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomTextField(
            controller: _searchController,
            onChanged: filtrarCanciones,
            hintText: "Buscar en favoritos...",
            prefixIcon: Icon(
              LucideIcons.search,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            suffixIcon: filtroActivo
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _searchController.clear();
                      filtrarCanciones("");
                    },
                  )
                : null,
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomText(
              text: filtroActivo
                  ? "Resultados en favoritos"
                  : "Pistas destacadas",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            CustomText(
              text: "${cancionesFiltradas.length} pistas",
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.heartHandshake,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            CustomText(
              text: "Sin favoritos aún",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 8),
            CustomText(
              text:
                  "Toca el ícono de corazón en cualquier canción para guardarla en esta lista especial.",
              textAlign: TextAlign.center,
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ],
        ),
      ),
    );
  }
}

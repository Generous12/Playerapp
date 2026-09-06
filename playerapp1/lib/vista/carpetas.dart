import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/vista/carpetadetalle.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/widgets/diseños/app_dropdown_menu.dart';
import 'package:playerapp1/widgets/diseños/modalcrearcarpeta.dart';
import 'package:playerapp1/widgets/diseños/pattern_background.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  List<Album> albums = [];
  Map<int, int> albumSongCounts = {};
  Map<int, double> albumSongSizesMB = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isGridView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    CancionesNotifier.instance.addListener(_onSongsChanged);
  }

  void _onSongsChanged() {
    if (mounted) _loadAlbums();
  }

  @override
  void dispose() {
    _searchController.dispose();
    CancionesNotifier.instance.removeListener(_onSongsChanged);
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    try {
      final data = await Album.getAll();
      final db = await DatabaseHelper.instance.database;
      final Map<int, int> counts = {};
      final Map<int, double> sizes = {};

      final countResults = await db.rawQuery(
        'SELECT id_album, COUNT(*) as total, SUM(tamano_archivo) as totalSize FROM canciones WHERE id_album IS NOT NULL GROUP BY id_album',
      );

      for (final row in countResults) {
        final albumId = row['id_album'] as int?;
        final total = row['total'] as int?;
        final sizeBytes = (row['totalSize'] as num?)?.toDouble() ?? 0.0;
        if (albumId != null) {
          counts[albumId] = total ?? 0;
          sizes[albumId] = sizeBytes / (1024 * 1024);
        }
      }

      if (!mounted) return;
      setState(() {
        albums = data;
        albumSongCounts = counts;
        albumSongSizesMB = sizes;
      });
    } catch (e) {
      debugPrint("Error al cargar álbumes: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Album> get _filteredAlbums {
    if (_searchQuery.trim().isEmpty) return albums;
    final q = _searchQuery.trim().toLowerCase();
    return albums.where((a) => a.titulo.toLowerCase().contains(q)).toList();
  }

  void _mostrarCrearAlbum(BuildContext context) {
    CreateAlbumModal.show(
      context: context,
      title: "Nueva Carpeta",
      hintText: "Nombre de la carpeta",
      buttonColor: AppColors.primary,
      onCreate: (album) async {
        await Album.create(album);
        await _loadAlbums();
      },
    );
  }

  Future<void> _editarNombreAlbum(Album album) async {
    if (album.id == null) return;
    final controller = TextEditingController(text: album.titulo);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nuevoNombre = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isSmallDevice = MediaQuery.of(ctx).size.width < 360;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141624) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.1 : 0.05,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.penLine,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomText(
                      text: "Renombrar carpeta",
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: isSmallDevice ? 14 : 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: "Nuevo nombre de carpeta",
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: CustomText(
                          text: "Cancelar",
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () =>
                            Navigator.pop(ctx, controller.text.trim()),
                        child: const Text(
                          "Guardar",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
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

    if (nuevoNombre != null &&
        nuevoNombre.isNotEmpty &&
        nuevoNombre != album.titulo) {
      await Album.updateTitle(album.id!, nuevoNombre);
      await _loadAlbums();
    }
  }

  Future<void> _eliminarAlbum(Album album) async {
    final confirm = await CustomDialog.show(
      context: context,
      title: "Eliminar Carpeta",
      message:
          "¿Deseas eliminar la carpeta '${album.titulo}'? Las canciones no se borrarán de tu biblioteca.",
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

  Future<void> _reproducirCarpetaDirecta(Album album, {bool aleatorio = false}) async {
    if (album.id == null) return;
    final repo = CancionRepository();
    final songs = await repo.obtenerPorAlbum(album.id!);
    if (songs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Esta carpeta no tiene canciones aún"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final playlist = List<Cancion>.from(songs);
    if (aleatorio) {
      playlist.shuffle();
    }

    await MusicService.instance.playPlaylist(
      playlist,
      0,
      context: "album_${album.id}",
    );
  }

  static final List<AppDropdownItem<String>> _folderDropdownItems = [
    AppDropdownItem(
      value: "play",
      text: "Reproducir todo",
      icon: LucideIcons.play,
      iconColor: AppColors.primary,
    ),
    AppDropdownItem(
      value: "shuffle",
      text: "Reproducir en aleatorio",
      icon: LucideIcons.shuffle,
      iconColor: AppColors.accent,
    ),
    AppDropdownItem(
      value: "rename",
      text: "Renombrar carpeta",
      icon: LucideIcons.pencil,
    ),
    AppDropdownItem(
      value: "delete",
      text: "Eliminar carpeta",
      icon: LucideIcons.trash2,
      isDestructive: true,
      isDividerBefore: true,
    ),
  ];

  void _onFolderOptionSelected(Album album, String value) {
    if (value == "play") {
      _reproducirCarpetaDirecta(album, aleatorio: false);
    } else if (value == "shuffle") {
      _reproducirCarpetaDirecta(album, aleatorio: true);
    } else if (value == "rename") {
      _editarNombreAlbum(album);
    } else if (value == "delete") {
      _eliminarAlbum(album);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isSmallDevice = screenSize.width < 360 || screenSize.height < 680;
    final horizontalPadding = (screenSize.width * 0.04).clamp(12.0, 18.0);
    final filtered = _filteredAlbums;

    return PatternBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isSmallDevice ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔝 CABECERA MODERNA CON CONTADOR Y BOTÓN NUEVA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CustomText(
                            text: "Carpetas",
                            fontSize: isSmallDevice ? 24 : 26,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.20),
                                  AppColors.accent.withValues(alpha: 0.12),
                                ],
                              ),
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
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _mostrarCrearAlbum(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallDevice ? 12 : 16,
                            vertical: isSmallDevice ? 8 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          LucideIcons.folderPlus,
                          color: Colors.white,
                          size: isSmallDevice ? 16 : 18,
                        ),
                        label: CustomText(
                          text: "Nueva",
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallDevice ? 12.5 : 13.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  CustomText(
                    text: "Tus álbumes y colecciones organizadas localmente.",
                    fontSize: isSmallDevice ? 11 : 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),

                  SizedBox(height: isSmallDevice ? 10 : 14),

                  /// 🔍 BARRA DE BÚSQUEDA Y SELECTOR DE VISTA (GRID / LIST)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141624) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onTapOutside: (_) => FocusScope.of(context).unfocus(),
                            onSubmitted: (_) => FocusScope.of(context).unfocus(),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Buscar carpetas...",
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              prefixIcon: Icon(
                                LucideIcons.search,
                                size: 17,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = "";
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141624) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isGridView ? LucideIcons.layoutGrid : LucideIcons.list,
                          size: 19,
                          color: AppColors.primary,
                        ),
                        tooltip: _isGridView ? "Vista Cuadrícula" : "Vista Lista",
                        onPressed: () {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallDevice ? 12 : 16),

                /// 📂 CONTENEDOR DE CARPETAS (GRID O LISTA)
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : albums.isEmpty
                          ? _buildEmptyCarpetas(context, theme, isDark, isSmallDevice)
                          : filtered.isEmpty
                              ? Center(
                                  child: CustomText(
                                    text: "No se encontraron carpetas con '$_searchQuery'",
                                    fontSize: 13,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                )
                              : AnimatedBuilder(
                                  animation: MusicService.instance,
                                  builder: (context, _) {
                                    final musicService = MusicService.instance;
                                    final currentSong = musicService.currentSong;

                                    if (_isGridView) {
                                      return _buildGridView(
                                        filtered,
                                        musicService,
                                        currentSong,
                                        theme,
                                        isDark,
                                        isSmallDevice,
                                      );
                                    } else {
                                      return _buildListView(
                                        filtered,
                                        musicService,
                                        currentSong,
                                        theme,
                                        isDark,
                                        isSmallDevice,
                                      );
                                    }
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  /// 🔲 VISTA EN CUADRÍCULA MODERNA (GRID)
  Widget _buildGridView(
    List<Album> list,
    MusicService musicService,
    Cancion? currentSong,
    ThemeData theme,
    bool isDark,
    bool isSmallDevice,
  ) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 110),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final album = list[index];
        final songCount = albumSongCounts[album.id] ?? 0;
        final sizeMB = (albumSongSizesMB[album.id] ?? 0.0).toStringAsFixed(1);
        final isPlayingThisFolder =
            musicService.context == "album_${album.id}" &&
            currentSong != null &&
            currentSong.idAlbum == album.id;

        return Container(
          decoration: BoxDecoration(
            color: isPlayingThisFolder
                ? AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.09)
                : (isDark ? const Color(0xFF131525) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPlayingThisFolder
                  ? AppColors.primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05)),
              width: isPlayingThisFolder ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isPlayingThisFolder
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
                blurRadius: isPlayingThisFolder ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(album: album),
                  ),
                ).then((_) => _loadAlbums());
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada de Carpeta con Badge
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPlayingThisFolder
                                    ? [
                                        AppColors.primary,
                                        AppColors.accent.withValues(alpha: 0.8),
                                      ]
                                    : [
                                        isDark
                                            ? const Color(0xFF1C1F33)
                                            : const Color(0xFFF1F4FA),
                                        isDark
                                            ? const Color(0xFF151726)
                                            : const Color(0xFFE5EAF3),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Icon(
                                isPlayingThisFolder
                                    ? LucideIcons.disc3
                                    : LucideIcons.folder,
                                size: isSmallDevice ? 34 : 40,
                                color: isPlayingThisFolder
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          // Badge de Conteo de Pistas
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: (isPlayingThisFolder
                                        ? Colors.black
                                        : (isDark ? Colors.black : Colors.white))
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "$songCount pistas",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isPlayingThisFolder
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          // Botón de 3 puntos
                          Positioned(
                            top: 2,
                            right: 2,
                            child: AppDropdownMenu<String>(
                              padding: EdgeInsets.zero,
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.ellipsisVertical,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              items: _folderDropdownItems,
                              onSelected: (val) =>
                                  _onFolderOptionSelected(album, val),
                            ),
                          ),
                          // Si está sonando, indicador ecualizador
                          if (isPlayingThisFolder)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  musicService.isPlaying
                                      ? Icons.graphic_eq_rounded
                                      : LucideIcons.play,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Título de la Carpeta
                    CustomText(
                      text: album.titulo,
                      fontSize: isSmallDevice ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: isPlayingThisFolder
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Subtítulo con MB y Pistas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomText(
                          text: "$sizeMB MB",
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        if (isPlayingThisFolder)
                          Text(
                            "EN PLAY",
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
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
  }

  /// 📋 VISTA EN LISTA ELEGANTE (LIST)
  Widget _buildListView(
    List<Album> list,
    MusicService musicService,
    Cancion? currentSong,
    ThemeData theme,
    bool isDark,
    bool isSmallDevice,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 110),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final album = list[index];
        final songCount = albumSongCounts[album.id] ?? 0;
        final sizeMB = (albumSongSizesMB[album.id] ?? 0.0).toStringAsFixed(1);
        final isPlayingThisFolder =
            musicService.context == "album_${album.id}" &&
            currentSong != null &&
            currentSong.idAlbum == album.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPlayingThisFolder
                ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                : (isDark ? const Color(0xFF131525) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPlayingThisFolder
                  ? AppColors.primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06)),
              width: isPlayingThisFolder ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isPlayingThisFolder
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
                blurRadius: isPlayingThisFolder ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(album: album),
                ),
              ).then((_) => _loadAlbums());
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPlayingThisFolder
                      ? [AppColors.primary, AppColors.accent]
                      : [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isPlayingThisFolder ? LucideIcons.disc3 : LucideIcons.folder,
                color: isPlayingThisFolder ? Colors.white : AppColors.primary,
                size: isSmallDevice ? 20 : 22,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: CustomText(
                    text: album.titulo,
                    fontSize: isSmallDevice ? 13.5 : 14.5,
                    fontWeight: FontWeight.bold,
                    color: isPlayingThisFolder
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPlayingThisFolder) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "EN PLAY",
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: CustomText(
              text: isPlayingThisFolder
                  ? "Sonando: ${currentSong.titulo}"
                  : "$songCount canciones • $sizeMB MB",
              fontSize: isSmallDevice ? 10.5 : 11.5,
              color: isPlayingThisFolder
                  ? AppColors.primary
                  : (isDark ? Colors.white54 : Colors.black45),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdownMenu<String>(
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    size: isSmallDevice ? 16 : 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  items: _folderDropdownItems,
                  onSelected: (val) => _onFolderOptionSelected(album, val),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  size: isSmallDevice ? 18 : 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🌟 ESTADO VACÍO ELEGANTE
  Widget _buildEmptyCarpetas(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isSmallDevice,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0.10),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  LucideIcons.folderClosed,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomText(
              text: "No tienes carpetas creadas",
              fontSize: isSmallDevice ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: CustomText(
                text:
                    "Crea carpetas para agrupar tus pistas o impórtalas directamente desde tus carpetas de música.",
                textAlign: TextAlign.center,
                fontSize: isSmallDevice ? 11.5 : 12.5,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _mostrarCrearAlbum(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.plus, size: 17, color: Colors.white),
              label: const Text(
                "Crear Primera Carpeta",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

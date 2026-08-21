import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/favorito.dart';
import 'package:playerapp1/clases/historial.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/services/permissioservice.dart';
import 'package:playerapp1/widgets/diseños/ai_dj_dialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';
import 'package:playerapp1/widgets/pantallas/itembuilder_inicio.dart';

class InicioScreen extends StatefulWidget {
  final Function(bool)? onImportandoChanged;

  const InicioScreen({super.key, this.onImportandoChanged});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final CancionRepository _repo = CancionRepository();
  final FavoritoDao _favoritoDao = FavoritoDao();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  String textoBusqueda = "";
  bool get filtroActivo => textoBusqueda.trim().isNotEmpty;
  Set<int> favoritosIds = {};
  List<Cancion> canciones = [];
  List<Cancion> cancionesFiltradas = [];
  List<Cancion> cancionesMasReproducidas = [];
  int totalCanciones = 0;
  double totalMB = 0;
  bool _isLoading = true;

  static const List<String> extensionesAudio = [
    '.mp3',
    '.wav',
    '.flac',
    '.aac',
    '.m4a',
    '.ogg',
    '.opus',
    '.wma',
    '.amr',
    '.3gp',
  ];

  @override
  void initState() {
    super.initState();
    cargarDatos();
    cargarFavoritos();
    CancionesNotifier.instance.addListener(_onCancionesChanged);
    FavoritosNotifier.instance.addListener(_onFavoritosChanged);
    MusicService.instance.currentSongIdNotifier.addListener(
      _onCurrentSongChanged,
    );
  }

  void _onCancionesChanged() {
    if (!mounted) return;
    cargarDatos();
  }

  void _onFavoritosChanged() {
    if (!mounted) return;
    cargarFavoritos();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    CancionesNotifier.instance.removeListener(_onCancionesChanged);
    FavoritosNotifier.instance.removeListener(_onFavoritosChanged);
    MusicService.instance.currentSongIdNotifier.removeListener(
      _onCurrentSongChanged,
    );
    super.dispose();
  }

  void _onCurrentSongChanged() {
    if (!mounted) return;
    cargarMasReproducidas().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> asignarCancionAAlbum(int songId, int albumId) async {
    final cancionesAlbum = await _repo.obtenerPorAlbum(albumId);
    final existe = cancionesAlbum.any((c) => c.id == songId);

    if (existe) {
      return;
    }

    await _repo.asignarAAlbum(songId, albumId);
  }

  Future<void> cargarFavoritos() async {
    final favs = await _favoritoDao.getFavoritos();
    if (!mounted) return;
    setState(() {
      favoritosIds = favs.map<int>((f) => f.idCancion).toSet();
    });
  }

  Future<void> cargarDatos() async {
    if (!mounted) return;
    if (canciones.isEmpty) {
      setState(() => _isLoading = true);
    }

    await Future.wait([
      cargarCanciones(),
      cargarEstadisticas(),
      cargarMasReproducidas(),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> cargarMasReproducidas() async {
    final HistorialDao histDao = HistorialDao();
    final data = await histDao.getMasReproducidas(4);
    if (data.isNotEmpty) {
      cancionesMasReproducidas = data.map((e) => Cancion.fromMap(e)).toList();
    } else {
      cancionesMasReproducidas = canciones.take(4).toList();
    }
  }

  Future<void> cargarCanciones() async {
    canciones = await _repo.obtenerTodas();
    cancionesFiltradas = List.from(canciones);
  }

  void filtrarCanciones(String value) {
    textoBusqueda = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final q = value.trim().toLowerCase();
      setState(() {
        if (q.isEmpty) {
          cancionesFiltradas = List.from(canciones);
        } else {
          cancionesFiltradas = canciones.where((c) {
            final t = c.titulo.toLowerCase();
            final path = c.rutaArchivo.toLowerCase();
            return t.contains(q) || path.contains(q);
          }).toList();
        }
      });
    });
  }

  Future<void> cargarEstadisticas() async {
    totalCanciones = await _repo.contarCanciones();
    totalMB = await _repo.obtenerTamanoTotalMB();
  }

  Future<void> importarArchivos() async {
    widget.onImportandoChanged?.call(true);
    await Future.delayed(const Duration(milliseconds: 30));

    try {
      final permitido = await PermissionService.solicitarPermisosAudio();
      if (!permitido) return;

      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: extensionesAudio
            .map((e) => e.replaceAll('.', ''))
            .toList(),
      );

      if (result == null || result.files.isEmpty) return;

      final listaActual = await _repo.obtenerTodas();
      int basePos = listaActual.length;
      final List<Cancion> cancionesNuevas = [];

      for (final file in result.files) {
        final ruta = file.path;
        if (ruta == null) continue;

        // Validación de seguridad: existencia física y lista blanca de extensiones
        final f = File(ruta);
        if (!f.existsSync()) continue;

        final ext = ruta.split('.').last.toLowerCase();
        const allowed = ['mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus'];
        if (!allowed.contains(ext)) continue;

        final existe = await _repo.existeRuta(ruta);
        if (existe) continue;

        cancionesNuevas.add(
          Cancion(
            titulo: file.name,
            duracion: 0,
            rutaArchivo: ruta,
            tamanoArchivo: file.size,
            fechaAgregado: DateTime.now().millisecondsSinceEpoch,
            posicion: basePos++,
          ),
        );
      }

      if (cancionesNuevas.isNotEmpty) {
        await _repo.insertarBatch(cancionesNuevas);
        final nuevaLista = await _repo.obtenerTodas();
        await MusicService.instance.refreshPlaylist(nuevaLista);
      }
    } finally {
      if (mounted) {
        widget.onImportandoChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hayCanciones = canciones.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : !hayCanciones
            ? _buildEmptyState(context, theme, isDark)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  header: _buildHeader(context, theme, isDark),
                  itemCount: cancionesFiltradas.length,
                  buildDefaultDragHandles: !filtroActivo,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: isDark ? const Color(0xFF1E2132) : Colors.white,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    );
                  },
                  onReorder: filtroActivo
                      ? (_, _) {}
                      : (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) {
                            newIndex--;
                          }
                          final item = cancionesFiltradas.removeAt(oldIndex);
                          cancionesFiltradas.insert(newIndex, item);
                          setState(() {
                            canciones = List.from(cancionesFiltradas);
                          });
                          await MusicService.instance.reorderPlaylist(
                            oldIndex,
                            newIndex,
                            context: "general",
                          );
                          await _repo.reordenar(canciones);
                        },
                  itemBuilder: (context, index) {
                    final c = cancionesFiltradas[index];

                    return SongTile(
                      key: ValueKey(c.id),
                      cancion: c,
                      index: index,
                      canciones: canciones,
                      cancionesFiltradas: cancionesFiltradas,
                      favoritosIds: favoritosIds,
                      favoritoDao: _favoritoDao,
                      repo: _repo,
                      onAsignarCancionAAlbum: asignarCancionAAlbum,
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
    final quickTracks = cancionesMasReproducidas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        /// 👑 CABECERA MINIMALISTA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomText(
                      text: "Biblioteca",
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
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.accent.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomText(
                        text: "$totalCanciones",
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                CustomText(
                  text: "${totalMB.toStringAsFixed(1)} MB en tu dispositivo",
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ],
            ),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    AIDJModal.show(context, canciones);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
                            size: 13,
                            color: Color(0xFF08090D),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "DJ IA",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF08090D),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: importarArchivos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF1E2232)
                        : const Color(0xFFF1F4F9),
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    LucideIcons.plus,
                    size: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  label: CustomText(
                    text: "Importar",
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

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
          child: TextField(
            controller: _searchController,
            onChanged: filtrarCanciones,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Buscar por título o artista...",
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                LucideIcons.search,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              suffixIcon: filtroActivo
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        filtrarCanciones("");
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        /// ⚡ PISTAS RÁPIDAS (Quick Access Mix)
        if (!filtroActivo && quickTracks.isNotEmpty) ...[
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              CustomText(
                text: "Escuchado Reciente",
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quickTracks.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 60,
            ),
            itemBuilder: (context, index) {
              final track = quickTracks[index];
              return ValueListenableBuilder<int?>(
                valueListenable: MusicService.instance.currentSongIdNotifier,
                builder: (context, currentId, _) {
                  final isSelected = currentId == track.id;
                  return GestureDetector(
                    onTap: () async {
                      final realIndex = canciones.indexWhere(
                        (e) => e.id == track.id,
                      );
                      if (realIndex != -1) {
                        await MusicService.instance.playPlaylist(
                          canciones,
                          realIndex,
                          context: "general",
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.20 : 0.12,
                              )
                            : isDark
                            ? const Color(0xFF11131B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.22 : 0.03,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [AppColors.primary, AppColors.accent]
                                    : [
                                        AppColors.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                        AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                      ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.graphic_eq_rounded
                                  : LucideIcons.play,
                              color: isSelected
                                  ? const Color(0xFF08090D)
                                  : AppColors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomText(
                                  text: track.titulo,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(height: 2),
                                CustomText(
                                  text: "Pista ${index + 1}",
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 22),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomText(
              text: filtroActivo
                  ? "Resultados de búsqueda"
                  : "Todas las canciones",
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  LucideIcons.music4,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomText(
              text: "Tu biblioteca está vacía",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 8),
            CustomText(
              text:
                  "Importa archivos locales de música (MP3, FLAC, WAV, M4A) para comenzar a escuchar.",
              textAlign: TextAlign.center,
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: importarArchivos,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                LucideIcons.folderDown,
                color: Colors.white,
                size: 18,
              ),
              label: const CustomText(
                text: "Importar canciones",
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/favorito.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/vista/importar.dart';
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
  int totalCanciones = 0;
  double totalMB = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
    cargarFavoritos();
    CancionesNotifier.instance.addListener(_onCancionesChanged);
    FavoritosNotifier.instance.addListener(_onFavoritosChanged);
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
    super.dispose();
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

    try {
      await Future.wait([
        cargarCanciones(),
        cargarEstadisticas(),
      ]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
    } catch (e) {
      debugPrint("Error al cargar datos en InicioScreen: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hayCanciones = canciones.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
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
          child: CustomTextField(
            controller: _searchController,
            onChanged: filtrarCanciones,
            hintText: "Buscar por título o artista...",
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
          ),
        ),

        const SizedBox(height: 16),

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

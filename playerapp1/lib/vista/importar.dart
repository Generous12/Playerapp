import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:playerapp1/services/permissioservice.dart';
import 'package:playerapp1/widgets/diseños/marqueeanimacion.dart';
import 'package:playerapp1/widgets/diseños/modalcrearcarpeta.dart';
import 'package:playerapp1/widgets/diseños/overlaydecarga.dart';
import 'package:playerapp1/widgets/diseños/pattern_background.dart';
import 'package:playerapp1/widgets/diseños/showdialog.dart';
import 'package:playerapp1/widgets/diseños/text.dart';
import 'package:sqflite/sqflite.dart';

class ImportItem {
  final String path;
  String title;
  final int size;
  bool isSelected;
  String? folderName; // null = Canción suelta

  ImportItem({
    required this.path,
    required this.title,
    required this.size,
    this.folderName,
    this.isSelected = true,
  });
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final CancionRepository _repo = CancionRepository();
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _searchFilterController = TextEditingController();
  final List<ImportItem> _items = [];
  final Set<String> _expandedFolders = {};
  bool _looseExpanded = true;
  String _filterQuery = "";

  bool _isScanning = false;
  bool _isImporting = false;

  static const allowedExts = [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
  ];

  @override
  void dispose() {
    _folderNameController.dispose();
    _searchFilterController.dispose();
    super.dispose();
  }

  bool get _allSelected =>
      _items.isNotEmpty && _items.every((i) => i.isSelected);

  int get _selectedCount => _items.where((i) => i.isSelected).length;

  int get _selectedTotalBytes =>
      _items.where((i) => i.isSelected).fold(0, (sum, item) => sum + item.size);

  List<ImportItem> get _filteredItems {
    if (_filterQuery.trim().isEmpty) return _items;
    final q = _filterQuery.trim().toLowerCase();
    return _items.where((i) {
      return i.title.toLowerCase().contains(q) ||
          (i.folderName != null && i.folderName!.toLowerCase().contains(q)) ||
          i.path.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, List<ImportItem>> get _groupedFolders {
    final Map<String, List<ImportItem>> groups = {};
    final list = _filteredItems;
    for (var item in list) {
      if (item.folderName != null && item.folderName!.trim().isNotEmpty) {
        groups.putIfAbsent(item.folderName!.trim(), () => []).add(item);
      }
    }
    return groups;
  }

  List<ImportItem> get _looseItems {
    return _filteredItems
        .where((i) => i.folderName == null || i.folderName!.trim().isEmpty)
        .toList();
  }

  void _toggleSelectAll() {
    final targetState = !_allSelected;
    setState(() {
      for (var item in _items) {
        item.isSelected = targetState;
      }
    });
  }

  void _toggleSelectFolder(String folderName) {
    final folderItems = _items
        .where((i) => i.folderName == folderName)
        .toList();
    final allSelected = folderItems.every((i) => i.isSelected);
    setState(() {
      for (var item in folderItems) {
        item.isSelected = !allSelected;
      }
    });
  }

  void _toggleSelectLoose() {
    final loose = _items
        .where((i) => i.folderName == null || i.folderName!.trim().isEmpty)
        .toList();
    final allSelected = loose.every((i) => i.isSelected);
    setState(() {
      for (var item in loose) {
        item.isSelected = !allSelected;
      }
    });
  }

  void _eliminarCarpeta(String folderName) {
    setState(() {
      _items.removeWhere((i) => i.folderName == folderName);
      _expandedFolders.remove(folderName);
    });
  }

  void _toggleFolderExpanded(String folderName) {
    setState(() {
      if (_expandedFolders.contains(folderName)) {
        _expandedFolders.remove(folderName);
      } else {
        _expandedFolders.add(folderName);
      }
    });
  }

  void _limpiarTodo() async {
    if (_items.isEmpty) return;
    final confirm = await CustomDialog.show(
      context: context,
      title: "Limpiar Lista",
      message:
          "¿Deseas remover todas las pistas escaneadas de la lista de importación?",
      confirmText: "Limpiar",
      cancelText: "Cancelar",
      confirmButtonColor: AppColors.danger,
    );

    if (confirm == true && mounted) {
      setState(() {
        _items.clear();
        _expandedFolders.clear();
        _filterQuery = "";
        _searchFilterController.clear();
      });
    }
  }

  /// SELECCIONAR ARCHIVOS INDIVIDUALES O MÚLTIPLES
  Future<void> _seleccionarArchivos() async {
    final permitido = await PermissionService.solicitarPermisosAudio();
    if (!permitido) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: allowedExts,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final rutasExistentes = await _repo.obtenerRutasExistentesSet();
      int agregadas = 0;

      for (final file in result.files) {
        final ruta = file.path;
        if (ruta == null) continue;

        final f = File(ruta);
        if (!f.existsSync()) continue;

        final ext = ruta.split('.').last.toLowerCase();
        if (!allowedExts.contains(ext)) continue;

        if (rutasExistentes.contains(ruta)) continue;
        if (_items.any((item) => item.path == ruta)) continue;

        _items.add(
          ImportItem(
            path: ruta,
            title: p.basenameWithoutExtension(file.name),
            size: file.size,
            folderName: null,
          ),
        );
        agregadas++;
      }

      if (mounted && agregadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$agregadas pistas agregadas a la vista previa"),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error al seleccionar archivos: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  /// ESCANEAR CARPETA RECURSIVA
  Future<void> _seleccionarCarpeta() async {
    final permitido = await PermissionService.solicitarPermisosAudio();
    if (!permitido) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final dirName = p.basename(selectedDirectory);

      final dir = Directory(selectedDirectory);
      if (!await dir.exists()) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final rutasExistentes = await _repo.obtenerRutasExistentesSet();

      final List<FileSystemEntity> entities = await dir
          .list(recursive: true, followLinks: false)
          .toList();

      int agregadas = 0;
      for (final entity in entities) {
        if (entity is File) {
          final ruta = entity.path;
          final ext = p.extension(ruta).replaceAll('.', '').toLowerCase();

          if (!allowedExts.contains(ext)) continue;
          if (rutasExistentes.contains(ruta)) continue;
          if (_items.any((item) => item.path == ruta)) continue;

          int size = 0;
          try {
            size = entity.lengthSync();
          } catch (_) {}

          final title = p.basenameWithoutExtension(ruta);
          final parentDir = p.basename(p.dirname(ruta));

          final itemFolderName =
              (parentDir.isNotEmpty && parentDir != '.' && parentDir != dirName)
              ? parentDir
              : dirName;

          _items.add(
            ImportItem(
              path: ruta,
              title: title,
              size: size,
              folderName: itemFolderName,
            ),
          );
          _expandedFolders.add(itemFolderName);
          agregadas++;
        }
      }

      if (mounted && agregadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$agregadas pistas encontradas en '$dirName'"),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error al escanear carpeta: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  /// EDITAR NOMBRE DE CARPETA
  void _editarNombreCarpeta(String oldFolderName) async {
    final controller = TextEditingController(text: oldFolderName);
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
                        LucideIcons.folderPen,
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
                    labelText: "Nombre de la carpeta",
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
        nuevoNombre != oldFolderName) {
      setState(() {
        for (var item in _items) {
          if (item.folderName == oldFolderName) {
            item.folderName = nuevoNombre;
          }
        }
        if (_expandedFolders.contains(oldFolderName)) {
          _expandedFolders.remove(oldFolderName);
          _expandedFolders.add(nuevoNombre);
        }
      });
    }
  }

  /// ASIGNAR CARPETA A CANCIONES SUELTAS
  void _asignarCarpetaACancionesSueltas() {
    CreateAlbumModal.show(
      context: context,
      title: "Asignar Carpeta",
      hintText: "Nombre para agrupar canciones",
      buttonColor: AppColors.primary,
      onCreate: (album) async {
        setState(() {
          for (var item in _items) {
            if (item.folderName == null || item.folderName!.trim().isEmpty) {
              item.folderName = album.titulo;
            }
          }
          _expandedFolders.add(album.titulo);
        });
      },
    );
  }

  /// EDITAR NOMBRE DE PISTA INDIVIDUAL
  void _editarNombreItem(ImportItem item) async {
    final controller = TextEditingController(text: item.title);
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
                      text: "Editar título de canción",
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
                    labelText: "Título de la canción",
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

    if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
      setState(() {
        item.title = nuevoNombre;
      });
    }
  }

  /// INSERCIÓN MASIVA EN SQLITE Y ACTUALIZACIÓN EN SEGUNDO PLANO
  Future<void> _ejecutarImportacion() async {
    final seleccionadas = _items.where((i) => i.isSelected).toList();
    if (seleccionadas.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final globalFolder = _folderNameController.text.trim();

      // 1. Cargar álbumes existentes en memoria
      final existingAlbums = await Album.getAll();
      final Map<String, int> albumMap = {};
      for (final a in existingAlbums) {
        if (a.id != null) {
          albumMap[a.titulo.trim().toLowerCase()] = a.id!;
        }
      }

      Future<int?> getOrCreateAlbumId(String? name) async {
        if (name == null || name.trim().isEmpty) return null;
        final cleanName = name.trim();
        final key = cleanName.toLowerCase();
        if (albumMap.containsKey(key)) {
          return albumMap[key];
        }
        final newId = await Album.create(Album(titulo: cleanName));
        albumMap[key] = newId;
        return newId;
      }

      // 2. Obtener posición base máxima
      final db = await DatabaseHelper.instance.database;
      final maxResult = await db.rawQuery(
        'SELECT MAX(posicion) as maxPos FROM canciones',
      );
      int basePos = (Sqflite.firstIntValue(maxResult) ?? -1) + 1;

      // 3. Crear lista de canciones en memoria
      final List<Cancion> cancionesNuevas = [];
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final item in seleccionadas) {
        final targetFolderName = globalFolder.isNotEmpty
            ? globalFolder
            : item.folderName;

        final albumId = await getOrCreateAlbumId(targetFolderName);

        cancionesNuevas.add(
          Cancion(
            titulo: item.title,
            duracion: 0,
            rutaArchivo: item.path,
            tamanoArchivo: item.size,
            fechaAgregado: now,
            idAlbum: albumId,
            posicion: basePos++,
          ),
        );
      }

      // 4. Inserción atómica masiva en SQLite
      if (cancionesNuevas.isNotEmpty) {
        await _repo.insertarBatch(cancionesNuevas);
        CancionesNotifier.instance.actualizar();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "¡${cancionesNuevas.length} canciones importadas con éxito!",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 5. Refrescar servicio de reproductor en segundo plano
      _repo.obtenerTodas().then((nuevaLista) {
        MusicService.instance.refreshPlaylist(nuevaLista);
      });
    } catch (e) {
      debugPrint("Error al importar canciones: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenSize = MediaQuery.of(context).size;
    final isSmallDevice = screenSize.width < 360 || screenSize.height < 680;
    final horizontalPadding = (screenSize.width * 0.04).clamp(12.0, 18.0);
    final totalMB = (_selectedTotalBytes / (1024 * 1024)).toStringAsFixed(1);

    final groups = _groupedFolders;
    final looseList = _looseItems;
    final folderCount = groups.keys.length;

    final cardBgColor = isDark ? const Color(0xFF131522) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    final isBusy = _isScanning || _isImporting;

    return PopScope(
      canPop: !isBusy,
      child: PatternBackground(
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    LucideIcons.arrowLeft,
                    color: theme.colorScheme.onSurface,
                    size: isSmallDevice ? 20 : 22,
                  ),
                  onPressed: isBusy ? null : () => Navigator.pop(context),
                ),
                title: CustomText(
                  text: "Importar Música",
                  fontSize: isSmallDevice ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
                centerTitle: true,
                actions: [
                  if (_items.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        LucideIcons.trash2,
                        size: 19,
                        color: isBusy
                            ? Colors.grey
                            : AppColors.danger.withValues(alpha: 0.85),
                      ),
                      tooltip: "Limpiar lista",
                      onPressed: isBusy ? null : _limpiarTodo,
                    ),
                  const SizedBox(width: 6),
                ],
              ),
              body: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 TARJETAS HERO PARA SELECCIÓN DE ARCHIVOS Y CARPETAS
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isSmallDevice ? 4.0 : 8.0,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildActionHeroCard(
                                  title: "Elegir Archivos",
                                  subtitle: "Pistas sueltas",
                                  icon: LucideIcons.fileMusic,
                                  isPrimary: false,
                                  isDark: isDark,
                                  theme: theme,
                                  isSmallDevice: isSmallDevice,
                                  onTap: isBusy ? null : () {
                                    FocusScope.of(context).unfocus();
                                    _seleccionarArchivos();
                                  },
                                ),
                              ),
                              SizedBox(width: isSmallDevice ? 8 : 12),
                              Expanded(
                                child: _buildActionHeroCard(
                                  title: "Agregar Carpeta",
                                  subtitle: "Escanear álbum",
                                  icon: LucideIcons.folderInput,
                                  isPrimary: true,
                                  isDark: isDark,
                                  theme: theme,
                                  isSmallDevice: isSmallDevice,
                                  onTap: isBusy ? null : () {
                                    FocusScope.of(context).unfocus();
                                    _seleccionarCarpeta();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallDevice ? 6 : 10),

                      // 🔍 BARRA DE BÚSQUEDA / FILTRO (VISIBLE SI HAY CANCIONES)
                      if (_items.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 4,
                          ),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF131524)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: TextField(
                              controller: _searchFilterController,
                              textInputAction: TextInputAction.search,
                              onTapOutside: (_) => FocusScope.of(context).unfocus(),
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _filterQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Buscar pista en vista previa...",
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                prefixIcon: Icon(
                                  LucideIcons.search,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                                suffixIcon: _filterQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          FocusScope.of(context).unfocus();
                                          _searchFilterController.clear();
                                          setState(() {
                                            _filterQuery = "";
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),

                    // 📊 CABECERA DE ESTADÍSTICAS Y ACCIONES POR LOTE
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(
                                text: _items.isEmpty
                                    ? "Vista Previa"
                                    : "Pistas Escaneadas (${_items.length})",
                                fontSize: isSmallDevice ? 13.5 : 14.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 2),
                              CustomText(
                                text: _items.isEmpty
                                    ? "Ningún archivo cargado aún"
                                    : "$_selectedCount activas • $totalMB MB ${folderCount > 0 ? "• $folderCount carpetas" : ""}",
                                fontSize: isSmallDevice ? 10.5 : 11.5,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ],
                          ),
                          if (_items.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: isBusy ? null : _toggleSelectAll,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _allSelected
                                              ? LucideIcons.checkSquare
                                              : LucideIcons.square,
                                          size: isSmallDevice ? 13 : 15,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        CustomText(
                                          text: _allSelected
                                              ? "Desmarcar"
                                              : "Marcar Todo",
                                          fontSize: isSmallDevice ? 11 : 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
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

                    // 🎵 LISTA DE IMPORTACIÓN AGRUPADA
                    Expanded(
                      child: _items.isEmpty
                          ? _buildEmptyState(
                              context,
                              theme,
                              isDark,
                              isSmallDevice,
                              horizontalPadding,
                            )
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(bottom: 100),
                              children: [
                                // 📁 GRUPOS DE CARPETAS
                                ...groups.entries.map((entry) {
                                  final folderName = entry.key;
                                  final folderItems = entry.value;
                                  final isExpanded = _expandedFolders.contains(
                                    folderName,
                                  );
                                  final allSelected = folderItems.every(
                                    (i) => i.isSelected,
                                  );
                                  final folderBytes = folderItems.fold(
                                    0,
                                    (s, i) => s + i.size,
                                  );
                                  final folderMB = (folderBytes / (1024 * 1024))
                                      .toStringAsFixed(1);

                                  return Container(
                                    key: ValueKey("folder_$folderName"),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isExpanded
                                            ? AppColors.primary.withValues(
                                                alpha: 0.35,
                                              )
                                            : cardBorderColor,
                                        width: isExpanded ? 1.4 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.2 : 0.03,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          onTap: () =>
                                              _toggleFolderExpanded(folderName),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 2,
                                              ),
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: allSelected,
                                                activeColor: AppColors.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                onChanged: isBusy
                                                    ? null
                                                    : (_) =>
                                                          _toggleSelectFolder(
                                                            folderName,
                                                          ),
                                              ),
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  LucideIcons.folder,
                                                  color: AppColors.primary,
                                                  size: isSmallDevice ? 18 : 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          title: CustomText(
                                            text: folderName,
                                            fontSize: isSmallDevice ? 13 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: CustomText(
                                            text:
                                                "${folderItems.length} pistas • $folderMB MB",
                                            fontSize: isSmallDevice ? 10 : 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.55),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  LucideIcons.penLine,
                                                  size: isSmallDevice ? 15 : 17,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.55),
                                                ),
                                                tooltip: "Renombrar carpeta",
                                                onPressed: isBusy
                                                    ? null
                                                    : () =>
                                                          _editarNombreCarpeta(
                                                            folderName,
                                                          ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  LucideIcons.trash2,
                                                  size: isSmallDevice ? 15 : 17,
                                                  color: AppColors.danger
                                                      .withValues(alpha: 0.8),
                                                ),
                                                tooltip: "Remover carpeta",
                                                onPressed: isBusy
                                                    ? null
                                                    : () => _eliminarCarpeta(
                                                        folderName,
                                                      ),
                                              ),
                                              Icon(
                                                isExpanded
                                                    ? LucideIcons.chevronUp
                                                    : LucideIcons.chevronDown,
                                                size: isSmallDevice ? 18 : 20,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isExpanded)
                                          Container(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                              right: 8,
                                              bottom: 8,
                                            ),
                                            child: Column(
                                              children: folderItems.map((item) {
                                                return _buildSongItemTile(
                                                  item: item,
                                                  theme: theme,
                                                  isDark: isDark,
                                                  isSmallDevice: isSmallDevice,
                                                  isBusy: isBusy,
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),

                                // 🎵 CANCIONES SUELTAS (SIN CARPETA)
                                if (looseList.isNotEmpty)
                                  Container(
                                    key: const ValueKey("loose_container"),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _looseExpanded
                                            ? AppColors.primary.withValues(
                                                alpha: 0.35,
                                              )
                                            : cardBorderColor,
                                        width: _looseExpanded ? 1.4 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.2 : 0.03,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          onTap: () {
                                            setState(() {
                                              _looseExpanded = !_looseExpanded;
                                            });
                                          },
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 2,
                                              ),
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: looseList.every(
                                                  (i) => i.isSelected,
                                                ),
                                                activeColor: AppColors.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                onChanged: isBusy
                                                    ? null
                                                    : (_) =>
                                                          _toggleSelectLoose(),
                                              ),
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  LucideIcons.fileMusic,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
                                                  size: isSmallDevice ? 18 : 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          title: CustomText(
                                            text: "Canciones Sueltas",
                                            fontSize: isSmallDevice ? 13 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          subtitle: CustomText(
                                            text:
                                                "${looseList.length} pistas sin carpeta",
                                            fontSize: isSmallDevice ? 10 : 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.55),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: isSmallDevice
                                                        ? 4
                                                        : 8,
                                                  ),
                                                ),
                                                icon: Icon(
                                                  LucideIcons.folderPlus,
                                                  size: isSmallDevice ? 14 : 16,
                                                ),
                                                label: CustomText(
                                                  text: "Asignar",
                                                  fontSize: isSmallDevice
                                                      ? 11
                                                      : 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                                onPressed: isBusy
                                                    ? null
                                                    : _asignarCarpetaACancionesSueltas,
                                              ),
                                              Icon(
                                                _looseExpanded
                                                    ? LucideIcons.chevronUp
                                                    : LucideIcons.chevronDown,
                                                size: isSmallDevice ? 18 : 20,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_looseExpanded)
                                          Container(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                              right: 8,
                                              bottom: 8,
                                            ),
                                            child: Column(
                                              children: looseList.map((item) {
                                                return _buildSongItemTile(
                                                  item: item,
                                                  theme: theme,
                                                  isDark: isDark,
                                                  isSmallDevice: isSmallDevice,
                                                  isBusy: isBusy,
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),

                    // 🚀 BOTÓN FLOTANTE ELEVADO DE IMPORTACIÓN FINAL
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isSmallDevice ? 6 : 10,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: _selectedCount > 0 ? 0.35 : 0.0,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallDevice ? 12 : 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            LucideIcons.downloadCloud,
                            size: 19,
                            color: Colors.white,
                          ),
                          onPressed: _selectedCount == 0 || isBusy
                              ? null
                              : _ejecutarImportacion,
                          label: CustomText(
                            text: _selectedCount == 0
                                ? "Selecciona pistas para importar"
                                : "Importar $_selectedCount Canciones ($totalMB MB)",
                            fontSize: isSmallDevice ? 13.5 : 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),

            // 🌊 OVERLAY DE CARGA ANIMADO
            if (isBusy) const Positioned.fill(child: ImportandoOverlay()),
          ],
        ),
      ),
    );
  }

  /// TARJETA HERO DE SELECCIÓN DE ARCHIVOS O CARPETAS
  Widget _buildActionHeroCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required bool isDark,
    required ThemeData theme,
    required bool isSmallDevice,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 10 : 12,
            vertical: isSmallDevice ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPrimary
                  ? [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.85),
                    ]
                  : [
                      isDark ? const Color(0xFF181A2D) : Colors.white,
                      isDark
                          ? const Color(0xFF131525)
                          : const Color(0xFFF9FAFD),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: isSmallDevice ? 32 : 36,
                    height: isSmallDevice ? 32 : 36,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isPrimary ? Colors.white : AppColors.primary,
                      size: isSmallDevice ? 17 : 19,
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.arrowUpRight,
                        size: 12,
                        color: isPrimary
                            ? Colors.white70
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    text: title,
                    fontSize: isSmallDevice ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: isPrimary
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  CustomText(
                    text: subtitle,
                    fontSize: isSmallDevice ? 9.5 : 10.5,
                    color: isPrimary
                        ? Colors.white70
                        : (isDark ? Colors.white54 : Colors.black45),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ELEMENTO INDIVIDUAL DE CANCIÓN DENTRO DE CARPETA O SUELTAS
  Widget _buildSongItemTile({
    required ImportItem item,
    required ThemeData theme,
    required bool isDark,
    required bool isSmallDevice,
    required bool isBusy,
  }) {
    final sizeMB = (item.size / (1024 * 1024)).toStringAsFixed(1);
    final ext = item.path.split('.').last.toUpperCase();

    return Container(
      key: ValueKey("item_${item.path}"),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: item.isSelected ? 0.04 : 0.015)
            : Colors.black.withValues(alpha: item.isSelected ? 0.03 : 0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          width: 0.8,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        leading: Checkbox(
          value: item.isSelected,
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: isBusy
              ? null
              : (val) {
                  setState(() {
                    item.isSelected = val ?? false;
                  });
                },
        ),
        title: SongMarqueeTitle(
          text: item.title,
          fontSize: isSmallDevice ? 11.5 : 12.5,
          fontWeight: item.isSelected ? FontWeight.bold : FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ext,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(width: 6),
            CustomText(
              text: "$sizeMB MB",
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                LucideIcons.penLine,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              tooltip: "Editar título",
              onPressed: isBusy ? null : () => _editarNombreItem(item),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.trash2,
                size: 14,
                color: AppColors.danger.withValues(alpha: 0.75),
              ),
              tooltip: "Remover pista",
              onPressed: isBusy
                  ? null
                  : () {
                      setState(() {
                        _items.remove(item);
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  /// ESTADO VACÍO CUANDO NO HAY PISTAS SELECCIONADAS
  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isSmallDevice,
    double horizontalPadding,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
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
                    LucideIcons.music4,
                    size: isSmallDevice ? 32 : 38,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomText(
                text: "Lista de importación vacía",
                fontSize: isSmallDevice ? 15 : 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CustomText(
                  text:
                      "Toca 'Elegir Archivos' o 'Agregar Carpeta' arriba para seleccionar canciones de tu almacenamiento local.",
                  textAlign: TextAlign.center,
                  fontSize: isSmallDevice ? 11 : 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: allowedExts.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

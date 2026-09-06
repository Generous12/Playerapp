import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:playerapp1/services/musicservice.dart';
import 'package:sqflite/sqflite.dart';

class Cancion {
  final int? id;
  final int? idMedia;
  String titulo;
  final int? idAlbum;
  final int duracion;
  String rutaArchivo;
  final int? tamanoArchivo;
  final int fechaAgregado;
  final int? numeroPista;
  final int? year;
  final int posicion;
  final int enGeneral;

  Cancion({
    this.id,
    this.idMedia,
    required this.titulo,
    this.idAlbum,
    required this.duracion,
    required this.rutaArchivo,
    this.tamanoArchivo,
    required this.fechaAgregado,
    this.numeroPista,
    this.year,
    this.posicion = 0,
    this.enGeneral = 1,
  });

  /// Getter auxiliar para obtener el artista (extraído del título si tiene formato "Artista - Título", o null)
  String? get artista {
    if (titulo.contains(' - ')) {
      final parts = titulo.split(' - ');
      if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
        return parts[0].trim();
      }
    }
    return null;
  }

  factory Cancion.fromMap(Map<String, dynamic> map) {
    return Cancion(
      id: map['id'],
      idMedia: map['id_media'],
      titulo: map['titulo'],
      idAlbum: map['id_album'],
      duracion: map['duracion'],
      rutaArchivo: map['ruta_archivo'],
      tamanoArchivo: map['tamano_archivo'],
      fechaAgregado: map['fecha_agregado'],
      numeroPista: map['numero_pista'],
      year: map['year'],
      posicion: map['posicion'] ?? 0,
      enGeneral: map['en_general'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_media': idMedia,
      'titulo': titulo,
      'id_album': idAlbum,
      'duracion': duracion,
      'ruta_archivo': rutaArchivo,
      'tamano_archivo': tamanoArchivo,
      'fecha_agregado': fechaAgregado,
      'numero_pista': numeroPista,
      'year': year,
      'posicion': posicion,
      'en_general': enGeneral,
    };
  }
}

class CancionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  void _notificarCambios() {
    CancionesNotifier.instance.actualizar();
    FavoritosNotifier.instance.actualizar();
  }

  /// CREAR
  Future<int> insertar(Cancion cancion) async {
    final db = await _dbHelper.database;

   final id = await db.insert(
      'canciones',
      cancion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notificarCambios();
    return id;
  }

  /// INSERCIÓN MASIVA (BATCH ATÓMICO - EVITA PARPADEOS)
  Future<void> insertarBatch(List<Cancion> canciones) async {
    if (canciones.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final cancion in canciones) {
      batch.insert(
        'canciones',
        cancion.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
    _notificarCambios();
  }

  Future<List<Cancion>> obtenerTodas() async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'canciones',
      where: 'COALESCE(en_general, 1) = 1',
      orderBy: 'posicion ASC',
    );

    return result.map((e) => Cancion.fromMap(e)).toList();
  }

  Future<Cancion?> obtenerPorId(int id) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'canciones',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Cancion.fromMap(result.first);
  }

  /// ELIMINAR
  Future<int> eliminar(int id, {bool borrarArchivoFisico = false}) async {
    final db = await _dbHelper.database;

    if (borrarArchivoFisico) {
      try {
        final cancion = await obtenerPorId(id);
        if (cancion != null && cancion.rutaArchivo.isNotEmpty) {
          final file = File(cancion.rutaArchivo);
          if (await file.exists()) {
            await file.delete();
            debugPrint("🗑️ Archivo físico eliminado: ${cancion.rutaArchivo}");
          }
        }
      } catch (e) {
        debugPrint("⚠️ No se pudo eliminar el archivo físico del dispositivo: $e");
      }
    }

    // Limpiar tablas dependientes para evitar errores de Foreign Key (SQLITE 787)
    try {
      await db.delete('historial_reproduccion', where: 'id_cancion = ?', whereArgs: [id]);
      await db.delete('favoritos', where: 'id_cancion = ?', whereArgs: [id]);
      await db.delete('estado_cancion', where: 'id_cancion = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("⚠️ Limpieza previa de tablas relacionadas: $e");
    }

    final resultado = await db.delete('canciones', where: 'id = ?', whereArgs: [id]);
    _notificarCambios();
    return resultado;
  }

  /// 🗑️ ELIMINAR DESDE VISTA GENERAL (Preserva en Carpetas si tiene id_album)
  Future<int> eliminarDeGeneral(Cancion cancion, {bool borrarArchivoFisico = false}) async {
    if (borrarArchivoFisico) {
      return await eliminar(cancion.id!, borrarArchivoFisico: true);
    }

    // Si la canción pertenece a una carpeta/álbum, solo se oculta de la lista General
    if (cancion.idAlbum != null) {
      final db = await _dbHelper.database;
      final res = await db.update(
        'canciones',
        {'en_general': 0},
        where: 'id = ?',
        whereArgs: [cancion.id],
      );
      _notificarCambios();
      return res;
    } else {
      // Pista suelta que no pertenece a ninguna carpeta: se elimina de la base de datos
      return await eliminar(cancion.id!, borrarArchivoFisico: false);
    }
  }

  /// RESTAURAR EN GENERAL
  Future<void> restaurarEnGeneral(int cancionId) async {
    final db = await _dbHelper.database;
    await db.update(
      'canciones',
      {'en_general': 1},
      where: 'id = ?',
      whereArgs: [cancionId],
    );
    _notificarCambios();
  }

  /// ACTUALIZAR RUTA DE CANCIÓN
  Future<void> actualizarRuta(int id, String nuevaRuta) async {
    final db = await _dbHelper.database;
    await db.update(
      'canciones',
      {'ruta_archivo': nuevaRuta},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// RENOMBRAR CANCIÓN
  Future<void> renombrar(int id, String nuevoTitulo, {bool renombrarArchivoFisico = false}) async {
    final db = await _dbHelper.database;
    final cancion = await obtenerPorId(id);
    if (cancion == null) return;

    String nuevaRuta = cancion.rutaArchivo;

    if (renombrarArchivoFisico && cancion.rutaArchivo.isNotEmpty) {
      try {
        final file = File(cancion.rutaArchivo);
        if (await file.exists()) {
          final parentDir = file.parent.path;
          final ext = file.path.contains('.') ? file.path.split('.').last : 'mp3';
          final cleanTitle = nuevoTitulo.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final targetRuta = "$parentDir/$cleanTitle.$ext";
          if (targetRuta != cancion.rutaArchivo) {
            final renamedFile = await file.rename(targetRuta);
            if (await renamedFile.exists()) {
              nuevaRuta = targetRuta;
              debugPrint("✏️ Archivo físico renombrado a: $nuevaRuta");
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ No se pudo renombrar el archivo físico (se mantiene ruta original): $e");
        nuevaRuta = cancion.rutaArchivo;
      }
    }

    // Verificación de seguridad: si la nueva ruta no existe pero la original sí, revertir a la original
    if (!await File(nuevaRuta).exists() && await File(cancion.rutaArchivo).exists()) {
      nuevaRuta = cancion.rutaArchivo;
    }

    await db.update(
      'canciones',
      {
        'titulo': nuevoTitulo,
        'ruta_archivo': nuevaRuta,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final activeSong = MusicService.instance.currentSong;
    if (activeSong != null && activeSong.id == id) {
      activeSong.titulo = nuevoTitulo;
      activeSong.rutaArchivo = nuevaRuta;
    }
    MusicService.instance.updateSongMetadata(id, nuevoTitulo, nuevaRuta);

    _notificarCambios();
  }

  /// BUSCAR POR NOMBRE (puede mantener orden alfabético)
  Future<List<Cancion>> buscarPorNombre(String texto) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'canciones',
      where: 'titulo LIKE ? AND COALESCE(en_general, 1) = 1',
      whereArgs: ['%$texto%'],
      orderBy: 'titulo ASC',
    );

    return result.map((e) => Cancion.fromMap(e)).toList();
  }

  /// CONTAR CANCIONES
  Future<int> contarCanciones() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM canciones WHERE COALESCE(en_general, 1) = 1',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// TOTAL BYTES
  Future<int> obtenerTamanoTotalBytes() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      'SELECT SUM(tamano_archivo) as total FROM canciones WHERE COALESCE(en_general, 1) = 1',
    );

    final total = result.first['total'];

    return total == null ? 0 : total as int;
  }

  /// TOTAL MB
  Future<double> obtenerTamanoTotalMB() async {
    final bytes = await obtenerTamanoTotalBytes();
    return bytes / (1024 * 1024);
  }

  /// EXISTE POR RUTA
  Future<bool> existeRuta(String ruta) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'canciones',
      columns: ['id'],
      where: 'ruta_archivo = ?',
      whereArgs: [ruta],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// OBTENER CONJUNTO DE TODAS LAS RUTAS ALMACENADAS (PARA VERIFICACIÓN RÁPIDA EN MEMORIA)
  Future<Set<String>> obtenerRutasExistentesSet() async {
    final db = await _dbHelper.database;
    final result = await db.query('canciones', columns: ['ruta_archivo']);
    return result.map((row) => row['ruta_archivo'] as String).toSet();
  }

  // ⭐ NUEVO: ACTUALIZAR POSICION (DRAG & DROP)
  Future<void> actualizarPosicion(int id, int nuevaPosicion) async {
    final db = await _dbHelper.database;

    await db.update(
      'canciones',
      {'posicion': nuevaPosicion},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ⭐ NUEVO: REORDENAR LISTA COMPLETA
  Future<void> reordenar(List<Cancion> canciones) async {
    if (canciones.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (int i = 0; i < canciones.length; i++) {
      batch.update(
        'canciones',
        {'posicion': i},
        where: 'id = ?',
        whereArgs: [canciones[i].id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> asignarAAlbum(int cancionId, int albumId) async {
    final db = await _dbHelper.database;

    await db.update(
      'canciones',
      {
        'id_album': albumId,
        'en_general': 1,
      },
      where: 'id = ?',
      whereArgs: [cancionId],
    );
    _notificarCambios();
  }

  Future<void> quitarDeAlbum(int cancionId) async {
    final db = await _dbHelper.database;

    await db.update(
      'canciones',
      {'id_album': null},
      where: 'id = ?',
      whereArgs: [cancionId],
    );
    _notificarCambios();
  }

  Future<List<Cancion>> obtenerPorAlbum(int albumId) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'canciones',
      where: 'id_album = ?',
      whereArgs: [albumId],
      orderBy: 'posicion ASC',
    );

    return result.map((e) => Cancion.fromMap(e)).toList();
  }

  Future<int> removeFromAlbum(int songId) async {
    final db = await DatabaseHelper.instance.database;

    return await db.update(
      'canciones',
      {'id_album': null},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }
}

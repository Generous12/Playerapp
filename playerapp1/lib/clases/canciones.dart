import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/notifiers/cancionesnotifier.dart';
import 'package:sqflite/sqflite.dart';

class Cancion {
  final int? id;
  final int? idMedia;
  final String titulo;
  final int? idAlbum;
  final int duracion;
  final String rutaArchivo;
  final int? tamanoArchivo;
  final int fechaAgregado;
  final int? numeroPista;
  final int? year;
  final int posicion;
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
  });

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
      'posicion': posicion, // ⭐ IMPORTANTE
    };
  }
}

class CancionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  void _notificarCambios() {
    CancionesNotifier.instance.actualizar();
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

    final result = await db.query('canciones', orderBy: 'posicion ASC');

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
  Future<int> eliminar(int id) async {
    final db = await _dbHelper.database;

    final resultado = await db.delete('canciones', where: 'id = ?', whereArgs: [id]);
    _notificarCambios();
    return resultado;
  }

  /// BUSCAR POR NOMBRE (puede mantener orden alfabético)
  Future<List<Cancion>> buscarPorNombre(String texto) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'canciones',
      where: 'titulo LIKE ?',
      whereArgs: ['%$texto%'],
      orderBy: 'titulo ASC',
    );

    return result.map((e) => Cancion.fromMap(e)).toList();
  }

  /// CONTAR CANCIONES
  Future<int> contarCanciones() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('SELECT COUNT(*) as total FROM canciones');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// TOTAL BYTES
  Future<int> obtenerTamanoTotalBytes() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      'SELECT SUM(tamano_archivo) as total FROM canciones',
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
      {'id_album': albumId},
      where: 'id = ?',
      whereArgs: [cancionId],
    );  _notificarCambios();
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

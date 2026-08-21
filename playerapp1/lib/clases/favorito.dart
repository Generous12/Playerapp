import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/notifiers/favoritonotifier.dart';
import 'package:sqflite/sqflite.dart';

class Favorito {
  final int? id;
  final int idCancion;
  final int fechaAgregado;
  final int posicion;

  Favorito({
    this.id,
    required this.idCancion,
    required this.fechaAgregado,
    this.posicion = 0,
  });

  factory Favorito.fromMap(Map<String, dynamic> map) {
    return Favorito(
      id: map['id'],
      idCancion: map['id_cancion'],
      fechaAgregado: map['fecha_agregado'],
      posicion: map['posicion'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_cancion': idCancion,
      'fecha_agregado': fechaAgregado,
      'posicion': posicion,
    };
  }
}

class FavoritoDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  void _notificarCambios() {
    FavoritosNotifier.instance.actualizar();
  }

  Future<int> insertFavorito(Favorito favorito) async {
    final db = await _dbHelper.database;

    final maxPos =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(posicion) FROM favoritos'),
        ) ??
        0;

    final id = await db.insert(
      'favoritos',
      favorito.toMap()
        ..remove('id')
        ..['posicion'] = maxPos + 1,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notificarCambios();
    return id;
  }

  Future<List<Favorito>> getFavoritos() async {
    final db = await _dbHelper.database;

    final result = await db.query('favoritos', orderBy: 'posicion ASC');

    return result.map((map) => Favorito.fromMap(map)).toList();
  }

  // 🎵 JOIN canciones + favoritos (orden por posición real del usuario)
  Future<List<Map<String, dynamic>>> getCancionesFavoritas() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
      SELECT c.*, f.posicion as fav_posicion
      FROM canciones c
      INNER JOIN favoritos f
        ON c.id = f.id_cancion
      ORDER BY f.posicion ASC
    ''');
  }

  // 🔍 FAVORITO POR CANCION
  Future<Favorito?> getFavoritoByCancion(int idCancion) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'favoritos',
      where: 'id_cancion = ?',
      whereArgs: [idCancion],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Favorito.fromMap(result.first);
  }

  // ❌ ELIMINAR POR CANCION
  Future<int> deleteFavoritoByCancion(int idCancion) async {
    final db = await _dbHelper.database;

    final rows = await db.delete(
      'favoritos',
      where: 'id_cancion = ?',
      whereArgs: [idCancion],
    );
    if (rows > 0) {
      _notificarCambios();
    }

    return rows;
  }

  // 🔁 TOGGLE FAVORITO
  Future<bool> toggleFavorito(int idCancion) async {
    final existente = await getFavoritoByCancion(idCancion);

    if (existente != null) {
      await deleteFavoritoByCancion(idCancion);
      return false;
    } else {
      await insertFavorito(
        Favorito(
          idCancion: idCancion,
          fechaAgregado: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      return true;
    }
  }

  // 📊 CHECK FAVORITO
  Future<bool> isFavorito(int idCancion) async {
    return await getFavoritoByCancion(idCancion) != null;
  }

  // 🔥 REORDENAR FAVORITOS (DRAG & DROP)
  Future<void> reordenarFavoritos(List<Favorito> favoritos) async {
    if (favoritos.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (int i = 0; i < favoritos.length; i++) {
      batch.update(
        'favoritos',
        {'posicion': i},
        where: 'id_cancion = ?',
        whereArgs: [favoritos[i].idCancion],
      );  
    }

    await batch.commit(noResult: true);
  }
}

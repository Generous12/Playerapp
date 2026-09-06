import 'package:flutter/foundation.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:sqflite/sqflite.dart';

class Historial {
  final int? id;
  final int idCancion;
  final int fechaReproduccion;
  final int? duracionReproducida;

  Historial({
    this.id,
    required this.idCancion,
    required this.fechaReproduccion,
    this.duracionReproducida,
  });

  factory Historial.fromMap(Map<String, dynamic> map) {
    return Historial(
      id: map['id'],
      idCancion: map['id_cancion'],
      fechaReproduccion: map['fecha_reproduccion'],
      duracionReproducida: map['duracion_reproducida'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_cancion': idCancion,
      'fecha_reproduccion': fechaReproduccion,
      'duracion_reproducida': duracionReproducida,
    };
  }
}

class HistorialDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertHistorial(int idCancion) async {
    try {
      final db = await _dbHelper.database;
      final exists = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM canciones WHERE id = ?', [idCancion]),
      ) ?? 0;

      if (exists == 0) return -1;

      return await db.insert(
        'historial_reproduccion',
        {
          'id_cancion': idCancion,
          'fecha_reproduccion': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("⚠️ No se pudo registrar historial (canción eliminada o no encontrada): $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getHistorialCompleto() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT h.id as historial_id, h.fecha_reproduccion, c.*
      FROM historial_reproduccion h
      INNER JOIN canciones c ON h.id_cancion = c.id
      ORDER BY h.fecha_reproduccion DESC
      LIMIT 50
    ''');
  }

  Future<List<Map<String, dynamic>>> getMasReproducidas(int limite) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT c.*, COUNT(h.id_cancion) as reproducciones
      FROM historial_reproduccion h
      INNER JOIN canciones c ON h.id_cancion = c.id
      GROUP BY h.id_cancion
      ORDER BY reproducciones DESC
      LIMIT ?
    ''', [limite]);
  }

  Future<void> clearHistorial() async {
    final db = await _dbHelper.database;
    await db.delete('historial_reproduccion');
  }
}

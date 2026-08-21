import 'package:playerapp1/database/playerdb.dart';
import 'package:sqflite/sqflite.dart';

class EstadoCancion {
  final int idCancion;
  final int ultimaPosicion;
  final int estaReproduciendo;
  final int ultimaReproduccion;

  EstadoCancion({
    required this.idCancion,
    required this.ultimaPosicion,
    required this.estaReproduciendo,
    required this.ultimaReproduccion,
  });

  factory EstadoCancion.fromMap(Map<String, dynamic> map) {
    return EstadoCancion(
      idCancion: map['id_cancion'],
      ultimaPosicion: map['ultima_posicion'],
      estaReproduciendo: map['esta_reproduciendo'] ?? 0,
      ultimaReproduccion: map['ultima_reproduccion'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cancion': idCancion,
      'ultima_posicion': ultimaPosicion,
      'esta_reproduciendo': estaReproduciendo,
      'ultima_reproduccion': ultimaReproduccion,
    };
  }
}

class EstadoCancionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> guardarEstado(int idCancion, int posicionMs, bool estaReproduciendo) async {
    final db = await _dbHelper.database;
    await db.insert(
      'estado_cancion',
      {
        'id_cancion': idCancion,
        'ultima_posicion': posicionMs,
        'esta_reproduciendo': estaReproduciendo ? 1 : 0,
        'ultima_reproduccion': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EstadoCancion?> obtenerUltimoEstado() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'estado_cancion',
      orderBy: 'ultima_reproduccion DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return EstadoCancion.fromMap(result.first);
  }

  Future<void> limpiarEstado() async {
    final db = await _dbHelper.database;
    await db.delete('estado_cancion');
  }
}

import 'package:playerapp1/database/playerdb.dart';
import 'package:sqflite/sqflite.dart';

class Album {
  final int? id;
  final String titulo;
  final int? year;
  final String? portada;

  Album({this.id, required this.titulo, this.year, this.portada});

  factory Album.fromMap(Map<String, dynamic> map) {
    return Album(
      id: map['id'],
      titulo: map['titulo'],
      year: map['year'],
      portada: map['portada'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'titulo': titulo, 'year': year, 'portada': portada};
  }

  static Future<int> create(Album album) async {
    final db = await DatabaseHelper.instance.database;

    return await db.insert(
      'albumes',
      album.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Album>> getAll() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query('albumes', orderBy: 'id DESC');

    return result.map((e) => Album.fromMap(e)).toList();
  }

  static Future<int> countAlbums() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery('SELECT COUNT(*) as total FROM albumes');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Album>> search(String query) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'albumes',
      where: 'titulo LIKE ?',
      whereArgs: ['%$query%'],
    );

    return result.map((e) => Album.fromMap(e)).toList();
  }

  static Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'albumes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updateTitle(int id, String newTitle) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'albumes',
      {'titulo': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

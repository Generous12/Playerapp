import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reproductor_musica.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        try {
          await db.execute(
            'ALTER TABLE canciones ADD COLUMN en_general INTEGER DEFAULT 1',
          );
        } catch (_) {}
        await db.execute('CREATE INDEX IF NOT EXISTS idx_canciones_titulo ON canciones(titulo)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_canciones_album ON canciones(id_album)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_canciones_posicion ON canciones(posicion)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_canciones_ruta ON canciones(ruta_archivo)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_favoritos_posicion ON favoritos(posicion)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_fecha ON historial_reproduccion(fecha_reproduccion)');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {

    // 🎵 CANCIONES (BIBLIOTECA GENERAL)
    await db.execute('''
      CREATE TABLE canciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_media INTEGER UNIQUE,
        titulo TEXT NOT NULL,
        posicion INTEGER DEFAULT 0,
        id_album INTEGER,
        duracion INTEGER,
        ruta_archivo TEXT NOT NULL,
        tamano_archivo INTEGER,
        fecha_agregado INTEGER,
        numero_pista INTEGER,
        year INTEGER,
        en_general INTEGER DEFAULT 1
      )
    ''');

    // 💿 ALBUMES
    await db.execute('''
      CREATE TABLE albumes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT,
        year INTEGER,
        portada TEXT
      )
    ''');

    // ❤️ FAVORITOS (ORDEN INDEPENDIENTE)
    await db.execute('''
      CREATE TABLE favoritos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cancion INTEGER UNIQUE,
        posicion INTEGER DEFAULT 0,
        fecha_agregado INTEGER,
        FOREIGN KEY (id_cancion) REFERENCES canciones(id) ON DELETE CASCADE
      )
    ''');

    // 📂 LISTAS / CARPETAS
    await db.execute('''
      CREATE TABLE listas_reproduccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha_creacion INTEGER,
        es_favoritos INTEGER DEFAULT 0
      )
    ''');

    // ⏱ HISTORIAL
    await db.execute('''
      CREATE TABLE historial_reproduccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cancion INTEGER,
        fecha_reproduccion INTEGER,
        duracion_reproducida INTEGER,
        FOREIGN KEY (id_cancion) REFERENCES canciones(id) ON DELETE CASCADE
      )
    ''');

    // ⏯ COLA TEMPORAL
    await db.execute('''
      CREATE TABLE cola_reproduccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cancion INTEGER,
        posicion INTEGER,
        fecha_agregado INTEGER,
        FOREIGN KEY (id_cancion) REFERENCES canciones(id) ON DELETE CASCADE
      )
    ''');

    // 📍 ESTADO DE REPRODUCCIÓN
    await db.execute('''
      CREATE TABLE estado_cancion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cancion INTEGER UNIQUE,
        ultima_posicion INTEGER,
        esta_reproduciendo INTEGER DEFAULT 0,
        ultima_reproduccion INTEGER,
        FOREIGN KEY (id_cancion) REFERENCES canciones(id) ON DELETE CASCADE
      )
    ''');

    // ⚙️ CONFIGURACIÓN
    await db.execute('''
      CREATE TABLE configuracion_reproductor (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    // 📊 ÍNDICES (MEJORA DE RENDIMIENTO)
    await db.execute('CREATE INDEX idx_canciones_titulo ON canciones(titulo)');
    await db.execute('CREATE INDEX idx_canciones_album ON canciones(id_album)');
    await db.execute('CREATE INDEX idx_canciones_posicion ON canciones(posicion)');
    await db.execute('CREATE INDEX idx_favoritos_posicion ON favoritos(posicion)');
    await db.execute('CREATE INDEX idx_historial_fecha ON historial_reproduccion(fecha_reproduccion)');
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:playerapp1/database/playerdb.dart';

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const String _table = 'configuracion_reproductor';

  /// 🔧 GUARDAR CONFIGURACIÓN (genérico)
  Future<void> setValue(String key, String value) async {
    final Database db = await DatabaseHelper.instance.database;

    await db.insert(
      _table,
      {
        'clave': key,
        'valor': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 📥 OBTENER CONFIGURACIÓN
  Future<String?> getValue(String key) async {
    final Database db = await DatabaseHelper.instance.database;

    final result = await db.query(
      _table,
      where: 'clave = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['valor'] as String;
    }

    return null;
  }

  /// 🎨 TEMA - guardar
  Future<void> setThemeMode(String mode) async {
    await setValue('theme_mode', mode);
  }

  /// 🎨 TEMA - obtener
  Future<String> getThemeMode() async {
    return await getValue('theme_mode') ?? 'system';
  }

  /// 🔊 VOLUMEN (ejemplo futuro)
  Future<void> setVolume(double value) async {
    await setValue('volume', value.toString());
  }

  Future<double> getVolume() async {
    final v = await getValue('volume');
    return double.tryParse(v ?? '') ?? 1.0;
  }

  /// 🎵 CALIDAD AUDIO (ejemplo)
  Future<void> setAudioQuality(String quality) async {
    await setValue('audio_quality', quality);
  }

  Future<String> getAudioQuality() async {
    return await getValue('audio_quality') ?? 'high';
  }

  /// 🧹 RESET CONFIG
  Future<void> reset() async {
    final Database db = await DatabaseHelper.instance.database;
    await db.delete(_table);
  }
}
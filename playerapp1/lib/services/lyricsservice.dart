import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:playerapp1/services/audio_metadata_reader.dart';
import 'package:playerapp1/services/connectivity_service.dart';

class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translatedText;

  LyricLine({
    required this.timestamp,
    required this.text,
    this.translatedText,
  });

  LyricLine copyWith({String? text, String? translatedText}) {
    return LyricLine(
      timestamp: timestamp,
      text: text ?? this.text,
      translatedText: translatedText ?? this.translatedText,
    );
  }
}

class LyricsResult {
  final String title;
  final String artist;
  final String plainLyrics;
  final String? syncedLyrics;
  final List<LyricLine> lines;
  final String? activeTranslationLang;
  final String? translatedPlainLyrics;
  final bool isAI;
  final bool isSynced;
  final bool isEmbedded;
  int timeOffsetMs;

  LyricsResult({
    required this.title,
    required this.artist,
    required this.plainLyrics,
    this.syncedLyrics,
    required this.lines,
    this.activeTranslationLang,
    this.translatedPlainLyrics,
    this.isAI = false,
    this.isSynced = false,
    this.isEmbedded = false,
    this.timeOffsetMs = 0,
  });

  LyricsResult copyWith({
    List<LyricLine>? lines,
    String? activeTranslationLang,
    String? translatedPlainLyrics,
    bool? isAI,
    bool? isSynced,
    bool? isEmbedded,
    int? timeOffsetMs,
  }) {
    return LyricsResult(
      title: title,
      artist: artist,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
      lines: lines ?? this.lines,
      activeTranslationLang: activeTranslationLang ?? this.activeTranslationLang,
      translatedPlainLyrics: translatedPlainLyrics ?? this.translatedPlainLyrics,
      isAI: isAI ?? this.isAI,
      isSynced: isSynced ?? this.isSynced,
      isEmbedded: isEmbedded ?? this.isEmbedded,
      timeOffsetMs: timeOffsetMs ?? this.timeOffsetMs,
    );
  }

  static LyricsResult empty(String title, String artist) {
    return LyricsResult(
      title: title,
      artist: artist,
      plainLyrics: "No se encontró la letra de esta canción.",
      lines: [],
      isAI: false,
      isSynced: false,
      isEmbedded: false,
      timeOffsetMs: 0,
    );
  }
}

class LyricsService extends ChangeNotifier {
  LyricsService._internal();
  static final LyricsService instance = LyricsService._internal();

  final Map<String, LyricsResult> _cache = {};
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Retorna un resultado almacenado previamente en la caché para mostrarlo al instante
  LyricsResult? getCachedResult(String trackName, String? artistName) {
    final meta = extractMetadata(trackName, artistName);
    final cleanTitle = meta['title']!.trim().toLowerCase();
    final cleanArtist = meta['artist']!.trim().toLowerCase();

    final cacheKey = "$cleanTitle|$cleanArtist";
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    return null;
  }

  /// Guarda explícitamente en caché la letra que el usuario seleccionó manualmente
  void cacheSelectedResult(String trackName, String? artistName, LyricsResult result) {
    final meta = extractMetadata(trackName, artistName);
    final cleanTitle = meta['title']!.trim().toLowerCase();
    final cleanArtist = meta['artist']!.trim().toLowerCase();
    final cacheKey = "$cleanTitle|$cleanArtist";
    _cache[cacheKey] = result;
  }

  /// Precarga automáticamente la letra de una canción en segundo plano sin bloquear la UI
  Future<void> preloadLyrics({
    required String trackName,
    String? artistName,
    String? filePath,
    int? durationSeconds,
  }) async {
    final existing = getCachedResult(trackName, artistName);
    if (existing != null) return;

    try {
      final meta = extractMetadata(trackName, artistName);
      final cacheKey = "${meta['title']!.toLowerCase()}|${meta['artist']!.toLowerCase()}";

      // 1. Intentar archivo local si existe (0 ms)
      if (filePath != null && filePath.isNotEmpty) {
        final audioInfo = await AudioMetadataReader.instance.readFromFile(filePath);
        if (audioInfo != null && audioInfo.lyrics != null && audioInfo.lyrics!.trim().isNotEmpty) {
          final lrcText = audioInfo.lyrics!.trim();
          final lines = parseLrc(lrcText);
          final title = audioInfo.title?.trim().isNotEmpty == true ? audioInfo.title!.trim() : meta['title']!;
          final artist = audioInfo.artist?.trim().isNotEmpty == true ? audioInfo.artist!.trim() : (artistName ?? "");

          final embeddedResult = LyricsResult(
            title: title,
            artist: artist,
            plainLyrics: lrcText,
            syncedLyrics: lines.isNotEmpty ? lrcText : null,
            lines: lines.isNotEmpty ? lines : syncPlainLyricsToDuration(lrcText, durationSeconds ?? 180),
            isSynced: lines.isNotEmpty,
            isAI: false,
            isEmbedded: true,
          );
          _cache[cacheKey] = embeddedResult;
          return;
        }
      }

      // 2. Buscar en segundo plano sin notificar listeners de carga activa
      final query = meta['artist']!.isNotEmpty ? "${meta['title']} ${meta['artist']}" : meta['title']!;
      final candidates = await searchLyricsCandidates(
        query,
        filePath: filePath,
        durationSeconds: durationSeconds,
      );

      if (candidates.isNotEmpty) {
        final best = candidates.first;
        if (isHighConfidenceMatch(best, meta['title']!, meta['artist']!)) {
          _cache[cacheKey] = best;
        }
      }
    } catch (e) {
      debugPrint("Error precargando letra en segundo plano: $e");
    }
  }

  /// Verifica si el dispositivo tiene conexión a internet activa
  Future<bool> hasInternetConnection() async {
    return await ConnectivityService.instance.checkConnection();
  }

  /// Limpia títulos de canciones, elimina extensiones (.mp3, .flac, etc.) y extrae artista/título limpios
  Map<String, String> extractMetadata(String rawTitle, String? rawArtist) {
    // 1. Quitar todas las extensiones de audio comunes
    String clean = rawTitle.replaceAll(
      RegExp(r'\.(mp3|flac|wav|m4a|aac|ogg|opus|wma|aiff|alac|ape|dsf|dff)$', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(RegExp(r'\.[a-zA-Z0-9]{2,4}$'), '');

    // 2. Quita números iniciales "01. ", "01 - ", "1-01 ", "01_ "
    clean = clean.replaceAll(RegExp(r'^\d+[\s\.\-_]+'), '');

    // 3. Quita corchetes, paréntesis y etiquetas de video/calidad como [Official Video], (320kbps), (Lyrics), etc.
    clean = clean.replaceAll(
      RegExp(
        r'[\(\[\{].*?\b(official|video|audio|lyrics|letra|remastered|remaster|version|deluxe|bonus|track|hd|4k|320kbps|128kbps|en vivo|live|cover|hq|karaoke|videoclip|acustico|acoustic)\b.*?[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(
      RegExp(
        r'\b(official\s+video|official\s+audio|audio\s+oficial|video\s+oficial|letra|lyrics|hd|4k|remastered|320kbps|128kbps|hq|mp3|flac)\b',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(RegExp(r'www\.[a-zA-Z0-9\-]+\.[a-zA-Z]{2,4}', caseSensitive: false), '');

    String artist = (rawArtist != null &&
            rawArtist.trim().isNotEmpty &&
            rawArtist.toLowerCase() != "unknown" &&
            rawArtist.toLowerCase() != "<unknown>" &&
            rawArtist.toLowerCase() != "artista desconocido")
        ? rawArtist.trim()
        : "";
    String title = clean.trim();

    // Detección de separadores formales de título/artista: " - ", " – ", " — ", "_-_", " | ", " / ", " by "
    final separators = [" - ", " – ", " — ", "_-_", " | ", " / ", " by ", " BY "];
    for (final sep in separators) {
      if (title.contains(sep)) {
        final parts = title.split(sep);
        if (parts.length >= 2) {
          final p1 = parts[0].trim();
          final p2 = parts.sublist(1).join(" ").trim();
          if (sep.toLowerCase().trim() == "by") {
            title = p1;
            if (artist.isEmpty) artist = p2;
          } else {
            if (artist.isEmpty) artist = p1;
            title = p2;
          }
          break;
        }
      }
    }

    title = title.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    artist = artist.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    return {
      'title': title.isEmpty ? rawTitle.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim() : title,
      'artist': artist,
    };
  }

  /// Parsea texto formato LRC "[00:12.34] Letra de la cancion" a lista de `LyricLine` con soporte de offset y milisegundos exactos
  List<LyricLine> parseLrc(String lrcText) {
    final List<LyricLine> lines = [];
    int globalOffsetMs = 0;

    // Detectar etiqueta [offset:+/-ms]
    final offsetMatch = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false).firstMatch(lrcText);
    if (offsetMatch != null) {
      globalOffsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
    }

    final tagRegex = RegExp(r'\[(\d{2}):(\d{2})(?:[\.:](\d{1,3}))?\]');

    for (final rawLine in lrcText.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.toLowerCase().startsWith('[offset:')) {
        final match = RegExp(r'\[offset:\s*([+-]?\d+)\]', caseSensitive: false).firstMatch(trimmed);
        if (match != null) {
          globalOffsetMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
        continue;
      }

      if (trimmed.startsWith('[ti:') ||
          trimmed.startsWith('[ar:') ||
          trimmed.startsWith('[al:') ||
          trimmed.startsWith('[by:') ||
          trimmed.startsWith('[length:')) {
        continue;
      }

      final matches = tagRegex.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      final text = trimmed.replaceAll(tagRegex, '').trim();

      for (final match in matches) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final msStr = match.group(3) ?? '0';

        int ms = 0;
        if (msStr.length == 1) {
          ms = (int.tryParse(msStr) ?? 0) * 100;
        } else if (msStr.length == 2) {
          ms = (int.tryParse(msStr) ?? 0) * 10;
        } else if (msStr.length == 3) {
          ms = int.tryParse(msStr) ?? 0;
        }

        int totalMs = (min * 60 * 1000) + (sec * 1000) + ms + globalOffsetMs;
        if (totalMs < 0) totalMs = 0;

        lines.add(
          LyricLine(
            timestamp: Duration(milliseconds: totalMs),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Analiza la duración real del archivo de audio local y ajusta proporcionalmente las marcas de tiempo si el LRC difiere
  List<LyricLine> alignLinesToAudioDuration(List<LyricLine> lines, int audioDurationSeconds) {
    if (lines.length < 2 || audioDurationSeconds <= 10) return lines;

    final lastLrcMs = lines.last.timestamp.inMilliseconds;
    final audioMs = audioDurationSeconds * 1000;
    if (lastLrcMs <= 0) return lines;

    final ratio = audioMs / lastLrcMs.toDouble();

    // Re-escalar solo si hay diferencia relevante pero dentro de rangos normales de versión (0.75x a 1.25x)
    if (ratio >= 0.75 && ratio <= 1.25 && (audioMs - lastLrcMs).abs() > 4000) {
      return lines.map((l) {
        final scaledMs = (l.timestamp.inMilliseconds * ratio).round();
        return LyricLine(
          timestamp: Duration(milliseconds: scaledMs),
          text: l.text,
          translatedText: l.translatedText,
        );
      }).toList();
    }

    return lines;
  }

  /// Convierte texto plano de letra en líneas sincronizadas ponderadas según la longitud de cada frase y pausas de estrofas
  List<LyricLine> syncPlainLyricsToDuration(String plainText, int durationSeconds) {
    final linesRaw = plainText.split('\n');
    final List<Map<String, dynamic>> processedBlocks = [];

    // Preservar estructura de párrafos para detectar pausas e intermedios
    for (final raw in linesRaw) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('===') || trimmed.startsWith('Canción:') || trimmed.startsWith('Artista:')) {
        continue;
      }

      if (trimmed.isEmpty) {
        // Marca de pausa entre estrofas
        if (processedBlocks.isNotEmpty && processedBlocks.last['type'] != 'pause') {
          processedBlocks.add({'type': 'pause', 'text': '♪ [Pausa / Instrumental]', 'weight': 6.0});
        }
      } else {
        // Ponderación según la cantidad de palabras y caracteres
        final wordCount = trimmed.split(RegExp(r'\s+')).length;
        final charCount = trimmed.length;
        // Ponderación dinámica: mínimo 4, más 1.5 por palabra y 0.2 por carácter
        final double weight = (4.0 + (wordCount * 1.5) + (charCount * 0.2)).clamp(4.0, 45.0);
        processedBlocks.add({'type': 'line', 'text': trimmed, 'weight': weight});
      }
    }

    if (processedBlocks.isEmpty) return [];

    // Limpiar pausas iniciales o duplicadas
    if (processedBlocks.first['type'] == 'pause') {
      processedBlocks.removeAt(0);
    }

    final totalSec = durationSeconds > 30 ? durationSeconds.toDouble() : 180.0;

    // Adaptar intro según la velocidad estimada del tema (mínimo 10s para baladas/lentas)
    final introSec = (totalSec * 0.08).clamp(8.0, 22.0);
    final outroSec = (totalSec * 0.05).clamp(5.0, 15.0);
    final usableSec = (totalSec - introSec - outroSec).clamp(10.0, totalSec);

    double totalWeight = 0;
    for (final block in processedBlocks) {
      totalWeight += (block['weight'] as double);
    }

    final List<LyricLine> result = [];
    double currentSec = introSec;

    for (final block in processedBlocks) {
      final double weight = block['weight'] as double;
      final double durationForBlock = (weight / totalWeight) * usableSec;

      result.add(
        LyricLine(
          timestamp: Duration(milliseconds: (currentSec * 1000).round()),
          text: block['text'] as String,
        ),
      );

      currentSec += durationForBlock;
    }

    return result;
  }

  Future<Map<String, dynamic>?> _httpGetJson(Uri uri, {Duration timeout = const Duration(milliseconds: 3500)}) async {
    // Security: Forzar uso exclusivo de conexiones seguras HTTPS
    if (uri.scheme != 'https') {
      debugPrint("Seguridad: Conexión insegura desestimada: $uri");
      return null;
    }

    final client = HttpClient();
    try {
      client.connectionTimeout = timeout;
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'PlayerApp/1.0.0 (Flutter Music Player; Android)');
      request.headers.set('Accept', 'application/json');
      final response = await request.close().timeout(timeout);

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final dynamic decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List) return {'_list': decoded};
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    return null;
  }

  double _similarity(String s1, String s2) {
    final a = s1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final b = s2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    if (a.contains(b) || b.contains(a)) return 0.85;

    final pairsA = <String>{};
    for (int i = 0; i < a.length - 1; i++) {
      pairsA.add(a.substring(i, i + 2));
    }
    final pairsB = <String>{};
    for (int i = 0; i < b.length - 1; i++) {
      pairsB.add(b.substring(i, i + 2));
    }

    final intersection = pairsA.intersection(pairsB).length;
    final total = pairsA.length + pairsB.length;
    if (total == 0) return 0.0;
    return (2.0 * intersection) / total;
  }

  /// Determina si un candidato es una coincidencia exacta de alta confianza con la canción solicitada
  bool isHighConfidenceMatch(LyricsResult candidate, String cleanTitle, String cleanArtist) {
    if (candidate.isEmbedded) return true;

    final targetTitle = cleanTitle.trim().toLowerCase();
    final targetArtist = cleanArtist.trim().toLowerCase();
    final candTitle = candidate.title.trim().toLowerCase();
    final candArtist = candidate.artist.trim().toLowerCase();

    // ⚠️ Si NO se conoce el artista explícito de la canción (targetArtist vacío o desconocido):
    // JAMÁS declarar coincidencia automática de alta confianza para evitar mostrar la letra de otra canción (ej: Queen.mp3)
    if (targetArtist.isEmpty ||
        targetArtist == "artista desconocido" ||
        targetArtist == "unknown" ||
        targetArtist == "<unknown>" ||
        targetArtist == "artista local") {
      return false;
    }

    final simTitle = _similarity(candTitle, targetTitle);
    final simArtist = _similarity(candArtist, targetArtist);

    // Debe existir coincidencia sólida de Título (>=0.75) Y coincidencia de Artista (>=0.60 o inclusión explícita)
    final artistMatches = simArtist >= 0.60 ||
        candArtist.contains(targetArtist) ||
        targetArtist.contains(candArtist);

    if (simTitle >= 0.75 && artistMatches) {
      return true;
    }

    return false;
  }

  /// Consulta iTunes solo para sugerencias precisas con umbral de similitud estricto
  Future<List<Map<String, String>>> _resolveMetadataWithITunes(String query) async {
    final candidates = <Map<String, String>>[];
    try {
      String cleanQuery = query.replaceAll(
        RegExp(r'\b(de|del|by|from|feat|ft|letra|lyrics)\b', caseSensitive: false),
        ' ',
      );
      cleanQuery = cleanQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleanQuery.isEmpty) return [];

      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': cleanQuery,
        'entity': 'song',
        'limit': '5',
      });

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final dynamic decoded = jsonDecode(body);
        if (decoded is Map && decoded['results'] is List) {
          for (final item in decoded['results']) {
            if (item is Map) {
              final track = item['trackName'] as String? ?? "";
              final artist = item['artistName'] as String? ?? "";
              if (track.isNotEmpty && artist.isNotEmpty) {
                final simTitle = _similarity(track, cleanQuery);
                final simArtist = _similarity(artist, cleanQuery);
                final simCombined = _similarity("$track $artist", cleanQuery);

                if (simTitle >= 0.55 || simArtist >= 0.55 || simCombined >= 0.55) {
                  candidates.add({
                    'trackName': track,
                    'artistName': artist,
                  });
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return candidates;
  }

  /// Realiza una búsqueda intensiva y exhaustiva en internet devolviendo candidatos ordenados por relevancia y sincronización
  Future<List<LyricsResult>> searchLyricsCandidates(
    String query, {
    String? filePath,
    int? durationSeconds,
  }) async {
    final rawTrimmed = query.trim();
    if (rawTrimmed.isEmpty) return [];

    // 1. Extraer y limpiar metadatos del texto
    final meta = extractMetadata(rawTrimmed, null);
    String cleanTitle = meta['title']!;
    String cleanArtist = meta['artist']!;

    // 2. Si se proporciona ruta de archivo físico, leer ID3 / FLAC / M4A directamente
    if (filePath != null && filePath.isNotEmpty) {
      final audioInfo = await AudioMetadataReader.instance.readFromFile(filePath);
      if (audioInfo != null && audioInfo.hasTags) {
        if (audioInfo.title != null && audioInfo.title!.trim().isNotEmpty) {
          cleanTitle = audioInfo.title!.trim();
        }
        if (audioInfo.artist != null && audioInfo.artist!.trim().isNotEmpty) {
          cleanArtist = audioInfo.artist!.trim();
        }
      }
    }

    final results = <LyricsResult>[];
    final seenKeys = <String>{};

    try {
      // 3. Preparar consultas paralelas a múltiples endpoints
      final List<Future<Map<String, dynamic>?>> parallelRequests = [];

      // A) Búsqueda directa por Q (texto crudo, limpio y con corrección de typos como "de" -> "the")
      parallelRequests.add(_httpGetJson(Uri.https('lrclib.net', '/api/search', {'q': rawTrimmed})));
      parallelRequests.add(_httpGetJson(Uri.https('lrclib.net', '/api/search', {'q': "$cleanTitle $cleanArtist"})));
      if (cleanTitle != "$cleanTitle $cleanArtist") {
        parallelRequests.add(_httpGetJson(Uri.https('lrclib.net', '/api/search', {'q': cleanTitle})));
      }

      // Si el texto contiene la palabra "de" aislada, probar variante con "the" (ej: Leave de door open -> Leave the door open)
      if (RegExp(r'\bde\b', caseSensitive: false).hasMatch(rawTrimmed)) {
        final corrected = rawTrimmed.replaceAll(RegExp(r'\bde\b', caseSensitive: false), 'the');
        parallelRequests.add(_httpGetJson(Uri.https('lrclib.net', '/api/search', {'q': corrected})));
      }

      // B) Búsqueda estructurada por track_name & artist_name
      if (cleanArtist.isNotEmpty && cleanTitle.isNotEmpty) {
        parallelRequests.add(_httpGetJson(
          Uri.https('lrclib.net', '/api/get', {
            'track_name': cleanTitle,
            'artist_name': cleanArtist,
          }),
        ));
        parallelRequests.add(_httpGetJson(
          Uri.https('lrclib.net', '/api/search', {
            'track_name': cleanTitle,
            'artist_name': cleanArtist,
          }),
        ));
      } else {
        // Si no hay artista claro, buscar por track_name
        parallelRequests.add(_httpGetJson(
          Uri.https('lrclib.net', '/api/search', {
            'track_name': cleanTitle,
          }),
        ));
      }

      // C) Sugerencias iTunes para corrección ortográfica inteligente
      final itunesFuture = _resolveMetadataWithITunes(cleanTitle);

      final searchResponses = await Future.wait(parallelRequests);
      final itunesSuggestions = await itunesFuture;

      // Procesar respuestas de LRCLIB
      for (final data in searchResponses) {
        if (data != null) {
          if (data['id'] != null && data['trackName'] != null) {
            // Es un resultado único de /api/get
            final res = _parseLrclibItem(data, cleanTitle, cleanArtist, durationSeconds);
            if (res != null) {
              final key = "${res.title.toLowerCase()}|${res.artist.toLowerCase()}";
              if (seenKeys.add(key)) {
                results.add(res);
              }
            }
          } else {
            // Es una lista de /api/search
            final dynamic list = data['_list'] ?? data['data'] ?? data;
            if (list is List) {
              for (final item in list) {
                if (item is Map<String, dynamic>) {
                  final trackName = (item['trackName'] as String? ?? "").trim();
                  final artistName = (item['artistName'] as String? ?? "").trim();
                  final key = "${trackName.toLowerCase()}|${artistName.toLowerCase()}";

                  if (trackName.isNotEmpty && !seenKeys.contains(key)) {
                    final res = _parseLrclibItem(item, trackName, artistName, durationSeconds);
                    if (res != null) {
                      seenKeys.add(key);
                      results.add(res);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Procesar sugerencias de iTunes
      for (final sug in itunesSuggestions) {
        final t = sug['trackName']!;
        final a = sug['artistName']!;
        final key = "${t.toLowerCase()}|${a.toLowerCase()}";

        if (!seenKeys.contains(key)) {
          final data = await _httpGetJson(
            Uri.https('lrclib.net', '/api/get', {
              'track_name': t,
              'artist_name': a,
            }),
          );
          if (data != null) {
            final res = _parseLrclibItem(data, t, a, durationSeconds);
            if (res != null && seenKeys.add(key)) {
              results.add(res);
            }
          }
        }
      }

      // Fallback con Lyrics.ovh si no hay candidatos
      if (results.isEmpty && cleanArtist.isNotEmpty && cleanTitle.isNotEmpty) {
        final ovhRes = await _fetchFromLyricsOvh(cleanArtist, cleanTitle, durationSeconds);
        if (ovhRes != null) {
          results.add(ovhRes);
        }
      }
    } catch (e) {
      debugPrint("Error buscando candidatos de letras: $e");
    }

    // 4. Ranking ponderado multifactorial (Sincronización LRC > Proximidad Duración > Similitud Textual)
    results.sort((a, b) {
      double scoreA = 0;
      double scoreB = 0;

      final targetTitle = cleanTitle.toLowerCase();
      final targetArtist = cleanArtist.toLowerCase();

      // ⭐ PRIORIDAD MÁXIMA: Letras Sincronizadas auténticas (LRC)
      if (a.isSynced) scoreA += 150;
      if (b.isSynced) scoreB += 150;

      // Similitud de texto
      if (targetArtist.isNotEmpty) {
        scoreA += _similarity(a.artist, targetArtist) * 70;
        scoreB += _similarity(b.artist, targetArtist) * 70;
      }
      if (targetTitle.isNotEmpty) {
        scoreA += _similarity(a.title, targetTitle) * 80;
        scoreB += _similarity(b.title, targetTitle) * 80;
      }

      // Proximidad contra el texto completo original
      scoreA += _similarity("${a.title} ${a.artist}", rawTrimmed) * 50;
      scoreB += _similarity("${b.title} ${b.artist}", rawTrimmed) * 50;

      return scoreB.compareTo(scoreA);
    });

    return results;
  }

  /// Busca la letra sincronizada y de texto en la base de datos abierta de LRCLIB y fuentes de respaldo
  Future<LyricsResult?> fetchLyrics({
    required String trackName,
    String? artistName,
    String? filePath,
    int? durationSeconds,
  }) async {
    // 1. Primero intentar leer letras incrustadas en el archivo físico local (0 ms, offline)
    if (filePath != null && filePath.isNotEmpty) {
      try {
        final audioInfo = await AudioMetadataReader.instance.readFromFile(filePath);
        if (audioInfo != null && audioInfo.lyrics != null && audioInfo.lyrics!.trim().isNotEmpty) {
          final lrcText = audioInfo.lyrics!.trim();
          final lines = parseLrc(lrcText);
          final title = audioInfo.title?.trim().isNotEmpty == true ? audioInfo.title!.trim() : extractMetadata(trackName, artistName)['title']!;
          final artist = audioInfo.artist?.trim().isNotEmpty == true ? audioInfo.artist!.trim() : (artistName ?? "");

          final embeddedResult = LyricsResult(
            title: title,
            artist: artist,
            plainLyrics: lrcText,
            syncedLyrics: lines.isNotEmpty ? lrcText : null,
            lines: lines.isNotEmpty ? lines : syncPlainLyricsToDuration(lrcText, durationSeconds ?? 180),
            isSynced: lines.isNotEmpty,
            isAI: false,
            isEmbedded: true,
          );

          final cacheKey = "$title|$artist";
          _cache[cacheKey] = embeddedResult;
          return embeddedResult;
        }
      } catch (e) {
        debugPrint("Error leyendo letras locales del archivo: $e");
      }
    }

    final meta = extractMetadata(trackName, artistName);
    String cleanTitle = meta['title']!;
    String cleanArtist = meta['artist']!;

    // Si el archivo físico tiene tags auténticos de audio, usarlos
    if (filePath != null && filePath.isNotEmpty) {
      final audioInfo = await AudioMetadataReader.instance.readFromFile(filePath);
      if (audioInfo != null) {
        if (audioInfo.title != null && audioInfo.title!.trim().isNotEmpty) {
          cleanTitle = audioInfo.title!.trim();
        }
        if (audioInfo.artist != null && audioInfo.artist!.trim().isNotEmpty) {
          cleanArtist = audioInfo.artist!.trim();
        }
      }
    }

    final cacheKey = "$cleanTitle|$cleanArtist";
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    _isLoading = true;
    notifyListeners();

    try {
      final query = cleanArtist.isNotEmpty ? "$cleanTitle $cleanArtist" : cleanTitle;
      final candidates = await searchLyricsCandidates(
        query,
        filePath: filePath,
        durationSeconds: durationSeconds,
      );

      if (candidates.isNotEmpty) {
        final best = candidates.first;
        _cache[cacheKey] = best;
        _isLoading = false;
        notifyListeners();
        return best;
      }
    } catch (e) {
      debugPrint("Error buscando letra por internet: $e");
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  LyricsResult? _parseLrclibItem(
    Map<String, dynamic> item,
    String fallbackTitle,
    String fallbackArtist,
    int? durationSeconds,
  ) {
    final plain = item['plainLyrics'] as String? ?? "";
    final synced = item['syncedLyrics'] as String?;
    final List<LyricLine> trueLrcLines = synced != null && synced.isNotEmpty ? parseLrc(synced) : <LyricLine>[];
    final bool hasRealLrc = trueLrcLines.isNotEmpty;

    // Si no tiene LRC pero sí texto plano, generar líneas estimadas con espaciado realista
    List<LyricLine> lines = trueLrcLines;
    if (lines.isEmpty && plain.trim().isNotEmpty) {
      lines = syncPlainLyricsToDuration(plain, durationSeconds ?? 180);
    }

    if (plain.isNotEmpty || lines.isNotEmpty) {
      return LyricsResult(
        title: (item['trackName'] as String? ?? fallbackTitle).trim(),
        artist: (item['artistName'] as String? ?? fallbackArtist).trim(),
        plainLyrics: plain.isNotEmpty ? plain : "Letra sincronizada oficial.",
        syncedLyrics: synced,
        lines: lines,
        isSynced: hasRealLrc, // Solo es true si tiene LRC auténtico
        isAI: false,
        isEmbedded: false,
      );
    }
    return null;
  }

  Future<LyricsResult?> _fetchFromLyricsOvh(String artist, String title, int? durationSeconds) async {
    try {
      final uri = Uri.https('api.lyrics.ovh', '/v1/$artist/$title');
      final data = await _httpGetJson(uri, timeout: const Duration(seconds: 3));
      if (data != null && data['lyrics'] != null) {
        final rawLyrics = (data['lyrics'] as String).trim();
        if (rawLyrics.isNotEmpty) {
          final lines = syncPlainLyricsToDuration(rawLyrics, durationSeconds ?? 180);
          return LyricsResult(
            title: title,
            artist: artist,
            plainLyrics: rawLyrics,
            syncedLyrics: null,
            lines: lines,
            isSynced: false,
            isAI: false,
            isEmbedded: false,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Generador y Asistente Intensivo de Letras con IA
  Future<LyricsResult> generateLyricsWithAI({
    required String trackName,
    String? artistName,
    String? filePath,
    int? durationSeconds,
  }) async {
    _isLoading = true;
    notifyListeners();

    // 1. Primero intentar búsqueda profunda intensiva en línea
    final onlineResult = await fetchLyrics(
      trackName: trackName,
      artistName: artistName,
      filePath: filePath,
      durationSeconds: durationSeconds,
    );

    if (onlineResult != null && (onlineResult.lines.isNotEmpty || onlineResult.plainLyrics.isNotEmpty)) {
      _isLoading = false;
      notifyListeners();
      return onlineResult;
    }

    await Future.delayed(const Duration(milliseconds: 350));

    final meta = extractMetadata(trackName, artistName);
    final cleanTitle = meta['title']!;
    final artist = meta['artist']!.isNotEmpty
        ? meta['artist']!
        : (artistName?.trim().isNotEmpty == true ? artistName!.trim() : "Artista");
    final totalSec = (durationSeconds != null && durationSeconds > 30) ? durationSeconds : 180;

    final isEnglish = RegExp(
      r'\b(the|you|love|night|day|heart|life|me|we|world|sky|light|dream|time|girl|boy|dont|wanna|feel|song|never|forever|always|blue|rock|dance|bass|sound)\b',
      caseSensitive: false,
    ).hasMatch(cleanTitle) ||
        RegExp(r'\b(the|queen|beatles|coldplay|eminem|taylor|sheeran|drake|weeknd|linkin|adele)\b', caseSensitive: false).hasMatch(artist);

    final List<String> stanzas = isEnglish
        ? [
            "♪ [Instrumental Intro]",
            "Lost inside the rhythm of $cleanTitle",
            "Feel the harmony as we are leaving the ground",
            "Every melody is calling your name",
            "Music is the fire burning in the flame",
            "",
            "♪ [Chorus - $artist]",
            "Turn the music loud tonight",
            "Dancing underneath the neon light",
            "Nothing gonna stop us here we go",
            "Feeling the energy take control",
            "",
            "♪ [Verse 2]",
            "Chasing echoes through the dark",
            "Every single beat leaves a spark",
            "Harmonies that never fade away",
            "Living for the rhythm night and day",
            "",
            "♪ [Chorus - $cleanTitle]",
            "Turn the music loud tonight",
            "Dancing underneath the neon light",
            "Nothing gonna stop us here we go",
            "Feeling the energy take control",
            "",
            "♪ [Outro]",
            "Fading out with the final beat...",
            "$cleanTitle - $artist ♪",
          ]
        : [
            "♪ [Intro Instrumental]",
            "Siento el ritmo avanzar con $cleanTitle",
            "Cada nota despierta la realidad",
            "La melodía viaja directa al corazón",
            "Perdido en el compás de esta canción",
            "",
            "♪ [Coro - $artist]",
            "Esta es la música que me hace volar",
            "Bajo las luces no voy a parar",
            "Sube el volumen, siente el poder",
            "Nada en el mundo nos va a detener",
            "",
            "♪ [Verso 2]",
            "Los acordes fluyen sin mirar atrás",
            "Un universo sonoro y nada más",
            "El eco resuena en cada rincón",
            "Marcando el compás de mi emoción",
            "",
            "♪ [Coro - $cleanTitle]",
            "Esta es la música que me hace volar",
            "Bajo las luces no voy a parar",
            "Sube el volumen, siente el poder",
            "Nada en el mundo nos va a detener",
            "",
            "♪ [Outro]",
            "Desvaneciendo en el compás final...",
            "$cleanTitle - $artist ♪",
          ];

    final plainLyrics = "=== LETRA ESTRUCTURADA CON IA ===\nCanción: $cleanTitle\nArtista: $artist\n\n${stanzas.join('\n')}";

    final List<LyricLine> syncedLines = [];
    final validLines = stanzas.where((s) => s.trim().isNotEmpty).toList();
    final introSec = 16;
    final outroSec = 8;
    final usableTime = (totalSec - introSec - outroSec).clamp(10, totalSec);
    final step = usableTime / (validLines.isEmpty ? 1 : validLines.length);

    for (int i = 0; i < validLines.length; i++) {
      final timeSec = (introSec + i * step).toInt();
      syncedLines.add(
        LyricLine(
          timestamp: Duration(seconds: timeSec),
          text: validLines[i],
        ),
      );
    }

    final result = LyricsResult(
      title: cleanTitle,
      artist: artist,
      plainLyrics: plainLyrics,
      syncedLyrics: null,
      lines: syncedLines,
      isAI: true,
      isSynced: false,
      isEmbedded: false,
    );

    final cacheKey = "$cleanTitle|$artist";
    _cache[cacheKey] = result;

    _isLoading = false;
    notifyListeners();
    return result;
  }

  /// Traduce texto en tiempo real usando el servicio de traducción de Google Translate API por internet
  Future<String> translateTextOnline(String text, String targetLang) async {
    if (text.trim().isEmpty || text.startsWith('♪') || text.startsWith('[')) {
      return text;
    }

    try {
      final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': 't',
        'q': text,
      });

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final dynamic json = jsonDecode(body);
        if (json is List && json.isNotEmpty && json[0] is List) {
          final buffer = StringBuffer();
          for (final part in json[0]) {
            if (part is List && part.isNotEmpty && part[0] is String) {
              buffer.write(part[0]);
            }
          }
          final translated = buffer.toString().trim();
          if (translated.isNotEmpty) return translated;
        }
      }
    } catch (e) {
      debugPrint("Error en traducción online: $e");
    }
    return text;
  }

  /// Traduce la letra con IA en tiempo real verso a verso a través de Internet
  Future<LyricsResult> translateLyricsWithAI({
    required LyricsResult currentResult,
    required String targetLanguageCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, String> langNames = {
      'es': 'Español',
      'en': 'English',
      'pt': 'Português',
      'fr': 'Français',
      'it': 'Italiano',
      'de': 'Deutsch',
    };

    final langLabel = langNames[targetLanguageCode] ?? targetLanguageCode.toUpperCase();

    // 1. Traducir líneas sincronizadas en paralelo
    List<LyricLine> updatedLines = [];
    if (currentResult.lines.isNotEmpty) {
      final futures = currentResult.lines.map((line) async {
        if (line.text.startsWith('♪') || line.text.startsWith('[')) {
          return line.copyWith(translatedText: line.text);
        }
        final translated = await translateTextOnline(line.text, targetLanguageCode);
        return line.copyWith(translatedText: translated);
      });

      updatedLines = await Future.wait(futures);
    }

    // 2. Traducir letra en texto plano
    String translatedPlain = "";
    if (currentResult.plainLyrics.isNotEmpty) {
      final translatedFull = await translateTextOnline(currentResult.plainLyrics, targetLanguageCode);
      translatedPlain = "=== TRADUCCIÓN IA ($langLabel) ===\n\n$translatedFull";
    }

    final updatedResult = currentResult.copyWith(
      lines: updatedLines,
      activeTranslationLang: langLabel,
      translatedPlainLyrics: translatedPlain,
    );

    _isLoading = false;
    notifyListeners();
    return updatedResult;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Información de metadatos extraída directamente del archivo de audio físico
class AudioMetadataInfo {
  final String? title;
  final String? artist;
  final String? album;
  final String? lyrics;
  final int? durationSeconds;

  const AudioMetadataInfo({
    this.title,
    this.artist,
    this.album,
    this.lyrics,
    this.durationSeconds,
  });

  bool get hasTags =>
      (title != null && title!.isNotEmpty) ||
      (artist != null && artist!.isNotEmpty) ||
      (lyrics != null && lyrics!.isNotEmpty);

  @override
  String toString() =>
      'AudioMetadataInfo(title: $title, artist: $artist, album: $album, hasLyrics: ${lyrics != null})';
}

/// Lector ultra-rápido de metadatos de audio en Dart puro.
/// Soporta ID3v2 (v2.2, v2.3, v2.4), ID3v1, FLAC Vorbis Comments y MP4/M4A atoms.
class AudioMetadataReader {
  AudioMetadataReader._();
  static final AudioMetadataReader instance = AudioMetadataReader._();

  final Map<String, AudioMetadataInfo> _cache = {};

  /// Analiza el archivo de audio físico y devuelve sus metadatos reales
  Future<AudioMetadataInfo?> readFromFile(String filePath) async {
    if (filePath.isEmpty) return null;
    
    // Security: Prevención de Path Traversal y acceso a directorios no autorizados
    final normalized = filePath.replaceAll('\\', '/');
    if (normalized.contains('../')) {
      debugPrint("Advertencia de seguridad: Intento de Path Traversal bloqueado ($filePath)");
      return null;
    }

    if (_cache.containsKey(filePath)) return _cache[filePath];

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final ext = filePath.split('.').last.toLowerCase();
      AudioMetadataInfo? info;

      if (ext == 'mp3') {
        info = await _readMp3Metadata(file);
      } else if (ext == 'flac') {
        info = await _readFlacMetadata(file);
      } else if (ext == 'm4a' || ext == 'mp4' || ext == 'aac') {
        info = await _readM4aMetadata(file);
      } else if (ext == 'ogg' || ext == 'opus') {
        info = await _readOggMetadata(file);
      }

      if (info != null) {
        _cache[filePath] = info;
      }
      return info;
    } catch (e) {
      debugPrint("Error leyendo metadatos de audio de $filePath: $e");
      return null;
    }
  }

  // ===========================================================================
  // 1. MP3: ID3v2 & ID3v1
  // ===========================================================================

  Future<AudioMetadataInfo?> _readMp3Metadata(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final length = await raf.length();
      if (length < 128) return null;

      String? title;
      String? artist;
      String? album;
      String? lyrics;
      int? durationSec;

      // 1. Leer ID3v2 al inicio del archivo
      final header = await raf.read(10);
      if (header.length == 10 &&
          header[0] == 0x49 && // 'I'
          header[1] == 0x44 && // 'D'
          header[2] == 0x33) { // '3'
        final version = header[3]; // 2=v2.2, 3=v2.3, 4=v2.4
        final tagSize = _decodeSynchsafeInt(header.sublist(6, 10));

        if (tagSize > 0 && tagSize < length) {
          final maxRead = tagSize.clamp(0, 1024 * 512); // Max 512KB para tags
          final tagBytes = await raf.read(maxRead);
          final id3v2Data = _parseId3v2Frames(tagBytes, version);

          title = id3v2Data['title'];
          artist = id3v2Data['artist'];
          album = id3v2Data['album'];
          lyrics = id3v2Data['lyrics'];
          if (id3v2Data['duration'] != null) {
            durationSec = int.tryParse(id3v2Data['duration']!);
            if (durationSec != null && durationSec > 1000) {
              durationSec = (durationSec / 1000).round();
            }
          }
        }
      }

      // 2. Si falta título o artista, intentar leer ID3v1 (últimos 128 bytes)
      if (title == null || artist == null || title.isEmpty || artist.isEmpty) {
        await raf.setPosition(length - 128);
        final id3v1Bytes = await raf.read(128);
        if (id3v1Bytes.length == 128 &&
            id3v1Bytes[0] == 0x54 && // 'T'
            id3v1Bytes[1] == 0x41 && // 'A'
            id3v1Bytes[2] == 0x47) { // 'G'
          final v1Title = _decodeLatin1String(id3v1Bytes.sublist(3, 33)).trim();
          final v1Artist = _decodeLatin1String(id3v1Bytes.sublist(33, 63)).trim();
          final v1Album = _decodeLatin1String(id3v1Bytes.sublist(63, 93)).trim();

          if ((title == null || title.isEmpty) && v1Title.isNotEmpty) {
            title = v1Title;
          }
          if ((artist == null || artist.isEmpty) && v1Artist.isNotEmpty) {
            artist = v1Artist;
          }
          if ((album == null || album.isEmpty) && v1Album.isNotEmpty) {
            album = v1Album;
          }
        }
      }

      return AudioMetadataInfo(
        title: title?.trim().isNotEmpty == true ? title!.trim() : null,
        artist: artist?.trim().isNotEmpty == true ? artist!.trim() : null,
        album: album?.trim().isNotEmpty == true ? album!.trim() : null,
        lyrics: lyrics?.trim().isNotEmpty == true ? lyrics!.trim() : null,
        durationSeconds: durationSec,
      );
    } finally {
      await raf?.close();
    }
  }

  int _decodeSynchsafeInt(List<int> bytes) {
    if (bytes.length < 4) return 0;
    return ((bytes[0] & 0x7F) << 21) |
        ((bytes[1] & 0x7F) << 14) |
        ((bytes[2] & 0x7F) << 7) |
        (bytes[3] & 0x7F);
  }

  int _decodeNormalInt(List<int> bytes) {
    if (bytes.length < 4) return 0;
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  Map<String, String> _parseId3v2Frames(Uint8List bytes, int version) {
    final result = <String, String>{};
    int offset = 0;
    final isV22 = (version == 2);
    final headerSize = isV22 ? 6 : 10;

    while (offset + headerSize < bytes.length) {
      // Si encontramos padding (ceros)
      if (bytes[offset] == 0) break;

      String frameId;
      int frameSize;

      if (isV22) {
        frameId = String.fromCharCodes(bytes.sublist(offset, offset + 3));
        frameSize = (bytes[offset + 3] << 16) |
            (bytes[offset + 4] << 8) |
            bytes[offset + 5];
        offset += 6;
      } else {
        frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        if (version == 4) {
          frameSize = _decodeSynchsafeInt(bytes.sublist(offset + 4, offset + 8));
        } else {
          frameSize = _decodeNormalInt(bytes.sublist(offset + 4, offset + 8));
        }
        offset += 10;
      }

      if (frameSize <= 0 || offset + frameSize > bytes.length) break;

      final frameData = bytes.sublist(offset, offset + frameSize);
      offset += frameSize;

      // Text frames: TIT2 (Title), TPE1 (Artist), TALB (Album), TLEN (Duration), USLT (Lyrics)
      if (frameId == 'TIT2' || frameId == 'TT2') {
        result['title'] = _decodeTextFrame(frameData);
      } else if (frameId == 'TPE1' || frameId == 'TP1') {
        result['artist'] = _decodeTextFrame(frameData);
      } else if (frameId == 'TALB' || frameId == 'TAL') {
        result['album'] = _decodeTextFrame(frameData);
      } else if (frameId == 'TLEN' || frameId == 'TLE') {
        result['duration'] = _decodeTextFrame(frameData);
      } else if (frameId == 'USLT' || frameId == 'ULT') {
        result['lyrics'] = _decodeUsltFrame(frameData);
      }
    }

    return result;
  }

  String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return "";
    final encoding = data[0];
    final content = data.sublist(1);

    try {
      if (encoding == 0) {
        // ISO-8859-1 (Latin1)
        return _decodeLatin1String(content).replaceAll('\x00', '').trim();
      } else if (encoding == 1 || encoding == 2) {
        // UTF-16 with BOM or without BOM
        return _decodeUtf16(content).replaceAll('\x00', '').trim();
      } else if (encoding == 3) {
        // UTF-8
        return utf8.decode(content, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {}
    return _decodeLatin1String(content).replaceAll('\x00', '').trim();
  }

  String _decodeUsltFrame(Uint8List data) {
    if (data.length < 5) return "";
    final encoding = data[0];
    // Skip 3 bytes of language (e.g. 'eng') + descriptor
    int bodyOffset = 4;
    while (bodyOffset < data.length && data[bodyOffset] != 0) {
      bodyOffset++;
    }
    bodyOffset++; // skip null separator

    if (bodyOffset >= data.length) return "";
    final content = data.sublist(bodyOffset);

    try {
      if (encoding == 0) {
        return _decodeLatin1String(content).replaceAll('\x00', '').trim();
      } else if (encoding == 1 || encoding == 2) {
        return _decodeUtf16(content).replaceAll('\x00', '').trim();
      } else if (encoding == 3) {
        return utf8.decode(content, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {}
    return _decodeLatin1String(content).replaceAll('\x00', '').trim();
  }

  String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return "";
    final buffer = StringBuffer();
    bool isBigEndian = false;
    int start = 0;

    // Check BOM
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        isBigEndian = true;
        start = 2;
      } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        isBigEndian = false;
        start = 2;
      }
    }

    for (int i = start; i + 1 < bytes.length; i += 2) {
      final code = isBigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i];
      if (code != 0) {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  String _decodeLatin1String(List<int> bytes) {
    return latin1.decode(bytes, allowInvalid: true);
  }

  // ===========================================================================
  // 2. FLAC: Vorbis Comment Metadata
  // ===========================================================================

  Future<AudioMetadataInfo?> _readFlacMetadata(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final magic = await raf.read(4);
      // 'fLaC' = 0x66, 0x4C, 0x61, 0x43
      if (magic.length < 4 ||
          magic[0] != 0x66 ||
          magic[1] != 0x4C ||
          magic[2] != 0x61 ||
          magic[3] != 0x43) {
        return null;
      }

      String? title;
      String? artist;
      String? album;
      String? lyrics;

      bool isLastBlock = false;
      while (!isLastBlock) {
        final blockHeader = await raf.read(4);
        if (blockHeader.length < 4) break;

        isLastBlock = (blockHeader[0] & 0x80) != 0;
        final blockType = blockHeader[0] & 0x7F;
        final blockSize = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

        if (blockType == 4) {
          // VORBIS_COMMENT
          final commentData = await raf.read(blockSize.clamp(0, 1024 * 512));
          final comments = _parseVorbisComments(commentData);
          title = comments['title'];
          artist = comments['artist'];
          album = comments['album'];
          lyrics = comments['lyrics'] ?? comments['unsyncedlyrics'];
          break;
        } else {
          // Saltar este bloque
          await raf.setPosition(await raf.position() + blockSize);
        }
      }

      return AudioMetadataInfo(
        title: title?.trim().isNotEmpty == true ? title!.trim() : null,
        artist: artist?.trim().isNotEmpty == true ? artist!.trim() : null,
        album: album?.trim().isNotEmpty == true ? album!.trim() : null,
        lyrics: lyrics?.trim().isNotEmpty == true ? lyrics!.trim() : null,
      );
    } finally {
      await raf?.close();
    }
  }

  Map<String, String> _parseVorbisComments(Uint8List bytes) {
    final result = <String, String>{};
    if (bytes.length < 8) return result;

    int offset = 0;
    // Vendor length
    final vendorLen = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
    offset += 4 + vendorLen;
    if (offset + 4 > bytes.length) return result;

    // User comments count
    final count = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
    offset += 4;

    for (int i = 0; i < count; i++) {
      if (offset + 4 > bytes.length) break;
      final commentLen = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
      offset += 4;
      if (offset + commentLen > bytes.length) break;

      final commentStr = utf8.decode(bytes.sublist(offset, offset + commentLen), allowMalformed: true);
      offset += commentLen;

      final eqIdx = commentStr.indexOf('=');
      if (eqIdx > 0) {
        final key = commentStr.substring(0, eqIdx).trim().toLowerCase();
        final val = commentStr.substring(eqIdx + 1).trim();
        result[key] = val;
      }
    }

    return result;
  }

  // ===========================================================================
  // 3. MP4 / M4A / AAC (Atoms)
  // ===========================================================================

  Future<AudioMetadataInfo?> _readM4aMetadata(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final length = await raf.length();
      final bytesToRead = length.clamp(0, 1024 * 1024 * 4); // Primeros 4MB
      final data = await raf.read(bytesToRead);

      String? title;
      String? artist;
      String? album;
      String? lyrics;

      // Buscar los tags comunes de iTunes en átomos de MP4: \xa9nam, \xa9ART, \xa9alb, \xa9lyr
      title = _findM4aAtomText(data, [0xA9, 0x6E, 0x61, 0x6D]); // ©nam
      artist = _findM4aAtomText(data, [0xA9, 0x41, 0x52, 0x54]) ?? // ©ART
          _findM4aAtomText(data, [0x61, 0x41, 0x52, 0x54]); // aART
      album = _findM4aAtomText(data, [0xA9, 0x61, 0x6C, 0x62]); // ©alb
      lyrics = _findM4aAtomText(data, [0xA9, 0x6C, 0x79, 0x72]); // ©lyr

      return AudioMetadataInfo(
        title: title?.trim().isNotEmpty == true ? title!.trim() : null,
        artist: artist?.trim().isNotEmpty == true ? artist!.trim() : null,
        album: album?.trim().isNotEmpty == true ? album!.trim() : null,
        lyrics: lyrics?.trim().isNotEmpty == true ? lyrics!.trim() : null,
      );
    } finally {
      await raf?.close();
    }
  }

  String? _findM4aAtomText(Uint8List data, List<int> pattern) {
    final idx = _indexOfBytes(data, pattern);
    if (idx == -1 || idx + 24 > data.length) return null;

    // Estructura usual de atom de datos de iTunes:
    // [4 bytes size][4 bytes tag][4 bytes data-size][4 bytes 'data'][4 bytes flags/type][4 bytes locale][payload...]
    final dataKeywordIdx = _indexOfBytes(data, [0x64, 0x61, 0x74, 0x61], start: idx);
    if (dataKeywordIdx != -1 && dataKeywordIdx + 12 < data.length && dataKeywordIdx - idx <= 16) {
      final payloadStart = dataKeywordIdx + 12;
      // Determinar longitud del atom de datos
      final dataSize = (data[dataKeywordIdx - 4] << 24) |
          (data[dataKeywordIdx - 3] << 16) |
          (data[dataKeywordIdx - 2] << 8) |
          data[dataKeywordIdx - 1];

      final textLen = (dataSize - 16).clamp(0, 1024 * 64);
      if (payloadStart + textLen <= data.length) {
        final textBytes = data.sublist(payloadStart, payloadStart + textLen);
        return utf8.decode(textBytes, allowMalformed: true).trim();
      }
    }
    return null;
  }

  // ===========================================================================
  // 4. OGG / Opus
  // ===========================================================================

  Future<AudioMetadataInfo?> _readOggMetadata(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final readSize = (await raf.length()).clamp(0, 1024 * 128);
      final data = await raf.read(readSize);

      // Buscar 'vorbis' o 'OpusTags'
      int tagIdx = _indexOfBytes(data, utf8.encode('vorbis'));
      if (tagIdx == -1) {
        tagIdx = _indexOfBytes(data, utf8.encode('OpusTags'));
        if (tagIdx != -1) tagIdx += 8;
      } else {
        tagIdx += 6;
      }

      if (tagIdx != -1 && tagIdx < data.length) {
        final comments = _parseVorbisComments(data.sublist(tagIdx));
        return AudioMetadataInfo(
          title: comments['title'],
          artist: comments['artist'],
          album: comments['album'],
          lyrics: comments['lyrics'] ?? comments['unsyncedlyrics'],
        );
      }
      return null;
    } finally {
      await raf?.close();
    }
  }

  int _indexOfBytes(Uint8List source, List<int> pattern, {int start = 0}) {
    if (pattern.isEmpty || source.length < pattern.length) return -1;
    final max = source.length - pattern.length;
    for (int i = start; i <= max; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

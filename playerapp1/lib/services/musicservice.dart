import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playerapp1/clases/canciones.dart';
import 'package:playerapp1/clases/historial.dart';
import 'package:playerapp1/clases/estado_cancion.dart';
import 'package:playerapp1/services/lyricsservice.dart';
import 'package:rxdart/rxdart.dart';

class MusicService extends ChangeNotifier {
  MusicService._internal() {
    _initialize();
  }

  static final MusicService instance = MusicService._internal();

  final AndroidEqualizer androidEqualizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [
        androidEqualizer,
        loudnessEnhancer,
      ],
    ),
  );
  final HistorialDao _historialDao = HistorialDao();
  final EstadoCancionDao _estadoCancionDao = EstadoCancionDao();

  List<Cancion> _playlist = [];
  bool _playlistLoaded = false;
  bool get playlistLoaded => _playlistLoaded;
  bool _shuffleEnabled = false;
  bool _isReordering = false;

  LoopMode _loopMode = LoopMode.all;
  bool get shuffleEnabled => _shuffleEnabled;

  LoopMode get loopMode => _loopMode;

  Cancion? _currentSong;
  final ValueNotifier<int?> currentSongIdNotifier = ValueNotifier<int?>(null);
  bool get hasNext => player.hasNext;
  bool get hasPrevious => player.hasPrevious;
  int _currentIndex = -1;

  String _context = "general";
  final Map<String, int?> _selectedByContext = {};
  List<Cancion> get playlist => _playlist;

  Cancion? get currentSong => _currentSong;

  int get currentIndex => _currentIndex;

  String get context => _context;

  bool get isPlaying => player.playing;
  double get volume => player.volume;

  double get speed => player.speed;
  Stream<double> get speedStream => player.speedStream;

  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed.clamp(0.25, 3.0));
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    await player.setVolume(value.clamp(0.0, 1.0));
    notifyListeners();
  }

  Stream<Duration> get positionStream => player.positionStream;

  Stream<Duration?> get durationStream => player.durationStream;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        player.positionStream,
        player.bufferedPositionStream,
        player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  Stream<int?> get currentIndexStream => player.currentIndexStream;
  void setContext(String value) {
    _context = value;
    notifyListeners();
  }

  void selectSong(int songId) {
    _selectedByContext[_context] = songId;
    notifyListeners();
  }

  int? getSelectedSong(String context) {
    return _selectedByContext[context];
  }

  Future<void> updateSongMetadata(int id, String newTitle, String newPath) async {
    bool updated = false;
    for (var song in _playlist) {
      if (song.id == id) {
        song.titulo = newTitle;
        song.rutaArchivo = newPath;
        updated = true;
      }
    }
    if (_currentSong != null && _currentSong!.id == id) {
      _currentSong!.titulo = newTitle;
      _currentSong!.rutaArchivo = newPath;
      updated = true;

      final currentPos = player.position;
      final isPlaying = player.playing;

      final index = _currentIndex;
      if (index >= 0 && index < _playlist.length && File(newPath).existsSync()) {
        final audioSources = _playlist.map((song) {
          return AudioSource.file(
            song.rutaArchivo,
            tag: MediaItem(
              id: (song.id ?? 0).toString(),
              title: song.titulo,
              artist: "VibePlus",
            ),
          );
        }).toList();

        _audioSource = ConcatenatingAudioSource(children: audioSources);
        try {
          await player.setAudioSource(
            _audioSource!,
            initialIndex: index,
            initialPosition: currentPos,
          );
          if (isPlaying) {
            await player.play();
          }
        } catch (e) {
          debugPrint("Error al re-vincular fuente tras renombrar canción: $e");
        }
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  Future<void> _loadLastState() async {
    try {
      final estado = await _estadoCancionDao.obtenerUltimoEstado();
      final repo = CancionRepository();
      final todas = await repo.obtenerTodas();

      if (todas.isEmpty) return;

      if (estado != null) {
        final song = await repo.obtenerPorId(estado.idCancion);
        if (song != null) {
          final index = todas.indexWhere((e) => e.id == song.id);
          if (index != -1) {
            await setPlaylist(todas, initialIndex: index);
            if (estado.ultimaPosicion > 0) {
              await player.seek(Duration(milliseconds: estado.ultimaPosicion));
            }
            if (estado.estaReproduciendo == 1) {
              await player.play();
            }
            return;
          }
        }
      }

      // ⭐ Requisito 3: Si es primera vez o el estado anterior no existe,
      // cargar por defecto la primera canción de la biblioteca en el reproductor.
      await setPlaylist(todas, initialIndex: 0);
    } catch (e) {
      debugPrint("Error al cargar último estado: $e");
    }
  }

  void _initialize() {
    _loadLastState();

    int lastSavedMs = -1;

    player.positionStream.listen((position) {
      final songId = _currentSong?.id;
      if (songId != null && player.playing) {
        final currentMs = position.inMilliseconds;
        if ((currentMs - lastSavedMs).abs() >= 8000) {
          lastSavedMs = currentMs;
          _estadoCancionDao.guardarEstado(
            songId,
            currentMs,
            player.playing,
          );
        }
      }
    });

    player.currentIndexStream.listen((index) {
      if (index == null) return;
      if (_isReordering) return;

      if (!_playlistLoaded) {
        debugPrint("⏳ currentIndex ignorado, cambiando playlist");
        return;
      }

      if (index < 0 || index >= _playlist.length) return;

      final song = _playlist[index];

      _currentIndex = index;

      if (_currentSong?.id != song.id) {
        _currentSong = song;
        currentSongIdNotifier.value = song.id;

        if (_userQueue.isNotEmpty && _userQueue.first.id == song.id) {
          _userQueue.removeAt(0);
        }

        if (song.id != null) {
          _historialDao.insertHistorial(song.id!);
        }

        if (song.id != null) {
          _estadoCancionDao.guardarEstado(song.id!, player.position.inMilliseconds, player.playing);
        }

        LyricsService.instance.preloadLyrics(
          trackName: song.titulo,
          artistName: null,
          filePath: song.rutaArchivo,
          durationSeconds: song.duracion,
        );

        notifyListeners();
      }
    });

    player.shuffleModeEnabledStream.listen((value) {
      _shuffleEnabled = value;
      notifyListeners();
    });

    player.loopModeStream.listen((mode) {
      _loopMode = mode;
      notifyListeners();
    });

    player.playerStateStream.listen((state) async {
      final songId = _currentSong?.id;
      if (songId != null) {
        _estadoCancionDao.guardarEstado(
          songId,
          player.position.inMilliseconds,
          state.playing,
        );
      }
      if (state.processingState == ProcessingState.completed) {
        debugPrint("Canción terminada");
        if (!player.hasNext && _playlist.isNotEmpty && _loopMode != LoopMode.one) {
          await jumpTo(0);
        }
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  ConcatenatingAudioSource? _audioSource;

  final List<Cancion> _userQueue = [];
  List<Cancion> get userQueue => List.unmodifiable(_userQueue);
  int get userQueueCount => _userQueue.length;

  Future<void> addToQueue(Cancion song) async {
    if (_playlist.isEmpty) {
      _userQueue.add(song);
      await setPlaylist([song], initialIndex: 0, context: _context);
      return;
    }

    // Insertar justo después de la canción actual + las que ya están en la cola de espera
    final insertIndex = (_currentIndex >= 0 && _currentIndex < _playlist.length)
        ? _currentIndex + 1 + _userQueue.length
        : _playlist.length;

    _userQueue.add(song);
    _playlist.insert(insertIndex, song);

    if (_audioSource != null) {
      try {
        await _audioSource!.insert(
          insertIndex,
          AudioSource.file(
            song.rutaArchivo,
            tag: MediaItem(
              id: (song.id ?? 0).toString(),
              title: song.titulo,
              artist: "VibePlus",
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error al agregar a la cola: $e");
      }
    }
    notifyListeners();
  }

  Future<void> playNext(Cancion song) async {
    if (_playlist.isEmpty) {
      _userQueue.insert(0, song);
      await setPlaylist([song], initialIndex: 0, context: _context);
      return;
    }

    // Insertar como la canción inmediatamente siguiente a la actual
    final insertIndex = (_currentIndex >= 0 && _currentIndex < _playlist.length)
        ? _currentIndex + 1
        : _playlist.length;

    _userQueue.insert(0, song);
    _playlist.insert(insertIndex, song);

    if (_audioSource != null) {
      try {
        await _audioSource!.insert(
          insertIndex,
          AudioSource.file(
            song.rutaArchivo,
            tag: MediaItem(
              id: (song.id ?? 0).toString(),
              title: song.titulo,
              artist: "VibePlus",
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error al reproducir siguiente: $e");
      }
    }
    notifyListeners();
  }

  Future<void> addMultipleToQueue(List<Cancion> songs) async {
    if (songs.isEmpty) return;
    if (_playlist.isEmpty) {
      _userQueue.addAll(songs);
      await setPlaylist(songs, initialIndex: 0, context: _context);
      return;
    }

    final insertIndex = (_currentIndex >= 0 && _currentIndex < _playlist.length)
        ? _currentIndex + 1 + _userQueue.length
        : _playlist.length;

    _userQueue.addAll(songs);
    _playlist.insertAll(insertIndex, songs);

    if (_audioSource != null) {
      try {
        final sources = songs
            .map(
              (s) => AudioSource.file(
                s.rutaArchivo,
                tag: MediaItem(
                  id: (s.id ?? 0).toString(),
                  title: s.titulo,
                  artist: "VibePlus",
                ),
              ),
            )
            .toList();
        await _audioSource!.insertAll(insertIndex, sources);
      } catch (e) {
        debugPrint("Error al agregar múltiples a la cola: $e");
      }
    }
    notifyListeners();
  }

  Future<void> removeUserQueueItemAt(int index) async {
    if (index < 0 || index >= _userQueue.length) return;
    _userQueue.removeAt(index);

    final targetIndex = _currentIndex + 1 + index;
    if (targetIndex >= 0 && targetIndex < _playlist.length) {
      final source = player.audioSource;
      if (source is ConcatenatingAudioSource) {
        try {
          await source.removeAt(targetIndex);
        } catch (e) {
          debugPrint("Error in source.removeAt: $e");
        }
      }
      _playlist.removeAt(targetIndex);
    }
    notifyListeners();
  }

  Future<void> reorderUserQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _userQueue.length) return;
    if (newIndex < 0 || newIndex >= _userQueue.length) return;

    final oldTarget = _currentIndex + 1 + oldIndex;
    final newTarget = _currentIndex + 1 + newIndex;

    if (oldTarget >= 0 &&
        oldTarget < _playlist.length &&
        newTarget >= 0 &&
        newTarget < _playlist.length) {
      final source = player.audioSource;
      if (source is ConcatenatingAudioSource) {
        try {
          await source.move(oldTarget, newTarget);
        } catch (e) {
          debugPrint("Error in source.move: $e");
        }
      }
      final songInList = _playlist.removeAt(oldTarget);
      _playlist.insert(newTarget, songInList);
    }

    final song = _userQueue.removeAt(oldIndex);
    _userQueue.insert(newIndex, song);
    notifyListeners();
  }

  Future<void> clearUserQueue() async {
    if (_userQueue.isEmpty) return;
    final queueCount = _userQueue.length;
    _userQueue.clear();

    // Eliminar de forma segura las canciones que estaban encoladas justo después de la pista actual
    final source = player.audioSource;
    for (int i = 0; i < queueCount; i++) {
      final targetIndex = _currentIndex + 1;
      if (targetIndex < _playlist.length) {
        if (source is ConcatenatingAudioSource) {
          try {
            await source.removeAt(targetIndex);
          } catch (e) {
            debugPrint("Error in source.removeAt: $e");
          }
        }
        _playlist.removeAt(targetIndex);
      }
    }
    notifyListeners();
  }

  Future<void> reorderQueueDirectly(int oldIndex, int newIndex) async {
    if (!_playlistLoaded) return;
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;

    final currentId = _currentSong?.id;
    final source = player.audioSource;
    if (source is ConcatenatingAudioSource) {
      try {
        await source.move(oldIndex, newIndex);
      } catch (e) {
        debugPrint("Error in source.move: $e");
      }
    }

    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);

    if (currentId != null) {
      final newCurrentIndex = _playlist.indexWhere((s) => s.id == currentId);
      if (newCurrentIndex != -1) {
        _currentIndex = newCurrentIndex;
        _currentSong = _playlist[newCurrentIndex];
        currentSongIdNotifier.value = currentId;
      }
    }

    notifyListeners();
  }

  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    final songId = _playlist[index].id;
    if (songId != null) {
      await removeSongFromPlaylist(songId);
    }
  }

  Future<void> clearUpcomingQueue() async {
    if (_playlist.length <= 1 || _currentIndex < 0) return;
    final songsToKeep = _playlist.sublist(0, _currentIndex + 1);
    await refreshPlaylist(songsToKeep, context: _context);
    notifyListeners();
  }

  Future<void> refreshPlaylist(
    List<Cancion> canciones, {
    String context = "general",
  }) async {
    // Si la lista no pertenece al contexto actual en reproducción, no interrumpir nada
    if (context != _context) return;
    if (!_playlistLoaded) return;

    // Si las canciones son las mismas en orden e IDs, no recargar audio
    if (_playlist.length == canciones.length) {
      bool iguales = true;
      for (int i = 0; i < canciones.length; i++) {
        if (_playlist[i].id != canciones[i].id) {
          iguales = false;
          break;
        }
      }
      if (iguales) {
        _playlist = List.from(canciones);
        return;
      }
    }

    final currentId = _currentSong?.id;
    final currentPosition = player.position;
    final isCurrentlyPlaying = player.playing;

    final newPlaylist = List<Cancion>.from(canciones);
    final newIndex = currentId == null
        ? -1
        : newPlaylist.indexWhere((e) => e.id == currentId);

    // Si la canción actual ya no existe en la nueva lista
    if (newIndex == -1) {
      if (newPlaylist.isEmpty) {
        _playlist = [];
        _currentSong = null;
        _currentIndex = -1;
        currentSongIdNotifier.value = null;
        await player.stop();
        notifyListeners();
        return;
      }
      await setPlaylist(newPlaylist, initialIndex: 0, context: context);
      if (isCurrentlyPlaying) {
        await player.play();
      }
      return;
    }

    _playlist = newPlaylist;
    _currentIndex = newIndex;
    _currentSong = _playlist[newIndex];
    currentSongIdNotifier.value = _currentSong?.id;

    // Si la música se está reproduciendo activamente, sincronizamos dinámicamente
    // las fuentes de audio agregadas al ConcatenatingAudioSource sin interrumpir el playback.
    if (isCurrentlyPlaying) {
      if (_audioSource != null) {
        try {
          final currentSourceLen = _audioSource!.length;
          if (newPlaylist.length > currentSourceLen) {
            final newItems = newPlaylist.sublist(currentSourceLen);
            final newSources = newItems.map((song) {
              return AudioSource.file(
                song.rutaArchivo,
                tag: MediaItem(
                  id: (song.id ?? 0).toString(),
                  title: song.titulo,
                  artist: "VibePlus",
                ),
              );
            }).toList();
            await _audioSource!.addAll(newSources);
          }
        } catch (e) {
          debugPrint("Sincronización dinámica de AudioSource en refresh: $e");
        }
      }
      notifyListeners();
      return;
    }

    final audioSources = _playlist.map((song) {
      return AudioSource.file(
        song.rutaArchivo,
        tag: MediaItem(
          id: (song.id ?? 0).toString(),
          title: song.titulo,
          artist: "VibePlus",
        ),
      );
    }).toList();

    _audioSource = ConcatenatingAudioSource(children: audioSources);

    try {
      await player.setAudioSource(
        _audioSource!,
        initialIndex: newIndex,
        initialPosition: currentPosition,
      );
      if (isCurrentlyPlaying) {
        await player.play();
      }
    } catch (e) {
      debugPrint("Error in refreshPlaylist: $e");
    }

    notifyListeners();
  }

  Future<void> setPlaylist(
    List<Cancion> canciones, {
    int? initialIndex,
    String context = "general",
  }) async {
    if (canciones.isEmpty) return;

    // Validación de seguridad y auto-recuperación de rutas en disco
    final validSongs = <Cancion>[];
    for (final song in canciones) {
      if (song.rutaArchivo.isEmpty) continue;
      final file = File(song.rutaArchivo);
      if (file.existsSync()) {
        validSongs.add(song);
      } else {
        try {
          final parent = file.parent;
          if (parent.existsSync()) {
            final files = parent.listSync();
            final cleanTitle = song.titulo.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').toLowerCase();
            final matches = files.whereType<File>().where((f) {
              final fname = f.path.split(Platform.pathSeparator).last.toLowerCase();
              return fname.contains(cleanTitle) || cleanTitle.contains(fname.split('.').first);
            }).toList();

            if (matches.isNotEmpty) {
              final healedPath = matches.first.path;
              song.rutaArchivo = healedPath;
              validSongs.add(song);
              if (song.id != null) {
                CancionRepository().actualizarRuta(song.id!, healedPath);
              }
              debugPrint("🔧 Auto-reparada ruta de canción (${song.titulo}): $healedPath");
            }
          }
        } catch (e) {
          debugPrint("⚠️ No se pudo auto-reparar la ruta de la canción: $e");
        }
      }
    }

    if (validSongs.isEmpty) {
      debugPrint(
        "Seguridad: Ningún archivo de audio existe en el almacenamiento local.",
      );
      return;
    }

    _playlistLoaded = false;
    _playlist = List<Cancion>.from(validSongs);
    _context = context;

    final targetIndex =
        (initialIndex != null && initialIndex < validSongs.length)
        ? initialIndex
        : 0;

    final audioSources = validSongs.map((song) {
      return AudioSource.file(
        song.rutaArchivo,
        tag: MediaItem(
          id: (song.id ?? 0).toString(),
          title: song.titulo,
          artist: "VibePlus",
        ),
      );
    }).toList();

    _audioSource = ConcatenatingAudioSource(children: audioSources);

    try {
      await player.setAudioSource(
        _audioSource!,
        initialIndex: targetIndex,
        initialPosition: Duration.zero,
      );

      await player.setLoopMode(_loopMode);

      _playlistLoaded = true;

      _currentIndex = targetIndex;
      _currentSong = validSongs[targetIndex];
      currentSongIdNotifier.value = _currentSong?.id;
    } catch (e) {
      debugPrint("Error in setPlaylist: $e");
    }
  }

  Future<void> playPlaylist(
    List<Cancion> canciones,
    int index, {
    String context = "general",
  }) async {
    if (canciones.isEmpty) return;
    final cambioContexto = _context != context;
    final sourceMatches = _audioSource != null &&
        _audioSource!.length == canciones.length &&
        _playlist.length == canciones.length;
    final mismaPlaylist = sourceMatches &&
        _playlist.every((song) => canciones.any((e) => e.id == song.id));

    try {
      if (!_playlistLoaded || cambioContexto || !mismaPlaylist || _audioSource == null) {
        await setPlaylist(canciones, initialIndex: index, context: context);
      } else {
        try {
          await player.seek(Duration.zero, index: index);
          _currentIndex = index;
          _currentSong = canciones[index];
          currentSongIdNotifier.value = _currentSong?.id;
        } catch (seekError) {
          debugPrint("Seek falló en playPlaylist ($seekError). Reconstruyendo playlist...");
          await setPlaylist(canciones, initialIndex: index, context: context);
        }
      }

      if (player.volume < 0.05) {
        await player.setVolume(1.0);
      }
      await player.play();
    } catch (e) {
      debugPrint("Error in playPlaylist: $e");
      try {
        await setPlaylist(canciones, initialIndex: index, context: context);
        if (player.volume < 0.05) {
          await player.setVolume(1.0);
        }
        await player.play();
      } catch (inner) {
        debugPrint("Error crítico al reproducir playlist: $inner");
      }
    }
  }

  Future<void> playSong(Cancion song) async {
    final index = _playlist.indexWhere((e) => e.id == song.id);
    if (index != -1 && _audioSource != null && index < _audioSource!.length) {
      await jumpTo(index);
    } else {
      await playPlaylist([song], 0, context: "queue");
    }
  }

  Future<void> play() async {
    try {
      if (player.volume < 0.05) {
        await player.setVolume(1.0);
      }
      if (!player.playing) {
        await player.play();
      }
    } catch (e) {
      debugPrint("Error in play: $e");
    }
  }

  Future<void> pause() async {
    try {
      if (player.playing) {
        await player.pause();
      }
    } catch (e) {
      debugPrint("Error in pause: $e");
    }
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (e) {
      debugPrint("Error in stop: $e");
    }
  }

  Future<void> next() async {
    if (!_playlistLoaded || _playlist.isEmpty) return;

    try {
      if (player.hasNext) {
        await player.seekToNext();
      } else {
        // Volver a reproducir la primera canción si estamos al final
        await jumpTo(0);
      }
    } catch (e) {
      debugPrint("Error in next: $e");
    }
  }

  Future<void> previous() async {
    if (!_playlistLoaded || _playlist.isEmpty) return;

    try {
      if (player.hasPrevious) {
        await player.seekToPrevious();
      } else {
        // Volver a reproducir la última canción si estamos al principio
        await jumpTo(_playlist.length - 1);
      }
    } catch (e) {
      debugPrint("Error in previous: $e");
    }
  }

  Future<void> seek(Duration position) async {
    try {
      if (_currentSong != null) {
        final file = File(_currentSong!.rutaArchivo);
        // Si la ruta cambió o no existe en la fuente original, aseguramos que la fuente de audio coincida
        if (!file.existsSync()) {
          debugPrint("⚠️ Archivo no encontrado en la ruta actual al hacer seek, verificando...");
        }
      }
      await player.seek(position);
    } catch (e) {
      debugPrint("Error in seek: $e");
    }
  }

  Future<void> restart() async {
    try {
      await player.seek(Duration.zero);
    } catch (e) {
      debugPrint("Error in restart: $e");
    }
  }

  Future<void> jumpTo(int index) async {
    if (!_playlistLoaded) return;

    if (index < 0 || index >= _playlist.length) return;

    try {
      if (_audioSource == null || index >= _audioSource!.length) {
        await setPlaylist(_playlist, initialIndex: index, context: _context);
      } else {
        await player.seek(Duration.zero, index: index);
      }
      if (player.volume < 0.05) {
        await player.setVolume(1.0);
      }
      await player.play();
    } catch (e) {
      debugPrint("Error in jumpTo: $e, recargando playlist...");
      try {
        await setPlaylist(_playlist, initialIndex: index, context: _context);
        if (player.volume < 0.05) {
          await player.setVolume(1.0);
        }
        await player.play();
      } catch (inner) {
        debugPrint("Error crítico en jumpTo fallback: $inner");
      }
    }
  }

  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;

    await player.setShuffleModeEnabled(_shuffleEnabled);

    if (_shuffleEnabled) {
      await player.shuffle();
    }

    notifyListeners();
  }

  Future<void> changeLoopMode() async {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;

      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;

      case LoopMode.one:
        _loopMode = LoopMode.off;
        break;
    }

    await player.setLoopMode(_loopMode);

    notifyListeners();
  }

  Future<void> reorderPlaylist(
    int oldIndex,
    int newIndex, {
    required String context,
  }) async {
    if (_context != context) return;
    if (!_playlistLoaded) return;
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    if (oldIndex == newIndex) return;

    _isReordering = true;

    try {
      final currentId = _currentSong?.id;

      // 1. Actualizamos nuestra lista interna PRIMERO
      final song = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, song);

      // 2. Recalcular posición de la canción actual
      if (currentId != null) {
        final newCurrentIndex = _playlist.indexWhere(
          (song) => song.id == currentId,
        );

        if (newCurrentIndex != -1) {
          _currentIndex = newCurrentIndex;
          _currentSong = _playlist[newCurrentIndex];
        }
      }

      // 3. Movemos la fuente en just_audio
      final source = player.audioSource;
      if (source is ConcatenatingAudioSource) {
        await source.move(oldIndex, newIndex);
      }
    } catch (e) {
      debugPrint("Error al reordenar playlist en AudioSource: $e");
    } finally {
      _isReordering = false;
    }

    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(int songId) async {
    final index = _playlist.indexWhere((e) => e.id == songId);
    if (index == -1) return;

    final eraActual = (_currentSong?.id == songId);

    if (eraActual) {
      // 1. Si era la única canción de la playlist
      if (_playlist.length <= 1) {
        _currentSong = null;
        currentSongIdNotifier.value = null;
        _currentIndex = -1;
        _playlist.clear();
        _playlistLoaded = false;
        try {
          await player.stop();
        } catch (_) {}
        notifyListeners();
        return;
      }

      // 2. Si hay más canciones, pasar primero a otra pista antes de remover
      final nextIndex = (index >= _playlist.length - 1) ? index - 1 : index + 1;
      final nextSong = _playlist[nextIndex];

      try {
        await player.seek(Duration.zero, index: nextIndex);
        _currentSong = nextSong;
        currentSongIdNotifier.value = nextSong.id;
        _currentIndex = nextIndex;
      } catch (e) {
        debugPrint("Error seeking before removing active track: $e");
      }
    }

    // 3. Remover de la fuente de audio enjust_audio
    final source = player.audioSource;
    if (source is ConcatenatingAudioSource) {
      try {
        await source.removeAt(index);
      } catch (e) {
        debugPrint("Error in source.removeAt: $e");
      }
    }

    _playlist.removeAt(index);

    // 4. Ajustar el índice si la canción eliminada estaba antes de la actual
    if (!eraActual && _currentIndex > index) {
      _currentIndex--;
    } else if (eraActual) {
      _currentIndex = _playlist.indexWhere((s) => s.id == _currentSong?.id);
    }

    notifyListeners();
  }

  Future<void> addSongToPlaylist(Cancion song) async {
    // Solo si estamos reproduciendo favoritos
    if (_context != "favorites") return;

    // Evitar duplicados
    final existe = _playlist.any((e) => e.id == song.id);

    if (existe) return;

    final source = player.audioSource;

    if (source is ConcatenatingAudioSource) {
      final audioSource = AudioSource.file(
        song.rutaArchivo,
        tag: MediaItem(
          id: song.id.toString(),
          title: song.titulo,
          artist: "VibePlus",
        ),
      );

      // Agrega al final de la cola
      await source.add(audioSource);
    }

    // Actualiza lista interna
    _playlist.add(song);

  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

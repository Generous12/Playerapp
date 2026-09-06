import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playerapp1/services/musicservice.dart';

enum SleepTimerMode {
  time,
  endOfSong,
}

class SleepTimerService extends ChangeNotifier {
  SleepTimerService._internal();
  static final SleepTimerService instance = SleepTimerService._internal();

  Timer? _countdownTimer;
  Timer? _fadeTimer;
  
  SleepTimerMode _mode = SleepTimerMode.time;
  int _initialSeconds = 0;
  int _remainingSeconds = 0;
  bool _isActive = false;
  bool _isFadingOut = false;
  double _originalVolume = 1.0;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;

  SleepTimerMode get mode => _mode;
  int get initialSeconds => _initialSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isActive => _isActive;
  bool get isFadingOut => _isFadingOut;
  bool get isEndOfSongMode => _isActive && _mode == SleepTimerMode.endOfSong;

  double get progress {
    if (!_isActive || _initialSeconds <= 0) return 0.0;
    return (1.0 - (_remainingSeconds / _initialSeconds)).clamp(0.0, 1.0);
  }

  String get formattedRemainingTime {
    if (!_isActive) return "Desactivado";
    if (_mode == SleepTimerMode.endOfSong) return "Al terminar canción";

    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }

  /// Iniciar temporizador por minutos
  void startTimer(int minutes) {
    if (minutes <= 0) return;
    _cancelAllTimers();

    _mode = SleepTimerMode.time;
    _initialSeconds = minutes * 60;
    _remainingSeconds = _initialSeconds;
    _isActive = true;
    _isFadingOut = false;
    final currentVol = MusicService.instance.volume;
    _originalVolume = (currentVol > 0.05) ? currentVol : 1.0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;

        // Iniciar Fade Out Progresivo en los últimos 30 segundos (o últimos 20% si es muy corto)
        final fadeThreshold = _initialSeconds < 45 ? (_initialSeconds * 0.4).round() : 30;
        if (_remainingSeconds <= fadeThreshold && !_isFadingOut) {
          _startFadeOut(fadeThreshold);
        }

        notifyListeners();
      } else {
        _onTimerFinished();
      }
    });

    notifyListeners();
  }

  /// Iniciar temporizador para terminar al final de la canción actual
  void startEndOfSongTimer() {
    _cancelAllTimers();

    _mode = SleepTimerMode.endOfSong;
    _isActive = true;
    _isFadingOut = false;
    final currentVol = MusicService.instance.volume;
    _originalVolume = (currentVol > 0.05) ? currentVol : 1.0;

    final music = MusicService.instance;
    final duration = music.player.duration;
    final position = music.player.position;

    if (duration != null && duration > position) {
      _initialSeconds = (duration - position).inSeconds;
      _remainingSeconds = _initialSeconds;
    } else {
      _initialSeconds = 180;
      _remainingSeconds = 180;
    }

    _positionSubscription = music.player.positionStream.listen((pos) {
      final dur = music.player.duration;
      if (dur != null) {
        final left = (dur - pos).inSeconds;
        _remainingSeconds = left > 0 ? left : 0;

        // Iniciar fade out en los últimos 6 segundos de la canción
        if (left <= 6 && left > 0 && !_isFadingOut) {
          _startFadeOut(left);
        }
        notifyListeners();
      }
    });

    _playerStateSubscription = music.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTimerFinished();
      }
    });

    notifyListeners();
  }

  /// Iniciar desvanecimiento progresivo suave (Fade Out)
  void _startFadeOut(int durationSeconds) {
    if (durationSeconds <= 0) return;
    _isFadingOut = true;
    final music = MusicService.instance;
    final startVol = (music.player.volume > 0.05) ? music.player.volume : _originalVolume;
    final steps = (durationSeconds * 4).clamp(10, 60); // 4 pasos por segundo
    final intervalMs = (durationSeconds * 1000) ~/ steps;
    int currentStep = 0;

    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      currentStep++;
      final factor = 1.0 - (currentStep / steps);
      final newVol = (startVol * factor).clamp(0.0, 1.0);
      music.player.setVolume(newVol);

      if (currentStep >= steps || !_isActive) {
        timer.cancel();
      }
    });
  }

  /// Acción cuando el temporizador finaliza
  Future<void> _onTimerFinished() async {
    _cancelAllTimers();
    _isActive = false;
    _isFadingOut = false;

    final music = MusicService.instance;
    try {
      await music.pause();
      // Restaurar el volumen original del usuario para futuras reproducciones
      final restoreVol = (_originalVolume > 0.05) ? _originalVolume : 1.0;
      await music.player.setVolume(restoreVol);
      await music.setVolume(restoreVol);
    } catch (e) {
      debugPrint("Error al pausar por SleepTimer: $e");
    }

    notifyListeners();
  }

  /// Añadir minutos adicionales al temporizador activo
  void addMinutes(int minutes) {
    if (!_isActive || _mode == SleepTimerMode.endOfSong) {
      startTimer(minutes);
      return;
    }
    _remainingSeconds += minutes * 60;
    _initialSeconds += minutes * 60;
    _isFadingOut = false;
    _fadeTimer?.cancel();
    final restoreVol = (_originalVolume > 0.05) ? _originalVolume : 1.0;
    MusicService.instance.player.setVolume(restoreVol);
    notifyListeners();
  }

  /// Cancelar temporizador
  void cancelTimer() {
    final restoreVol = (_originalVolume > 0.05) ? _originalVolume : 1.0;
    MusicService.instance.player.setVolume(restoreVol);
    MusicService.instance.setVolume(restoreVol);
    _cancelAllTimers();
    _isActive = false;
    _isFadingOut = false;
    _remainingSeconds = 0;
    _initialSeconds = 0;
    notifyListeners();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }
}

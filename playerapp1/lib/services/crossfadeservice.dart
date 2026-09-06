import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:playerapp1/clases/configuracion.dart';
import 'package:playerapp1/services/musicservice.dart';

class CrossfadeService extends ChangeNotifier {
  CrossfadeService._internal() {
    _loadSettings();
  }
  static final CrossfadeService instance = CrossfadeService._internal();

  int _crossfadeSeconds = 0; // 0 = Desactivado, 2, 4, 6, 8, 10, 12
  bool _isTransitioning = false;
  Timer? _fadeTimer;
  StreamSubscription? _posSubscription;

  int get crossfadeSeconds => _crossfadeSeconds;
  bool get isEnabled => _crossfadeSeconds > 0;
  bool get isTransitioning => _isTransitioning;

  static const List<int> availableDurations = [0, 2, 4, 6, 8, 10, 12];

  Future<void> _loadSettings() async {
    try {
      final val = await ConfigService.instance.getValue('crossfade_seconds');
      if (val != null) {
        _crossfadeSeconds = int.tryParse(val) ?? 0;
      }
      _setupPositionListener();
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando configuración de crossfade: $e");
    }
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 15);
    await ConfigService.instance.setValue('crossfade_seconds', _crossfadeSeconds.toString());
    _setupPositionListener();
    notifyListeners();
  }

  void _setupPositionListener() {
    _posSubscription?.cancel();
    _posSubscription = null;

    if (_crossfadeSeconds <= 0) return;

    final music = MusicService.instance;
    _posSubscription = music.player.positionStream.listen((pos) {
      if (!music.isPlaying || _isTransitioning) return;
      final duration = music.player.duration;
      if (duration == null || duration.inSeconds <= _crossfadeSeconds * 2) return;

      final remaining = (duration - pos).inSeconds;
      if (remaining <= _crossfadeSeconds && remaining > 0) {
        _triggerIntelligentEndFadeOut(remaining);
      }
    });
  }

  /// Desvanecimiento suave al final de la pista
  void _triggerIntelligentEndFadeOut(int secondsLeft) {
    if (_isTransitioning) return;
    _isTransitioning = true;

    final music = MusicService.instance;
    final targetVol = music.volume;
    final steps = (secondsLeft * 5).clamp(8, 50);
    final intervalMs = (secondsLeft * 1000) ~/ steps;
    int currentStep = 0;

    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      currentStep++;
      final factor = (1.0 - (currentStep / steps)).clamp(0.05, 1.0);
      music.player.setVolume(targetVol * factor);

      if (currentStep >= steps) {
        timer.cancel();
        _isTransitioning = false;
        // La siguiente pista iniciará con fade-in
      }
    });
  }

  /// Fade-in suave al comenzar una pista nueva
  Future<void> performSmoothFadeIn({int durationMs = 800}) async {
    if (_crossfadeSeconds <= 0) return;
    _fadeTimer?.cancel();
    _isTransitioning = true;

    final music = MusicService.instance;
    final targetVol = music.volume;
    await music.player.setVolume(0.05 * targetVol);

    final steps = 16;
    final interval = durationMs ~/ steps;
    int step = 0;

    _fadeTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      step++;
      final factor = (step / steps).clamp(0.0, 1.0);
      music.player.setVolume(targetVol * factor);

      if (step >= steps) {
        timer.cancel();
        music.player.setVolume(targetVol);
        _isTransitioning = false;
      }
    });
  }

  /// Micro crossfade suave para cambio manual de pista (siguiente/anterior)
  Future<void> performManualTrackTransition(Future<void> Function() action) async {
    if (_crossfadeSeconds <= 0) {
      await action();
      return;
    }

    final music = MusicService.instance;
    final targetVol = music.volume;

    // Rápido fade out de 250ms
    _isTransitioning = true;
    for (int i = 4; i >= 1; i--) {
      await music.player.setVolume(targetVol * (i / 5));
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await action();

    // Rápido fade in de 350ms
    for (int i = 1; i <= 5; i++) {
      await music.player.setVolume(targetVol * (i / 5));
      await Future.delayed(const Duration(milliseconds: 70));
    }
    await music.player.setVolume(targetVol);
    _isTransitioning = false;
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }
}

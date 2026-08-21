import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playerapp1/services/musicservice.dart';

class EqualizerPreset {
  final String name;
  final List<double> bands; // 5 bandas en dB [-12 a +12]
  final double bassBoost; // 0.0 a 1.0
  final double virtualizer; // 0.0 a 1.0

  const EqualizerPreset({
    required this.name,
    required this.bands,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
  });
}

class EqualizerService extends ChangeNotifier {
  EqualizerService._internal() {
    _initNativeEffects();
  }
  static final EqualizerService instance = EqualizerService._internal();

  bool _enabled = true;
  String _currentPreset = "Plano (Flat)";
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _bassBoost = 0.15; // 15%
  double _virtualizer = 0.10; // 10%

  AndroidEqualizerParameters? _cachedParameters;

  static const List<String> bandLabels = [
    "60 Hz",
    "230 Hz",
    "910 Hz",
    "3.6 kHz",
    "14 kHz",
  ];

  static const List<EqualizerPreset> presets = [
    EqualizerPreset(
      name: "Plano (Flat)",
      bands: [0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0.0,
      virtualizer: 0.0,
    ),
    EqualizerPreset(
      name: "Bass Boost",
      bands: [8.0, 5.5, 1.0, 0.0, -1.0],
      bassBoost: 0.75,
      virtualizer: 0.2,
    ),
    EqualizerPreset(
      name: "Rock",
      bands: [5.0, 3.0, -1.0, 3.5, 5.5],
      bassBoost: 0.35,
      virtualizer: 0.25,
    ),
    EqualizerPreset(
      name: "Pop",
      bands: [-1.5, 2.0, 4.5, 2.5, -1.0],
      bassBoost: 0.20,
      virtualizer: 0.15,
    ),
    EqualizerPreset(
      name: "Jazz",
      bands: [3.5, 2.0, -2.0, 3.0, 4.5],
      bassBoost: 0.15,
      virtualizer: 0.30,
    ),
    EqualizerPreset(
      name: "Vocal",
      bands: [-3.0, 0.0, 6.0, 4.0, 1.5],
      bassBoost: 0.0,
      virtualizer: 0.10,
    ),
    EqualizerPreset(
      name: "Clásica",
      bands: [4.5, 3.0, -1.5, 3.5, 5.0],
      bassBoost: 0.10,
      virtualizer: 0.40,
    ),
    EqualizerPreset(
      name: "Electrónica",
      bands: [7.0, 4.5, 0.0, 4.0, 6.0],
      bassBoost: 0.60,
      virtualizer: 0.35,
    ),
    EqualizerPreset(
      name: "Hip-Hop",
      bands: [7.5, 5.5, 0.5, 2.0, 3.5],
      bassBoost: 0.65,
      virtualizer: 0.20,
    ),
    EqualizerPreset(
      name: "Acústico",
      bands: [4.0, 2.5, 1.5, 4.0, 3.5],
      bassBoost: 0.10,
      virtualizer: 0.25,
    ),
  ];

  bool get isEnabled => _enabled;
  String get currentPreset => _currentPreset;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  double get bassBoost => _bassBoost;
  double get virtualizer => _virtualizer;

  Future<void> _initNativeEffects() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final music = MusicService.instance;
      await music.androidEqualizer.setEnabled(_enabled);
      await music.loudnessEnhancer.setEnabled(_enabled);
      _cachedParameters = await music.androidEqualizer.parameters;
      await _applyCurrentSettingsToNative();
    } catch (e) {
      debugPrint("Error inicializando efectos nativos de audio: $e");
    }
  }

  Future<void> _applyCurrentSettingsToNative() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final music = MusicService.instance;
      await music.androidEqualizer.setEnabled(_enabled);
      await music.loudnessEnhancer.setEnabled(_enabled);

      if (!_enabled) {
        // Al deshabilitar, restablecer ganancias nativas a 0
        final params = _cachedParameters ?? await music.androidEqualizer.parameters;
        for (final b in params.bands) {
          await b.setGain(0.0);
        }
        await music.loudnessEnhancer.setTargetGain(0.0);
        return;
      }

      final params = _cachedParameters ?? await music.androidEqualizer.parameters;
      _cachedParameters = params;

      final minDb = params.minDecibels;
      final maxDb = params.maxDecibels;
      final nativeBands = params.bands;

      for (int i = 0; i < _bandGains.length && i < nativeBands.length; i++) {
        double gain = _bandGains[i];

        // Refuerzo de graves (Bass Boost) en bandas bajas
        if (i == 0) {
          gain += _bassBoost * 6.0;
        } else if (i == 1) {
          gain += _bassBoost * 3.5;
        }

        // Claridad y presencia espacial (Virtualizer) en bandas agudas
        if (i == 3) {
          gain += _virtualizer * 3.0;
        } else if (i == 4) {
          gain += _virtualizer * 5.0;
        }

        final targetGain = gain.clamp(minDb, maxDb);
        await nativeBands[i].setGain(targetGain);
      }

      // Refuerzo de ganancia y pegada dinámica
      final loudnessGain = (_bassBoost * 5.0).clamp(0.0, 12.0);
      await music.loudnessEnhancer.setTargetGain(loudnessGain);
    } catch (e) {
      debugPrint("Error aplicando parámetros al ecualizador nativo: $e");
    }
  }

  void toggleEnabled() {
    _enabled = !_enabled;
    _applyCurrentSettingsToNative();
    notifyListeners();
  }

  void setPreset(String name) {
    final preset = presets.firstWhere(
      (p) => p.name == name,
      orElse: () => presets.first,
    );
    _currentPreset = preset.name;
    _bandGains = List.from(preset.bands);
    _bassBoost = preset.bassBoost;
    _virtualizer = preset.virtualizer;
    _applyCurrentSettingsToNative();
    notifyListeners();
  }

  void setBandGain(int index, double gain) {
    if (index < 0 || index >= _bandGains.length) return;
    _bandGains[index] = gain.clamp(-12.0, 12.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    notifyListeners();
  }

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    notifyListeners();
  }

  void setVirtualizer(double value) {
    _virtualizer = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    notifyListeners();
  }

  void reset() {
    setPreset("Plano (Flat)");
  }
}

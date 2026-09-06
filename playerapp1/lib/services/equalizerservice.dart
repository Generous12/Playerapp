import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playerapp1/clases/configuracion.dart';
import 'package:playerapp1/services/musicservice.dart';

class EqualizerPreset {
  final String name;
  final String category;
  final List<double> bands; // 10 bandas HD en dB [-12 a +12]
  final double preamp; // -12.0 a +12.0 dB
  final double bassBoost; // 0.0 a 1.0
  final double virtualizer; // 0.0 a 1.0
  final double crystalEffect; // 0.0 a 1.0
  final double dynamicPunch; // 0.0 a 1.0

  const EqualizerPreset({
    required this.name,
    this.category = "Urbano",
    required this.bands,
    this.preamp = 0.0,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.crystalEffect = 0.0,
    this.dynamicPunch = 0.0,
  });
}

class ReverbPreset {
  final String id;
  final String name;
  final String description;
  final double roomFactor;
  final List<double> bandOffsets;

  const ReverbPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.roomFactor,
    required this.bandOffsets,
  });
}

class EqualizerService extends ChangeNotifier {
  EqualizerService._internal() {
    _loadPersistedSettings();
  }
  static final EqualizerService instance = EqualizerService._internal();

  // ⭐ Por defecto desactivado según requerimiento
  bool _enabled = false;
  String _currentPreset = "Plano (Flat)";
  
  // 10 Bandas HD Audiófilas
  List<double> _bandGains = List.filled(10, 0.0);
  double _preampGain = 0.0; // Preamp en dB [-12.0 a +12.0]
  double _bassBoost = 0.20; // 20%
  double _virtualizer = 0.15; // 15%
  double _crystalEffect = 0.25; // 25% Nitidez Cristalina
  double _dynamicPunch = 0.25; // 25% Pegada Dinámica

  String _currentReverbId = "off";
  double _reverbLevel = 0.50;

  AndroidEqualizerParameters? _cachedParameters;

  static const List<String> bandLabels = [
    "31 Hz",
    "63 Hz",
    "125 Hz",
    "250 Hz",
    "500 Hz",
    "1 kHz",
    "2 kHz",
    "4 kHz",
    "8 kHz",
    "16 kHz",
  ];

  static const List<EqualizerPreset> presets = [
    EqualizerPreset(
      name: "Plano (Flat)",
      category: "Estudio",
      bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 0.0,
      bassBoost: 0.0,
      virtualizer: 0.0,
      crystalEffect: 0.0,
      dynamicPunch: 0.0,
    ),
    EqualizerPreset(
      name: "Dolby Digital",
      category: "Cine & Pro",
      bands: [6.0, 4.5, 2.0, 0.5, 0.0, 1.0, 2.5, 4.5, 6.5, 7.5],
      preamp: 0.5,
      bassBoost: 0.55,
      virtualizer: 0.85,
      crystalEffect: 0.70,
      dynamicPunch: 0.60,
    ),
    EqualizerPreset(
      name: "Dolby Atmos 3D",
      category: "Envolvente",
      bands: [7.0, 5.5, 3.0, 1.5, 0.5, 1.5, 3.5, 6.0, 8.0, 9.0],
      preamp: 0.8,
      bassBoost: 0.65,
      virtualizer: 0.95,
      crystalEffect: 0.80,
      dynamicPunch: 0.65,
    ),
    EqualizerPreset(
      name: "Bass Boost",
      category: "Graves",
      bands: [8.0, 6.5, 4.0, 1.5, 0.0, 0.0, 1.0, 2.5, 4.0, 5.0],
      preamp: 0.0,
      bassBoost: 0.75,
      virtualizer: 0.25,
      crystalEffect: 0.30,
      dynamicPunch: 0.70,
    ),
    EqualizerPreset(
      name: "Urbano / Reggaetón",
      category: "Urbano",
      bands: [7.5, 6.5, 4.0, 1.5, 0.0, 1.0, 2.5, 4.0, 6.0, 7.5],
      preamp: 0.5,
      bassBoost: 0.65,
      virtualizer: 0.35,
      crystalEffect: 0.50,
      dynamicPunch: 0.70,
    ),
    EqualizerPreset(
      name: "Trap / Hip-Hop 808",
      category: "Urbano",
      bands: [9.0, 8.0, 5.5, 2.0, -0.5, 0.5, 2.0, 4.5, 7.0, 8.5],
      preamp: 0.0,
      bassBoost: 0.85,
      virtualizer: 0.30,
      crystalEffect: 0.45,
      dynamicPunch: 0.80,
    ),
    EqualizerPreset(
      name: "Pop",
      category: "Pop",
      bands: [-1.5, 0.0, 2.0, 3.5, 4.5, 4.0, 2.5, 1.5, -0.5, -1.0],
      preamp: 0.0,
      bassBoost: 0.25,
      virtualizer: 0.25,
      crystalEffect: 0.45,
      dynamicPunch: 0.35,
    ),
    EqualizerPreset(
      name: "Rock",
      category: "Rock",
      bands: [6.0, 5.0, 3.0, 1.0, -1.0, -0.5, 2.5, 4.5, 6.0, 7.0],
      preamp: 0.0,
      bassBoost: 0.45,
      virtualizer: 0.30,
      crystalEffect: 0.50,
      dynamicPunch: 0.55,
    ),
    EqualizerPreset(
      name: "Jazz",
      category: "Jazz",
      bands: [4.0, 3.0, 1.5, 0.0, -2.0, 0.0, 2.0, 3.5, 4.5, 5.0],
      preamp: 0.0,
      bassBoost: 0.20,
      virtualizer: 0.35,
      crystalEffect: 0.55,
      dynamicPunch: 0.20,
    ),
    EqualizerPreset(
      name: "Vocal",
      category: "Voces",
      bands: [-3.5, -2.0, 0.0, 2.5, 5.5, 6.5, 5.0, 3.5, 2.0, 1.0],
      preamp: 0.5,
      bassBoost: 0.10,
      virtualizer: 0.20,
      crystalEffect: 0.70,
      dynamicPunch: 0.20,
    ),
    EqualizerPreset(
      name: "Clásica",
      category: "Clásica",
      bands: [4.5, 3.5, 2.0, 0.0, -1.5, 0.0, 2.5, 4.0, 5.0, 5.5],
      preamp: 0.0,
      bassBoost: 0.15,
      virtualizer: 0.45,
      crystalEffect: 0.60,
      dynamicPunch: 0.15,
    ),
    EqualizerPreset(
      name: "Basshead Extreme",
      category: "Graves",
      bands: [10.0, 8.5, 6.5, 3.5, 1.0, 0.0, -1.0, -1.5, -1.0, 0.0],
      preamp: -1.5,
      bassBoost: 0.95,
      virtualizer: 0.20,
      crystalEffect: 0.10,
      dynamicPunch: 0.75,
    ),
    EqualizerPreset(
      name: "Cristal HD",
      category: "Nitidez",
      bands: [-2.0, -1.0, 0.0, 1.0, 2.0, 3.5, 5.0, 7.5, 9.0, 10.5],
      preamp: 0.0,
      bassBoost: 0.15,
      virtualizer: 0.45,
      crystalEffect: 0.95,
      dynamicPunch: 0.25,
    ),
    EqualizerPreset(
      name: "Spatial 3D Urban",
      category: "Envolvente",
      bands: [5.5, 4.5, 2.5, 1.0, 0.0, 1.5, 3.5, 5.5, 7.5, 8.5],
      preamp: 1.0,
      bassBoost: 0.55,
      virtualizer: 0.95,
      crystalEffect: 0.50,
      dynamicPunch: 0.45,
    ),
    EqualizerPreset(
      name: "Electronic / EDM",
      category: "Club",
      bands: [8.0, 7.0, 4.5, 2.0, 0.0, 2.0, 4.0, 6.0, 7.5, 8.5],
      preamp: -0.5,
      bassBoost: 0.70,
      virtualizer: 0.45,
      crystalEffect: 0.65,
      dynamicPunch: 0.65,
    ),
    EqualizerPreset(
      name: "R&B / Smooth",
      category: "Cálido",
      bands: [4.5, 3.5, 2.5, 1.0, -1.0, 0.0, 2.0, 3.5, 5.0, 6.0],
      preamp: 0.0,
      bassBoost: 0.35,
      virtualizer: 0.40,
      crystalEffect: 0.60,
      dynamicPunch: 0.30,
    ),
    EqualizerPreset(
      name: "Acústico",
      category: "Acústico",
      bands: [4.0, 3.0, 2.0, 1.5, 0.0, 1.0, 3.0, 4.5, 4.0, 3.5],
      preamp: 0.0,
      bassBoost: 0.15,
      virtualizer: 0.30,
      crystalEffect: 0.65,
      dynamicPunch: 0.25,
    ),
  ];

  static const List<ReverbPreset> reverbPresets = [
    ReverbPreset(
      id: "off",
      name: "Desactivado",
      description: "Sonido directo y seco",
      roomFactor: 0.0,
      bandOffsets: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    ReverbPreset(
      id: "studio",
      name: "Estudio Pro",
      description: "Acústica tratada y presencia limpia",
      roomFactor: 0.20,
      bandOffsets: [0.5, 0.8, 1.0, 2.0, 2.5, 3.0, 3.5, 4.0, 3.5, 3.0],
    ),
    ReverbPreset(
      id: "club",
      name: "Club Urbano",
      description: "Ambiente con pegada nocturna y eco envolvente",
      roomFactor: 0.50,
      bandOffsets: [2.5, 3.0, 3.5, 2.5, 2.0, 1.5, 2.0, 2.5, 3.0, 2.5],
    ),
    ReverbPreset(
      id: "concert_hall",
      name: "Auditorio / Live",
      description: "Espacio amplio con resonancia natural 3D",
      roomFactor: 0.80,
      bandOffsets: [3.5, 4.0, 4.0, 3.5, 3.0, 3.0, 3.5, 4.0, 4.0, 4.5],
    ),
    ReverbPreset(
      id: "street",
      name: "Street Sound",
      description: "Reflexiones abiertas de escenario al aire libre",
      roomFactor: 0.65,
      bandOffsets: [1.5, 2.0, 3.0, 4.0, 3.5, 3.0, 3.5, 4.5, 5.0, 5.5],
    ),
  ];

  bool get isEnabled => _enabled;
  String get currentPreset => _currentPreset;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  double get preampGain => _preampGain;
  double get bassBoost => _bassBoost;
  double get virtualizer => _virtualizer;
  double get crystalEffect => _crystalEffect;
  double get dynamicPunch => _dynamicPunch;
  String get currentReverbId => _currentReverbId;
  double get reverbLevel => _reverbLevel;

  ReverbPreset get currentReverbPreset => reverbPresets.firstWhere(
        (r) => r.id == _currentReverbId,
        orElse: () => reverbPresets.first,
      );

  /// 💾 Cargar configuración guardada desde SQLite
  Future<void> _loadPersistedSettings() async {
    try {
      final config = ConfigService.instance;

      // Cargar estado de activación (por defecto 'false')
      final enabledVal = await config.getValue('equalizer_enabled');
      _enabled = (enabledVal == 'true');

      final presetVal = await config.getValue('equalizer_preset');
      if (presetVal != null && presetVal.isNotEmpty) {
        _currentPreset = presetVal;
      }

      final bandsVal = await config.getValue('equalizer_bands');
      if (bandsVal != null && bandsVal.isNotEmpty) {
        try {
          final list = (jsonDecode(bandsVal) as List).map((e) => (e as num).toDouble()).toList();
          if (list.length == 10) {
            _bandGains = list;
          }
        } catch (_) {}
      }

      final preampVal = await config.getValue('equalizer_preamp');
      if (preampVal != null) _preampGain = double.tryParse(preampVal) ?? _preampGain;

      final bassVal = await config.getValue('equalizer_bass');
      if (bassVal != null) _bassBoost = double.tryParse(bassVal) ?? _bassBoost;

      final virtVal = await config.getValue('equalizer_virtualizer');
      if (virtVal != null) _virtualizer = double.tryParse(virtVal) ?? _virtualizer;

      final crystalVal = await config.getValue('equalizer_crystal');
      if (crystalVal != null) _crystalEffect = double.tryParse(crystalVal) ?? _crystalEffect;

      final punchVal = await config.getValue('equalizer_punch');
      if (punchVal != null) _dynamicPunch = double.tryParse(punchVal) ?? _dynamicPunch;

      final revIdVal = await config.getValue('equalizer_reverb_id');
      if (revIdVal != null) _currentReverbId = revIdVal;

      final revLvlVal = await config.getValue('equalizer_reverb_level');
      if (revLvlVal != null) _reverbLevel = double.tryParse(revLvlVal) ?? _reverbLevel;

      await _initNativeEffects();
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando configuración persistida de ecualizador: $e");
    }
  }

  /// 💾 Guardar configuración completa en SQLite
  Future<void> _persistSettings() async {
    try {
      final config = ConfigService.instance;
      await config.setValue('equalizer_enabled', _enabled ? 'true' : 'false');
      await config.setValue('equalizer_preset', _currentPreset);
      await config.setValue('equalizer_bands', jsonEncode(_bandGains));
      await config.setValue('equalizer_preamp', _preampGain.toString());
      await config.setValue('equalizer_bass', _bassBoost.toString());
      await config.setValue('equalizer_virtualizer', _virtualizer.toString());
      await config.setValue('equalizer_crystal', _crystalEffect.toString());
      await config.setValue('equalizer_punch', _dynamicPunch.toString());
      await config.setValue('equalizer_reverb_id', _currentReverbId);
      await config.setValue('equalizer_reverb_level', _reverbLevel.toString());
    } catch (e) {
      debugPrint("Error persistiendo configuración de ecualizador: $e");
    }
  }

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
      final nativeCount = nativeBands.length;

      final rev = currentReverbPreset;
      final revScale = (rev.id == "off") ? 0.0 : _reverbLevel;

      final computedHDGains = List<double>.filled(10, 0.0);

      for (int i = 0; i < 10; i++) {
        double gain = _bandGains[i] + _preampGain;

        if (i < rev.bandOffsets.length) {
          gain += rev.bandOffsets[i] * revScale;
        }

        // Sub-graves y Graves 808
        if (i == 0) gain += _bassBoost * 7.5;
        if (i == 1) gain += _bassBoost * 5.5;
        if (i == 2) gain += _bassBoost * 3.5;

        // 3D Spatial Virtualizer
        final effectiveVirtualizer = (_virtualizer + (rev.roomFactor * revScale * 0.35)).clamp(0.0, 1.0);
        if (i >= 6) {
          gain += effectiveVirtualizer * (2.5 + (i - 6) * 1.5);
        }

        // Cristal HD
        if (i == 7) gain += _crystalEffect * 4.5;
        if (i == 8) gain += _crystalEffect * 7.0;
        if (i == 9) gain += _crystalEffect * 9.5;

        computedHDGains[i] = gain;
      }

      if (nativeCount > 0) {
        for (int j = 0; j < nativeCount; j++) {
          final hdIndex = ((j / nativeCount) * 10).floor().clamp(0, 9);
          final targetGain = computedHDGains[hdIndex].clamp(minDb, maxDb);
          await nativeBands[j].setGain(targetGain);
        }
      }

      // LoudnessEnhancer con Limiter Anti-Clipping
      final baseLoudness = (_bassBoost * 4.5 + _dynamicPunch * 6.5 + (rev.roomFactor * revScale * 2.0));
      final loudnessGain = baseLoudness.clamp(0.0, 12.0);
      await music.loudnessEnhancer.setTargetGain(loudnessGain);

    } catch (e) {
      debugPrint("Error aplicando parámetros al ecualizador nativo: $e");
    }
  }

  void toggleEnabled() {
    _enabled = !_enabled;
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setPreset(String name) {
    final preset = presets.firstWhere(
      (p) => p.name == name,
      orElse: () => presets.first,
    );
    _currentPreset = preset.name;
    _bandGains = List.from(preset.bands);
    _preampGain = preset.preamp;
    _bassBoost = preset.bassBoost;
    _virtualizer = preset.virtualizer;
    _crystalEffect = preset.crystalEffect;
    _dynamicPunch = preset.dynamicPunch;
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setPreampGain(double value) {
    _preampGain = value.clamp(-12.0, 12.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setBandGain(int index, double gain) {
    if (index < 0 || index >= _bandGains.length) return;
    _bandGains[index] = gain.clamp(-12.0, 12.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setVirtualizer(double value) {
    _virtualizer = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setCrystalEffect(double value) {
    _crystalEffect = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setDynamicPunch(double value) {
    _dynamicPunch = value.clamp(0.0, 1.0);
    _currentPreset = "Personalizado";
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setReverbPreset(String id) {
    _currentReverbId = id;
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void setReverbLevel(double value) {
    _reverbLevel = value.clamp(0.0, 1.0);
    _applyCurrentSettingsToNative();
    _persistSettings();
    notifyListeners();
  }

  void reset() {
    _currentReverbId = "off";
    _reverbLevel = 0.50;
    setPreset("Plano (Flat)");
  }
}

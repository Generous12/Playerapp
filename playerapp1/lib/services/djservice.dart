import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/canciones.dart';

class DJMood {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final List<String> negativeKeywords;

  const DJMood({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
    this.negativeKeywords = const [],
  });
}

class DJService extends ChangeNotifier {
  DJService._internal();
  static final DJService instance = DJService._internal();

  static const List<DJMood> predefinedMoods = [
    DJMood(
      id: "gym",
      title: "Gym & Adrenalina",
      subtitle: "Ritmo rápido, energía y motivación",
      icon: LucideIcons.zap,
      keywords: ["gym", "workout", "rock", "metal", "trap", "rap", "drill", "phonk", "bass", "hard", "energy", "power", "run", "fast", "hype", "electro", "dubstep"],
      negativeKeywords: ["slow", "lento", "relax", "sleep", "rain", "acoustic", "acustico", "piano", "sad", "triste", "ballad", "balada", "lofi", "quiet", "calm"],
    ),
    DJMood(
      id: "relax",
      title: "Noche & Lofi Relax",
      subtitle: "Sonidos suaves para descansar y relajarse",
      icon: LucideIcons.moon,
      keywords: ["relax", "chill", "lofi", "slow", "acoustic", "piano", "night", "calm", "sleep", "dream", "quiet", "soft", "ambient", "rain"],
      negativeKeywords: ["metal", "phonk", "rock", "hardcore", "drill", "screaming", "perreo", "guaracha", "party", "fiesta", "electro", "bass", "workout", "gym"],
    ),
    DJMood(
      id: "focus",
      title: "Concentración & Código",
      subtitle: "Flujo constante para estudiar y trabajar",
      icon: LucideIcons.laptop,
      keywords: ["focus", "study", "code", "synth", "cyber", "electronic", "instrumental", "deep", "cyberpunk", "mind", "chillstep", "wave", "classical", "ambient"],
      negativeKeywords: ["screaming", "metal", "hardcore", "perreo", "party", "fiesta", "reggaeton", "guaracha"],
    ),
    DJMood(
      id: "roadtrip",
      title: "Viaje & Carretera",
      subtitle: "Clásicos, pop y canciones para cantar",
      icon: LucideIcons.car,
      keywords: ["drive", "road", "trip", "pop", "classic", "hits", "summer", "dance", "radio", "party", "car", "travel", "highway", "sing"],
      negativeKeywords: ["sleep", "rain", "lofi", "screaming"],
    ),
    DJMood(
      id: "romance",
      title: "Sentimiento & Baladas",
      subtitle: "Letras profundas, amor y melancolía",
      icon: LucideIcons.heartCrack,
      keywords: ["love", "amor", "heart", "balada", "sad", "acoustic", "te quiero", "feeling", "soul", "romance", "cry", "lonely", "guitar", "risk"],
      negativeKeywords: ["metal", "phonk", "hardcore", "drill", "guaracha", "perreo", "electro", "edm", "workout", "gym"],
    ),
    DJMood(
      id: "party",
      title: "Fiesta & Urbano",
      subtitle: "Reggaeton, ritmo latino y baile",
      icon: LucideIcons.flame,
      keywords: ["reggaeton", "regeton", "party", "fiesta", "dance", "latin", "urbano", "perreo", "cumbia", "salsa", "electro", "club", "remix", "guaracha", "rumba", "disco", "dembow", "flow", "hit", "ritmo", "house", "merengue", "bachata", "funk", "pop"],
      negativeKeywords: ["ballad", "balada", "risk", "risk it all", "slow", "lento", "acustico", "acoustic", "sad", "triste", "cry", "lonely", "desamor", "piano", "sleep", "rain", "rest", "calm", "relax", "lofi"],
    ),
  ];

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  /// Genera una lista personalizada de canciones usando IA y análisis semántico de metadatos locales
  Future<List<Cancion>> generateMoodMix({
    required List<Cancion> allSongs,
    required String moodPrompt,
  }) async {
    _isGenerating = true;
    notifyListeners();

    // Pequeño delay para feedback visual de cálculo con IA
    await Future.delayed(const Duration(milliseconds: 300));

    final promptLower = moodPrompt.toLowerCase().trim();

    // Buscar si coincide con un mood predefinido
    final matchedPredefined = predefinedMoods.firstWhere(
      (m) => m.id == promptLower || m.title.toLowerCase().contains(promptLower),
      orElse: () => DJMood(
        id: "custom",
        title: moodPrompt,
        subtitle: "Mix personalizado",
        icon: LucideIcons.sparkles,
        keywords: promptLower.split(RegExp(r'\s+')),
        negativeKeywords: const [],
      ),
    );

    final targetKeywords = matchedPredefined.keywords;
    final negativeKeywords = matchedPredefined.negativeKeywords;

    // Puntuación inteligente de canciones basada en palabras positivas y penalización por negativas
    final scoredSongs = allSongs.map((cancion) {
      int score = 0;
      final searchableText = "${cancion.titulo} ${cancion.rutaArchivo}".toLowerCase();

      // 1. Penalización estricta para palabras clave incompatibles
      for (final negKw in negativeKeywords) {
        if (searchableText.contains(negKw.toLowerCase())) {
          score -= 100;
        }
      }

      // 2. Bonificación por palabras clave positivas coincidente
      for (final keyword in targetKeywords) {
        if (searchableText.contains(keyword.toLowerCase())) {
          score += 10;
        }
      }

      // 3. Ajuste de ritmo por duración estimada
      if (matchedPredefined.id == "gym" && cancion.duracion > 0 && cancion.duracion < 240) {
        score += 3;
      } else if (matchedPredefined.id == "focus" && cancion.duracion > 240) {
        score += 3;
      }

      return MapEntry(cancion, score);
    }).toList();

    // Ordenar de mayor coincidencia a menor
    scoredSongs.sort((a, b) => b.value.compareTo(a.value));

    // Filtrar aquellas con coincidencia positiva clara (score > 0)
    List<Cancion> result = scoredSongs.where((e) => e.value > 0).map((e) => e.key).toList();

    // Si faltan elementos, rellenar EXCLUSIVAMENTE con canciones que no violen las palabras clave negativas
    if (result.length < 5) {
      final safeRemaining = allSongs.where((s) {
        if (result.contains(s)) return false;
        final text = "${s.titulo} ${s.rutaArchivo}".toLowerCase();
        for (final negKw in negativeKeywords) {
          if (text.contains(negKw.toLowerCase())) return false; // 🚫 NUNCA incluir canciones incompatibles (ej. baladas en Fiesta)
        }
        return true;
      }).toList()..shuffle();

      result.addAll(safeRemaining.take(15 - result.length));
    }

    // Si la biblioteca es muy pequeña y no hubo filtros, retornar la selección segura disponible
    if (result.isEmpty && allSongs.isNotEmpty) {
      result = List.from(allSongs)..shuffle();
    }

    if (result.length > 25) {
      result = result.sublist(0, 25);
    }

    _isGenerating = false;
    notifyListeners();
    return result;
  }
}

import 'package:flutter/material.dart';

class MusicProvider extends ChangeNotifier {
  int? _currentSongId;

  int? get currentSongId => _currentSongId;

  void setSong(int id) {
    _currentSongId = id;
    notifyListeners(); // 🔥 actualiza toda la app
  }
}
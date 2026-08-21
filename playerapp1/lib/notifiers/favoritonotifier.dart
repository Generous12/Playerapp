import 'package:flutter/material.dart';

class FavoritosNotifier extends ChangeNotifier {
  static final FavoritosNotifier instance = FavoritosNotifier._();

  FavoritosNotifier._();

  void actualizar() {
    notifyListeners();
  }
}
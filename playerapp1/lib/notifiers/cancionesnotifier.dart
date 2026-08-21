
import 'package:flutter/material.dart';

class CancionesNotifier extends ChangeNotifier {
  static final CancionesNotifier instance = CancionesNotifier._();

  CancionesNotifier._();

  void actualizar() {
    notifyListeners();
  }
}


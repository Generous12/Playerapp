import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servicio en tiempo real para monitoreo de conexión a Internet
class ConnectivityService {
  ConnectivityService._internal() {
    _init();
  }

  static final ConnectivityService instance = ConnectivityService._internal();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  Timer? _pollTimer;
  DateTime _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isChecking = false;

  void _init() {
    // Verificación inicial rápida
    checkConnection(force: true);

    // Polling ligero periódico cada 8 segundos
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      checkConnection();
    });
  }

  /// Verifica el estado real de conexión a internet
  Future<bool> checkConnection({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastCheckTime).inSeconds < 4) {
      return isOnlineNotifier.value;
    }

    if (_isChecking) return isOnlineNotifier.value;
    _isChecking = true;

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 2500));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _lastCheckTime = DateTime.now();

      if (isOnlineNotifier.value != online) {
        isOnlineNotifier.value = online;
      }
      return online;
    } catch (_) {
      _lastCheckTime = DateTime.now();
      if (isOnlineNotifier.value != false) {
        isOnlineNotifier.value = false;
      }
      return false;
    } finally {
      _isChecking = false;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    isOnlineNotifier.dispose();
  }
}

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> solicitarPermisosAudio() async {
    if (!Platform.isAndroid) return true;

    // Solicitar permiso de notificaciones para reproducción en segundo plano (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    if (audioStatus.isPermanentlyDenied ||
        storageStatus.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }
}
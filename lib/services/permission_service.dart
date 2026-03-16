import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestStoragePermission() async {
    // Android 13+ uses READ_MEDIA_IMAGES instead of READ_EXTERNAL_STORAGE
    final status = await Permission.photos.request();
    if (status.isGranted) return true;

    // Fallback for Android < 13
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> checkStoragePermission() async {
    final photos = await Permission.photos.status;
    if (photos.isGranted) return true;
    final storage = await Permission.storage.status;
    return storage.isGranted;
  }

  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }
}

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static bool _isRequestingStorage = false;
  static bool _isRequestingCamera = false;

  static Future<bool> requestStoragePermission() async {
    // Prevent double calls
    if (_isRequestingStorage) {
      // Wait for existing request to finish
      await Future.delayed(const Duration(milliseconds: 500));
      return checkStoragePermission();
    }

    _isRequestingStorage = true;
    try {
      if (Platform.isAndroid) {
        final sdkInt = await _getAndroidSdkInt();

        if (sdkInt >= 33) {
          final photos = await Permission.photos.request();
          return photos.isGranted;
        } else if (sdkInt >= 30) {
          final manage =
              await Permission.manageExternalStorage.request();
          if (manage.isGranted) return true;
          final storage = await Permission.storage.request();
          return storage.isGranted;
        } else {
          final storage = await Permission.storage.request();
          return storage.isGranted;
        }
      }
      return true;
    } catch (e) {
      // If permission request fails, check if already granted
      return checkStoragePermission();
    } finally {
      _isRequestingStorage = false;
    }
  }

  static Future<bool> checkStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt >= 33) {
          return await Permission.photos.isGranted;
        } else {
          return await Permission.storage.isGranted ||
              await Permission.manageExternalStorage.isGranted;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestCameraPermission() async {
    if (_isRequestingCamera) {
      await Future.delayed(const Duration(milliseconds: 500));
      return Permission.camera.isGranted;
    }

    _isRequestingCamera = true;
    try {
      final camera = await Permission.camera.request();
      return camera.isGranted;
    } catch (e) {
      return Permission.camera.isGranted;
    } finally {
      _isRequestingCamera = false;
    }
  }

  static Future<int> _getAndroidSdkInt() async {
    try {
      final result =
          await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
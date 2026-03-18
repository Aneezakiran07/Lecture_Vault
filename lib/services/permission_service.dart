import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static bool _isRequestingStorage = false;
  static bool _isRequestingCamera = false;

  // Correct way to get SDK version on Android
  static Future<int> _getAndroidSdkInt() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> requestStoragePermission() async {
    if (_isRequestingStorage) {
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
          final manage = await Permission.manageExternalStorage.request();
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
}
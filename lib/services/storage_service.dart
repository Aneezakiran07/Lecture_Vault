import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'search_service.dart';

class StorageService {
  static const _basePathKey = 'base_storage_path';
  static const _subjectsKey = 'subjects';
  static const _setupDoneKey = 'setup_done';

  // setup flag
  static Future<bool> isSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupDoneKey) ?? false;
  }

  static Future<void> markSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, true);
  }

  // base path
  static Future<void> saveBasePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_basePathKey, path);
  }

  static Future<String?> getBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_basePathKey);
  }

  // subjects
  static Future<void> saveSubjects(List<String> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_subjectsKey, subjects);
  }

  static Future<List<String>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subjectsKey) ?? [];
  }

  // create a single subject folder on device
  static Future<bool> createSubjectFolder(String basePath, String subject) async {
    try {
      final dir = Directory(p.join(basePath, subject));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // create root folder and all subject folders
  static Future<bool> createAllSubjectFolders(
      String basePath, List<String> subjects) async {
    try {
      final rootDir = Directory(basePath);
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
      for (final subject in subjects) {
        await createSubjectFolder(basePath, subject);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // copy photo into subject folder, returns destination path or null on failure
  static Future<String?> savePhotoToSubject({
    required String sourcePath,
    required String basePath,
    required String subject,
  }) async {
    try {
      final subjectDir = Directory(p.join(basePath, subject));
      if (!await subjectDir.exists()) {
        await subjectDir.create(recursive: true);
      }
      final fileName = 'LV_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = p.join(subjectDir.path, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      return null;
    }
  }

  // get all photos inside a subject folder sorted newest first
  static Future<List<File>> getPhotosInSubject({
    required String basePath,
    required String subject,
  }) async {
    try {
      final subjectDir = Directory(p.join(basePath, subject));
      if (!await subjectDir.exists()) return [];
      final files = await subjectDir.list().toList();
      return files
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.jpg') ||
              f.path.endsWith('.jpeg') ||
              f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) {
      return [];
    }
  }

  // delete a single photo file from device
static Future<bool> deletePhoto(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
    await SearchService.removePhoto(path);
    return true;
  } catch (e) {
    return false;
  }
}
  // move photo to a different subject folder
  static Future<String?> movePhotoToSubject({
    required String sourcePath,
    required String basePath,
    required String newSubject,
  }) async {
    final newPath = await savePhotoToSubject(
      sourcePath: sourcePath,
      basePath: basePath,
      subject: newSubject,
    );
    if (newPath != null) await deletePhoto(sourcePath);
    return newPath;
  }

  // get photo count for each subject
  static Future<Map<String, int>> getSubjectPhotoCounts(
      String basePath, List<String> subjects) async {
    final counts = <String, int>{};
    for (final subject in subjects) {
      final photos =
          await getPhotosInSubject(basePath: basePath, subject: subject);
      counts[subject] = photos.length;
    }
    return counts;
  }

  // get total folder size as formatted string
  static Future<String> getFolderSize(String basePath, String subject) async {
    try {
      final photos =
          await getPhotosInSubject(basePath: basePath, subject: subject);
      int totalBytes = 0;
      for (final file in photos) {
        totalBytes += await file.length();
      }
      if (totalBytes < 1024 * 1024) {
        return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '0 KB';
    }
  }

  // clear all saved prefs and reset app state
static Future<void> clearAll() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await SearchService.clearIndex();
}
  static const _autoClassifyKey = 'auto_classify';
static const _showConfidenceKey = 'show_confidence';
static const _saveOriginalKey = 'save_original';

static Future<void> saveClassificationSettings({
  required bool autoClassify,
  required bool showConfidence,
  required bool saveOriginal,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_autoClassifyKey, autoClassify);
  await prefs.setBool(_showConfidenceKey, showConfidence);
  await prefs.setBool(_saveOriginalKey, saveOriginal);
}

static Future<Map<String, bool>> getClassificationSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'autoClassify': prefs.getBool(_autoClassifyKey) ?? true,
    'showConfidence': prefs.getBool(_showConfidenceKey) ?? true,
    'saveOriginal': prefs.getBool(_saveOriginalKey) ?? false,
  };
}
}   
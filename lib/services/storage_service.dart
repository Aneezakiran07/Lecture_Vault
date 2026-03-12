import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;



class StorageService {
  static const _basePathKey = 'base_storage_path';
  static const _subjectsKey = 'subjects';

  // ── BASE PATH ──────────────────────────────────────────────────

  static Future<void> saveBasePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_basePathKey, path);
  }

  static Future<String?> getBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_basePathKey);
  }

  // ── SUBJECTS ───────────────────────────────────────────────────

  static Future<void> saveSubjects(List<String> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_subjectsKey, subjects);
  }

  static Future<List<String>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subjectsKey) ?? [];
  }

  // ── FOLDER CREATION ────────────────────────────────────────────

  static Future<bool> createSubjectFolder(
      String basePath, String subject) async {
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

  static Future<bool> createAllSubjectFolders(
      String basePath, List<String> subjects) async {
    try {
      // Create root LectureVault folder
      final rootDir = Directory(basePath);
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
      // Create each subject folder
      for (final subject in subjects) {
        await createSubjectFolder(basePath, subject);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── PHOTO SAVING ───────────────────────────────────────────────

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

      final fileName =
          'LV_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = p.join(subjectDir.path, fileName);

      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      return null;
    }
  }

  // ── FETCH PHOTOS IN FOLDER ─────────────────────────────────────

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
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (e) {
      return [];
    }
  }

  // ── DELETE PHOTO ───────────────────────────────────────────────

  static Future<bool> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── MOVE PHOTO ─────────────────────────────────────────────────

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

  // ── FOLDER STATS ───────────────────────────────────────────────

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

  static Future<String> getFolderSize(
      String basePath, String subject) async {
    try {
      final photos = await getPhotosInSubject(
          basePath: basePath, subject: subject);
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
}
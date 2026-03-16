import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyBasePath = 'base_path';
  static const _keySubjects = 'subjects';
  static const _keySetupDone = 'setup_done';

  // setup flag
  static Future<bool> isSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySetupDone) ?? false;
  }

  static Future<void> markSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupDone, true);
  }

  // base path
  static Future<void> saveBasePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBasePath, path);
  }

  static Future<String?> getBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyBasePath);
    return (path == null || path.isEmpty) ? null : path;
  }

  // subjects
  static Future<void> saveSubjects(List<String> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySubjects, subjects);
  }

  static Future<List<String>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySubjects) ?? [];
  }

  // create subject folder on device
  static Future<void> createSubjectFolder(String basePath, String subject) async {
    final dir = Directory(p.join(basePath, subject));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // copy photo into subject folder, returns destination path or null
  static Future<String?> savePhotoToSubject({
    required String sourcePath,
    required String basePath,
    required String subject,
  }) async {
    try {
      await createSubjectFolder(basePath, subject);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final destPath = p.join(basePath, subject, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      return null;
    }
  }

  // get all photos inside a subject folder
  static Future<List<File>> getPhotosInSubject({
    required String basePath,
    required String subject,
  }) async {
    try {
      final dir = Directory(p.join(basePath, subject));
      if (!await dir.exists()) return [];
      final files = await dir
          .list()
          .where((e) =>
              e is File &&
              (e.path.endsWith('.jpg') ||
                  e.path.endsWith('.jpeg') ||
                  e.path.endsWith('.png')))
          .map((e) => File(e.path))
          .toList();
      return files;
    } catch (e) {
      return [];
    }
  }

  // delete a single photo file from device
  static Future<bool> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // reset all prefs
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}


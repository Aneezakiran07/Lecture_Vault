import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'ocr_result.dart';

class CustomRulesClassifier {
  static const _rulesDir = 'custom_subject_rules';

  /// Classify using saved custom rules
  static Future<({String subject, double confidence})?> classify(
    OcrResult ocrResult,
    String subject,
  ) async {
    final rules = await _loadRules(subject);
    if (rules == null || rules.isEmpty) return null;

    final combinedText = ocrResult.classifierInput.toLowerCase();
    final keywords = ocrResult.keywords
        .map((k) => k.toLowerCase())
        .toSet();

    int matches = 0;
    for (final rule in rules) {
      if (combinedText.contains(rule.toLowerCase()) ||
          keywords.contains(rule.toLowerCase())) {
        matches++;
      }
    }

    if (rules.isEmpty) return null;

    final confidence = (matches / rules.length).clamp(0.0, 1.0);

    if (confidence < 0.02) return null;

    return (subject: subject, confidence: confidence);
  }

  /// Save rules for a subject (called after Gemini generates them)
  static Future<void> saveRules(
      String subject, List<String> rules) async {
    try {
      final file = await _getRulesFile(subject);
      await file.writeAsString(jsonEncode(rules));
    } catch (e) {
      // ignore save failure
    }
  }

  /// Check if rules exist for subject
  static Future<bool> hasRules(String subject) async {
    try {
      final file = await _getRulesFile(subject);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Load rules for a subject
  static Future<List<String>?> _loadRules(String subject) async {
    try {
      final file = await _getRulesFile(subject);
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list.cast<String>();
    } catch (_) {
      return null;
    }
  }

  static Future<File> _getRulesFile(String subject) async {
    final dir = await getApplicationDocumentsDirectory();
    final rulesDir =
        Directory('${dir.path}/$_rulesDir');
    if (!rulesDir.existsSync()) {
      rulesDir.createSync(recursive: true);
    }
    final safeName =
        subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return File('${rulesDir.path}/${safeName}_rules.json');
  }

  /// Delete rules for a subject (when subject is deleted)
  static Future<void> deleteRules(String subject) async {
    try {
      final file = await _getRulesFile(subject);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// List all subjects that have custom rules
  static Future<List<String>> subjectsWithRules() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final rulesDir = Directory('${dir.path}/$_rulesDir');
      if (!rulesDir.existsSync()) return [];
      return rulesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path
              .split('/')
              .last
              .replaceAll('_rules.json', '')
              .replaceAll('_', ' '))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_service.dart';

class StudyMaterial {
  final List<String> bullets;
  final List<String> details;
  final List<({String question, String answer})> flashcards;
  final DateTime generatedAt;

  const StudyMaterial({
    required this.bullets,
    required this.details,
    required this.flashcards,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'bullets': bullets,
        'details': details,
        'flashcards': flashcards
            .map((f) => {'q': f.question, 'a': f.answer})
            .toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  static StudyMaterial fromJson(Map<String, dynamic> json) => StudyMaterial(
        bullets: List<String>.from(json['bullets'] ?? []),
        details: List<String>.from(json['details'] ?? []),
        flashcards: (json['flashcards'] as List<dynamic>? ?? [])
            .map((f) => (
                  question: f['q'] as String,
                  answer: f['a'] as String,
                ))
            .toList(),
        generatedAt: DateTime.parse(
            json['generatedAt'] as String? ??
                DateTime.now().toIso8601String()),
      );
}

class SummaryService {
  static const _cachePrefix = 'study_cache_';
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static GenerativeModel? _model;
  static GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
      ),
    );
    return _model!;
  }

  // generates study material for an entire subject folder
  // cache key includes photo count so adding new photos auto-invalidates it
  static Future<StudyMaterial?> getForFolder({
    required String subject,
    required int photoCount,
    void Function(String)? onStatus,
  }) async {
    final cacheKey = '$_cachePrefix${subject}_$photoCount';

    final cached = await _loadCache(cacheKey);
    if (cached != null) {
      onStatus?.call('Loaded from cache');
      return cached;
    }

    onStatus?.call('Reading your notes...');
    final allText = await _collectTextForSubject(subject);
    if (allText.trim().isEmpty) return null;

    onStatus?.call('Generating study material...');
    final result = await _callGemini(allText, subject);
    if (result != null) await _saveCache(cacheKey, result);
    return result;
  }

  // generates study material for a specific selected set of photos
  // not cached since the selection is arbitrary each time
  static Future<StudyMaterial?> getForSelection({
    required List<String> photoPaths,
    required String subject,
    void Function(String)? onStatus,
  }) async {
    onStatus?.call('Reading selected notes...');
    final buffer = StringBuffer();
    for (final path in photoPaths) {
      final text = await SearchService.getTextForPhoto(path);
      if (text != null && text.trim().isNotEmpty) {
        buffer.writeln(text);
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) return null;

    onStatus?.call('Generating study material...');
    return await _callGemini(text, subject);
  }

  // clears all cached summaries for a subject
  // call this when photos are added or deleted from the folder
  static Future<void> invalidateCache(String subject) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('$_cachePrefix${subject}_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<String> _collectTextForSubject(String subject) async {
    final index = await SearchService.getRawIndex();
    final buffer = StringBuffer();
    for (final entry in index.entries) {
      if (entry.value['subject'] == subject) {
        final text = entry.value['text'] as String? ?? '';
        if (text.isNotEmpty) buffer.writeln(text);
      }
    }
    return buffer.toString();
  }

  static Future<StudyMaterial?> _callGemini(
      String text, String subject) async {
    final trimmed =
        text.length > 6000 ? text.substring(0, 6000) : text;

    final prompt =
        '''You are a study assistant. The following is OCR text from a student\'s lecture notes for "$subject".

Return ONLY this JSON with no extra text:
{
  "bullets": ["key concept 1", "key concept 2"],
  "details": ["detailed explanation 1", "detailed explanation 2"],
  "flashcards": [{"q": "question", "a": "answer"}]
}

Rules:
- bullets: 5 to 8 short key concepts, one line each
- details: 4 to 6 paragraphs each explaining a concept in depth
- flashcards: 5 to 10 question and answer pairs covering testable facts
- write for a student reviewing before an exam
- return only raw JSON, no markdown, no backticks

NOTES:
"""
$trimmed
"""''';

    try {
      final response =
          await _gemini.generateContent([Content.text(prompt)]);
      return _parse(response.text ?? '');
    } catch (_) {
      return null;
    }
  }

  static StudyMaterial? _parse(String raw) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
          .replaceAll('```', '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end <= start) return null;

      final json = jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;

      return StudyMaterial(
        bullets: List<String>.from(json['bullets'] ?? []),
        details: List<String>.from(json['details'] ?? []),
        flashcards: (json['flashcards'] as List<dynamic>? ?? [])
            .map((f) => (
                  question: f['q'] as String? ?? '',
                  answer: f['a'] as String? ?? '',
                ))
            .where((f) => f.question.isNotEmpty)
            .toList(),
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<StudyMaterial?> _loadCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return StudyMaterial.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(
      String key, StudyMaterial material) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(material.toJson()));
    } catch (_) {}
  }
}
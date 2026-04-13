import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// each search result carries the photo path, its subject folder, and the matched snippet
class SearchResult {
  final String photoPath;
  final String subject;
  final String snippet;

  const SearchResult({
    required this.photoPath,
    required this.subject,
    required this.snippet,
  });
}

class SearchService {
  // all ocr text is stored under this single key as a json map
  static const _ocrIndexKey = 'ocr_index';

  // saves the ocr text for one photo right after it is classified and copied
  static Future<void> indexPhoto({
    required String photoPath,
    required String subject,
    required String ocrText,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ocrIndexKey);
    final map = raw != null
        ? Map<String, dynamic>.from(jsonDecode(raw))
        : <String, dynamic>{};

    // store subject and ocr text together so search results know which folder to open
    map[photoPath] = {
      'subject': subject,
      'text': ocrText.toLowerCase(),
    };

    await prefs.setString(_ocrIndexKey, jsonEncode(map));
  }

  // removes the ocr entry when a photo is deleted so the index stays clean
  static Future<void> removePhoto(String photoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ocrIndexKey);
    if (raw == null) return;

    final map = Map<String, dynamic>.from(jsonDecode(raw));
    map.remove(photoPath);

    await prefs.setString(_ocrIndexKey, jsonEncode(map));
  }

  // removes all entries that belong to a subject folder
  // call this if the user deletes an entire subject
  static Future<void> removeSubject(String subject) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ocrIndexKey);
    if (raw == null) return;

    final map = Map<String, dynamic>.from(jsonDecode(raw));
    map.removeWhere((_, v) {
      final entry = v as Map<String, dynamic>;
      return entry['subject'] == subject;
    });

    await prefs.setString(_ocrIndexKey, jsonEncode(map));
  }

  // searches all saved ocr text and returns matching photos sorted by subject name
  static Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ocrIndexKey);
    if (raw == null) return [];

    final map = Map<String, dynamic>.from(jsonDecode(raw));
    final queryLower = query.toLowerCase().trim();
    final results = <SearchResult>[];

    for (final entry in map.entries) {
      final photoPath = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final subject = data['subject'] as String;
      final text = data['text'] as String;

      final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (queryWords.every((word) => text.contains(word))) { 
        results.add(SearchResult(
          photoPath: photoPath,
          subject: subject,
          snippet: _extractSnippet(text, queryLower),
        ));
      }
    }

    // sort alphabetically by subject so results feel organized
    results.sort((a, b) => a.subject.compareTo(b.subject));
    return results;
  }

  // returns total number of photos that have been indexed
  static Future<int> indexedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ocrIndexKey);
    if (raw == null) return 0;
    final map = Map<String, dynamic>.from(jsonDecode(raw));
    return map.length;
  }

  // wipes the entire index, used when the user resets the app
  static Future<void> clearIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ocrIndexKey);
  }

  // pulls a short window of text around where the query word appears
  static String _extractSnippet(String text, String query) {
    final index = text.indexOf(query);
    if (index == -1) return text.substring(0, text.length.clamp(0, 80));

    // take 40 characters before and after the match for context
    final start = (index - 40).clamp(0, text.length);
    final end = (index + query.length + 40).clamp(0, text.length);
    final snippet = text.substring(start, end).trim();

    // add ellipsis if we cut the text on either side
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix$snippet$suffix';
  }
}
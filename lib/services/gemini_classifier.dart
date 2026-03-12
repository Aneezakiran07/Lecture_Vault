import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ocr_result.dart';


class GeminiClassifier {
  static const _apiKey = 'AIzaSyDB9kalWfKJ8gQo_UnFtFqxvH8ucrpr3o4';

  static GenerativeModel? _model;
  static GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model:  'gemini-2.5-flash',
      
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 1000,
      ),
    );
    return _model!;
  }

  // ── SINGLE CLASSIFICATION ────────────────────────────────────────

  static Future<({String subject, double confidence, String reasoning})>
      classify(
    OcrResult ocrResult,
    List<String> subjects,
  ) async {
    print('==== GEMINI SINGLE START ====');
    print('Subjects: $subjects');
    print('Raw text length: ${ocrResult.rawText.length}');
    print('Keywords: ${ocrResult.keywords.take(10).toList()}');

    final empty = (
      subject: 'Unclassified',
      confidence: 0.0,
      reasoning: 'No text',
    );

    if (subjects.isEmpty) {
      print('❌ No subjects provided');
      return empty;
    }

    final text = _buildText(ocrResult);
    print('Built text length: ${text.length}');
    print('Built text preview: ${text.substring(0, text.length.clamp(0, 150))}');

    if (text.trim().length < 5) {
      print('❌ Text too short: "${text.trim()}"');
      return empty;
    }

    try {
      print('📡 Calling Gemini API (single)...');
      final response = await _gemini.generateContent([
        Content.text(_buildSinglePrompt(text, subjects)),
      ]);

      final raw = response.text ?? '';
      print('📥 Gemini single raw response: $raw');
      final result = _parseSingle(raw, subjects);
      print('✅ Parsed: ${result.subject} (${result.confidence})');
      return result;
    } catch (e, stack) {
      print('❌ Gemini single ERROR: $e');
      print('❌ STACK: $stack');
      return empty;
    }
  }

  // ── BATCH CLASSIFICATION ─────────────────────────────────────────

  static Future<List<({String subject, double confidence})>>
      classifyBatch(
    List<OcrResult> batch,
    List<String> subjects,
  ) async {
    print('==== GEMINI BATCH START ====');
    print('Batch size: ${batch.length}');
    print('Subjects: $subjects');

    final fallback = List.generate(
      batch.length,
      (_) => (subject: 'Unclassified', confidence: 0.0),
    );

    if (batch.isEmpty || subjects.isEmpty) {
      print('❌ Empty batch or subjects');
      return fallback;
    }

    // Log each item in batch
    for (int i = 0; i < batch.length; i++) {
      final text = _buildText(batch[i]);
      print('  Item $i: rawLen=${batch[i].rawText.length} '
          'keywords=${batch[i].keywords.take(5).toList()} '
          'textLen=${text.length}');
    }

    try {
      final prompt = _buildBatchPrompt(batch, subjects);
      print('📋 Prompt length: ${prompt.length}');
      print('📋 Prompt preview:\n${prompt.substring(0, prompt.length.clamp(0, 300))}');

      print('📡 Calling Gemini API (batch)...');
      final response = await _gemini.generateContent([
        Content.text(prompt),
      ]);

      final raw = response.text ?? '';
      print('📥 GEMINI BATCH RAW RESPONSE:');
      print(raw);
      print('📥 Response length: ${raw.length}');

      final results = _parseBatch(raw, batch.length, subjects, fallback);
      print('✅ Batch results: $results');
      return results;
    } catch (e, stack) {
      print('❌ GEMINI BATCH ERROR: $e');
      print('❌ STACK: $stack');
      return fallback;
    }
  }

  // ── PROMPTS ──────────────────────────────────────────────────────

 static String _buildText(OcrResult ocr) {
  return '''
RAW_OCR_TEXT:
${ocr.rawText}

KEYWORDS:
${ocr.keywords.join(', ')}

PATTERNS:
${ocr.patterns.join(', ')}
''';
}
static String _buildSinglePrompt(String text, List<String> subjects) {
  return '''
You are an academic subject classifier for OCR lecture notes.

The text may contain spelling mistakes, broken words, or shorthand.

NOTE TEXT:
"""
${text.substring(0, text.length.clamp(0, 1000))}
"""

AVAILABLE SUBJECTS:
${subjects.join(', ')}

Instructions:
- Infer the subject using technical concepts, not just exact keywords.
- Correct OCR mistakes mentally.
- Choose the most likely subject from the list.
- Only return "Unclassified" if the text has zero academic meaning.

Examples of concept mapping:
agent, heuristic, search -> Artificial Intelligence
packet, routing, subnet -> Computer Networks
CPU, clock cycle, pipeline -> Computer Architecture
matrix, vector, integral -> Mathematics

Return STRICT JSON ONLY:

{
  "subject": "EXACT_NAME_FROM_LIST",
  "confidence": 0.0,
  "reasoning": "Short explanation"
}
''';
}
  static String _buildBatchPrompt(List<OcrResult> batch, List<String> subjects) {
  final items = batch.asMap().entries.map((e) {
    final text = _buildText(e.value);
    final preview = text.substring(0, text.length.clamp(0, 500));

    return '''
NOTE ${e.key + 1}:
$preview
''';
  }).join('\n');

  return '''
You are an expert academic subject classifier.

The following texts come from OCR lecture notes. The text may contain spelling mistakes, missing letters, or shorthand.

AVAILABLE SUBJECTS:
${subjects.join(', ')}

Use semantic reasoning instead of exact keyword matching.

Examples of concept mapping:
- agent, heuristic, search → Artificial Intelligence
- packet, routing, subnet → Computer Networks
- CPU, clock cycle, register, pipeline → Computer Architecture
- matrix, vector, derivative, integral → Mathematics

NOTES TO CLASSIFY:
$items

Return ONLY a JSON array. No explanation.

Example format:
[
 {"id":1,"subject":"Algorithms","confidence":0.90},
 {"id":2,"subject":"Computer Networks","confidence":0.87}
]

Rules:
- id corresponds to NOTE number
- subject MUST match exactly one of: ${subjects.join(', ')}
- confidence must be between 0.0 and 1.0
- If completely unclear use "Unclassified"
''';
}

  // ── PARSERS ──────────────────────────────────────────────────────

  static ({String subject, double confidence, String reasoning})
      _parseSingle(String raw, List<String> subjects) {
    print('🔍 Parsing single response...');
    try {
      final cleaned = _cleanJson(raw);
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end <= start) {
        print('⚠️ No JSON object found, scanning...');
        return _scanForSubject(raw, subjects);
      }

      final jsonStr = cleaned.substring(start, end + 1);
      print('🔍 JSON string: $jsonStr');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final subject = json['subject']?.toString().trim() ?? '';
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      final reasoning = json['reasoning']?.toString() ?? '';

      print('🔍 Parsed subject: "$subject" confidence: $confidence');
      final matched = _matchSubject(subject, subjects);
      print('🔍 Matched to: "$matched"');

      if (matched != null) {
        return (
          subject: matched,
          confidence: confidence.clamp(0.0, 1.0),
          reasoning: reasoning,
        );
      }
      return _scanForSubject(raw, subjects);
    } catch (e) {
      print('❌ parseSingle error: $e');
      return _scanForSubject(raw, subjects);
    }
  }

  static List<({String subject, double confidence})> _parseBatch(
    String raw,
    int expectedCount,
    List<String> subjects,
    List<({String subject, double confidence})> fallback,
  ) {
    print('🔍 Parsing batch response, expected: $expectedCount');
    final results = List<({String subject, double confidence})>.from(fallback);

    try {
      final cleaned = _cleanJson(raw);
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');

      print('🔍 JSON array found: ${start != -1 && end > start}');
      if (start == -1 || end <= start) {
        print('⚠️ No JSON array found in: $cleaned');
        return results;
      }

      final jsonStr = cleaned.substring(start, end + 1);
      print('🔍 JSON array: $jsonStr');
      final jsonArray = jsonDecode(jsonStr) as List;
      print('🔍 Parsed ${jsonArray.length} items');

      for (final item in jsonArray) {
        try {
          final map = item as Map<String, dynamic>;
          final id = (map['id'] as num?)?.toInt() ?? 0;
          final idx = id - 1;
          final subject = map['subject']?.toString().trim() ?? '';
          final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.0;

          print('  Item id=$id subject="$subject" confidence=$confidence');
          final matched = _matchSubject(subject, subjects);
          print('  Matched to: "$matched"');

          if (matched != null && idx >= 0 && idx < expectedCount) {
            results[idx] = (
              subject: matched,
              confidence: confidence.clamp(0.0, 1.0),
            );
          }
        } catch (e) {
          print('⚠️ Item parse error: $e');
        }
      }
    } catch (e) {
      print('❌ parseBatch error: $e');
    }

    print('🔍 Final batch results: $results');
    return results;
  }

  // ── HELPERS ──────────────────────────────────────────────────────

static String _cleanJson(String raw) {
  return raw
      .replaceAll('```json', '')
      .replaceAll('```', '')
      .replaceAll('Here is the JSON:', '')
      .replaceAll('Sure! Here is the result:', '')
      .trim();
}

  static String? _matchSubject(String subject, List<String> subjects) {
    if (subject.isEmpty) return null;
    if (subjects.contains(subject)) return subject;
    for (final s in subjects) {
      if (s.toLowerCase() == subject.toLowerCase()) return s;
    }
    final sorted = [...subjects]..sort((a, b) => b.length.compareTo(a.length));
    for (final s in sorted) {
      if (s.toLowerCase().contains(subject.toLowerCase()) ||
          subject.toLowerCase().contains(s.toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  static ({String subject, double confidence, String reasoning})
_scanForSubject(String raw, List<String> subjects) {

  final lower = raw.toLowerCase();

  for (final subject in subjects) {
    if (lower.contains(subject.toLowerCase())) {
      return (
        subject: subject,
        confidence: 0.55,
        reasoning: 'Matched subject name in response'
      );
    }
  }

  return (
    subject: 'Unclassified',
    confidence: 0.0,
    reasoning: 'No recognizable subject'
  );
}
}
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ocr_result.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiClassifier {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static GenerativeModel? _model;
  static GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 8192,
       responseMimeType: 'application/json',
      ),
    //systemInstruction: Content.system("Return only a JSON object mapping keywords to subjects."),
  );
  return _model!;
}
  static Future<({String subject, double confidence, String reasoning})> classify(
    OcrResult ocrResult,
    List<String> subjects,
  ) async {
    print('GEMINI SINGLE START');
    print('Subjects: $subjects');
    final prompt = _buildSinglePrompt(_buildText(ocrResult), subjects);
    try {
      print('Calling Gemini single API...');
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      print('Gemini single response received (len=${responseText.length})');
      return _parseSingle(responseText, subjects);
    } catch (e) {
      print('Gemini single API error: $e');
      return (subject: 'Unclassified', confidence: 0.0, reasoning: 'API Error: $e');
    }
  }

  static Future<List<({String subject, double confidence})>> classifyBatch(
    List<OcrResult> batch,
    List<String> subjects, {
    void Function(String)? onLog,
  }) async {
    void log(String msg) {
      print(msg);
      onLog?.call(msg);
    }

    log('GEMINI BATCH START');
    log('Batch size: ${batch.length}');
    log('Subjects available: $subjects'); // FIX: log exact subject list for debugging

    final fallback = List.generate(
      batch.length,
      (_) => (subject: 'Unclassified', confidence: 0.0),
    );

    if (batch.isEmpty) return fallback;

    final prompt = _buildBatchPrompt(batch, subjects);
    log('Batch prompt built (len=${prompt.length})');

    try {
      log('Calling Gemini batch API...');
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      log('Gemini batch response received (len=${responseText.length})');
      log('Raw response preview: ${responseText.substring(0, responseText.length.clamp(0, 300))}');
      return _parseBatch(responseText, batch.length, subjects, fallback, onLog: onLog);
    } catch (e) {
      log('Gemini batch API error: $e');
      return fallback;
    }
  }

  static String _buildText(OcrResult ocr) {
    final topKeywords = ocr.keywords.take(20).join(', ');
    final rawPreview = ocr.rawText.length > 300
        ? ocr.rawText.substring(0, 300)
        : ocr.rawText;
    return 'KEYWORDS: $topKeywords\nRAW_PREVIEW: $rawPreview';
  }

  static String _buildSinglePrompt(String text, List<String> subjects) {
    return '''You are an academic subject classifier for OCR lecture notes.
The text may contain spelling mistakes, broken words, or shorthand.
NOTE TEXT: """
$text
"""
AVAILABLE SUBJECTS: ${subjects.join(', ')}
Instructions:
* Infer the subject using technical concepts, not just exact keywords.
* Correct OCR mistakes mentally.
* Choose the most likely subject from the list.
* Only return "Unclassified" if the text has zero academic meaning.

Return STRICT JSON ONLY:
{ "subject": "EXACT_NAME_FROM_LIST", "confidence": 0.0, "reasoning": "Short explanation" }''';
  }

  static String _buildBatchPrompt(List<OcrResult> batch, List<String> subjects) {
    final subjectList = subjects.join(', ');

    final noteBlocks = batch.asMap().entries.map((e) {
      final text = _buildText(e.value);
      return 'NOTE ${e.key + 1}:\n"""\n$text\n"""';
    }).join('\n\n');

    return '''You are an academic subject classifier for OCR lecture notes.
The text may contain spelling mistakes, broken words, or shorthand.

AVAILABLE SUBJECTS: $subjectList

Instructions:
* Infer the subject using technical concepts, not just exact keywords.
* Correct OCR mistakes mentally.
* Choose the most likely subject from the list.
* Only return "Unclassified" if the text has zero academic meaning.

Examples of concept mapping:
agent, heuristic, search -> Artificial Intelligence
packet, routing, subnet -> Computer Networks
CPU, clock cycle, pipeline -> Computer Architecture
matrix, vector, integral -> Mathematics

$noteBlocks

Classify EACH note above. Return a JSON array with one entry per note.
The array MUST have exactly ${batch.length} items.

IMPORTANT: Return ONLY the raw JSON array. No markdown, no backticks, no explanation. Start your response with [ and end with ].

[
  {
    "id": 1,
    "reasoning": "Explain the technical concepts found in the text",
    "subject": "EXACT_NAME_FROM_LIST",
    "confidence": 0.0
  }
]

Rules:
* id starts at 1
* reasoning MUST be provided before subject (chain-of-thought)
* subject MUST be exactly one of: $subjectList
* confidence is between 0.0 and 1.0
* Never return an empty array
* Return ALL ${batch.length} results
* DO NOT wrap the response in markdown code fences''';
  }

  static ({String subject, double confidence, String reasoning}) _parseSingle(
    String raw,
    List<String> subjects,
  ) {
    try {
      final cleaned = _cleanJson(raw);
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end <= start) return _scanForSubject(raw, subjects);

      final jsonStr = cleaned.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      final subject = decoded['subject']?.toString() ?? '';
      final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;
      final reasoning = decoded['reasoning']?.toString() ?? 'No reasoning provided';
      final matchedSubject = _matchSubject(subject, subjects, onLog: print) ?? 'Unclassified';

      return (subject: matchedSubject, confidence: confidence, reasoning: reasoning);
    } catch (e) {
      print('_parseSingle error: $e');
      return _scanForSubject(raw, subjects);
    }
  }

  static List<({String subject, double confidence})> _parseBatch(
    String raw,
    int expectedCount,
    List<String> subjects,
    List<({String subject, double confidence})> fallback, {
    void Function(String)? onLog,
  }) {
    void log(String msg) {
      print(msg);
      onLog?.call(msg);
    }

    final results = List<({String subject, double confidence})>.from(fallback);

    try {
      final cleaned = _cleanJson(raw);
      log('parseBatch: cleaned response (len=${cleaned.length})');
      log('parseBatch: cleaned preview: ${cleaned.substring(0, cleaned.length.clamp(0, 200))}');

      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');

      if (start == -1 || end <= start) {
        log('parseBatch: no JSON array found — cleaned text had no [ ] brackets');
        log('parseBatch: full cleaned dump: $cleaned');
        return results;
      }

      final jsonStr = cleaned.substring(start, end + 1);
      log('parseBatch: parsing JSON array (len=${jsonStr.length})');

      final decodedList = jsonDecode(jsonStr) as List<dynamic>;
      log('parseBatch: decoded ${decodedList.length} items (expected $expectedCount)');

      for (final item in decodedList) {
        if (item is Map<String, dynamic>) {
          final id = (item['id'] as num?)?.toInt();
          final reasoning = item['reasoning']?.toString() ?? 'No reasoning';
          final rawSubject = item['subject']?.toString() ?? '';
          final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.0;

          // FIX: log the RAW subject string from Gemini so we can see exactly
          // what it returned vs what's in our list
          log('Photo $id raw subject from Gemini: "$rawSubject"');

          if (id != null && id >= 1 && id <= expectedCount) {
            final matchedSubject = _matchSubject(
              rawSubject,
              subjects,
              onLog: onLog,
            ) ?? 'Unclassified';

            log('Photo $id -> "$matchedSubject" (${(confidence * 100).toStringAsFixed(0)}%) | $reasoning');
            results[id - 1] = (subject: matchedSubject, confidence: confidence);
          } else {
            log('parseBatch: skipping item with invalid id=$id');
          }
        }
      }
    } catch (e) {
      log('parseBatch error: $e');
      log('parseBatch raw dump (first 500): ${raw.substring(0, raw.length.clamp(0, 500))}');
    }

    return results;
  }

  static String _cleanJson(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '');
    final phrasesToStrip = [
      'Here is the JSON:',
      'Here is the JSON array:',
      'Sure! Here is the result:',
      'Sure, here is the classification:',
      'Here are the results:',
    ];
    for (final phrase in phrasesToStrip) {
      cleaned = cleaned.replaceAll(phrase, '');
    }
    return cleaned.trim();
  }

  // FIX: robust multi-strategy matcher with logging so you can see why it fails
  static String? _matchSubject(
    String subject,
    List<String> subjects, {
    void Function(String)? onLog,
    void Function(String)? onLog2, // legacy param name alias, ignored
  }) {
    void log(String msg) {
      print(msg);
      onLog?.call(msg);
    }

    if (subject.isEmpty) {
      log('_matchSubject: empty subject string');
      return null;
    }

    // Strategy 1: exact match
    if (subjects.contains(subject)) {
      log('_matchSubject: exact match "$subject"');
      return subject;
    }

    // Strategy 2: case-insensitive exact match
    final subjectLower = subject.toLowerCase().trim();
    for (final s in subjects) {
      if (s.toLowerCase().trim() == subjectLower) {
        log('_matchSubject: case-insensitive exact match "$subject" -> "$s"');
        return s;
      }
    }

    // Strategy 3: normalized match — remove punctuation/extra spaces
    final subjectNorm = _normalize(subject);
    for (final s in subjects) {
      if (_normalize(s) == subjectNorm) {
        log('_matchSubject: normalized match "$subject" -> "$s"');
        return s;
      }
    }

    // Strategy 4: one fully contains the other (longest first to avoid false short matches)
    final sorted = [...subjects]..sort((a, b) => b.length.compareTo(a.length));
    for (final s in sorted) {
      final sLower = s.toLowerCase().trim();
      if (sLower.contains(subjectLower) || subjectLower.contains(sLower)) {
        log('_matchSubject: contains match "$subject" -> "$s"');
        return s;
      }
    }

    // Strategy 5: word overlap — if 2+ words match it's probably right
    final subjectWords = subjectLower.split(RegExp(r'\s+')).toSet();
    for (final s in sorted) {
      final sWords = s.toLowerCase().split(RegExp(r'\s+')).toSet();
      final overlap = subjectWords.intersection(sWords).length;
      if (overlap >= 2) {
        log('_matchSubject: word overlap ($overlap words) "$subject" -> "$s"');
        return s;
      }
    }

    // Strategy 6: single meaningful word match (skip short stop words)
    const stopWords = {'the', 'of', 'and', 'to', 'a', 'in', 'for', 'is'};
    for (final s in sorted) {
      final sWords = s.toLowerCase().split(RegExp(r'\s+')).toSet();
      final meaningfulOverlap = subjectWords
          .intersection(sWords)
          .where((w) => w.length > 3 && !stopWords.contains(w));
      if (meaningfulOverlap.isNotEmpty) {
        log('_matchSubject: meaningful word match ${meaningfulOverlap.toList()} "$subject" -> "$s"');
        return s;
      }
    }

    log('_matchSubject: NO MATCH for "$subject" against $subjects');
    return null;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ');   // collapse spaces
  }

  static ({String subject, double confidence, String reasoning}) _scanForSubject(
    String raw,
    List<String> subjects,
  ) {
    final lower = raw.toLowerCase();
    for (final subject in subjects) {
      if (lower.contains(subject.toLowerCase())) {
        return (
          subject: subject,
          confidence: 0.55,
          reasoning: 'Matched subject name in response',
        );
      }
    }
    return (subject: 'Unclassified', confidence: 0.0, reasoning: 'No recognizable subject');
  }
}
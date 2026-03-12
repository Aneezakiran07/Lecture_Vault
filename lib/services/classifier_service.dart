import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ocr_result.dart';
import 'gemini_classifier.dart';
import 'ocr_service.dart';

class ClassifierService {
  static const _batchSize = 10;
  static const _parallelBatches = 3;
  static const _batchGap = Duration(seconds: 5);

  // ── CLASSIFY ALL FROM OCR ────────────────────────────────────────

  static Future<List<({String subject, double confidence})>>
      classifyAllFromOcr(
    List<OcrResult> ocrResults,
    List<String> userSubjects, {
    void Function(int completed, int total)? onProgress,
  }) async {
    print('====== CLASSIFY ALL FROM OCR ======');
    print('Total images: ${ocrResults.length}');
    print('Subjects: $userSubjects');

    if (ocrResults.isEmpty) {
      print('❌ No OCR results');
      return [];
    }

    // Log each OCR result
    for (int i = 0; i < ocrResults.length; i++) {
      print('OCR[$i]: rawLen=${ocrResults[i].rawText.length} '
          'keywords=${ocrResults[i].keywords.take(5).toList()}');
    }

    print('🌐 Checking internet...');
    final hasInternet = await _hasInternet();
    print('🌐 Internet: $hasInternet');

    if (!hasInternet) {
      print('❌ NO INTERNET — returning No Internet for all');
      return List.generate(
        ocrResults.length,
        (_) => (subject: 'No Internet', confidence: 0.0),
      );
    }

    final results = List<({String subject, double confidence})>.filled(
      ocrResults.length,
      (subject: 'Unclassified', confidence: 0.0),
    );

    final batches = _chunk(ocrResults, _batchSize);
    print('📦 Created ${batches.length} batches of max $_batchSize');

    int completed = 0;

    for (int i = 0; i < batches.length; i += _parallelBatches) {
      final roundBatches = batches.sublist(
        i,
        (i + _parallelBatches).clamp(0, batches.length),
      );

      print('🚀 Round ${(i ~/ _parallelBatches) + 1}: '
          '${roundBatches.length} parallel batch calls');

      await Future.wait(
        roundBatches.asMap().entries.map((entry) async {
          final batchIdx = i + entry.key;
          final batch = entry.value;
          final startIdx = batchIdx * _batchSize;

          print('  📤 Sending batch ${batchIdx + 1} '
              '(${batch.length} photos, startIdx=$startIdx)');

          final batchResults =
              await GeminiClassifier.classifyBatch(batch, userSubjects);

          for (int j = 0; j < batchResults.length; j++) {
            final globalIdx = startIdx + j;
            if (globalIdx < results.length) {
              results[globalIdx] = batchResults[j];
              print('  ✅ Photo[$globalIdx] → '
                  '${batchResults[j].subject} '
                  '(${(batchResults[j].confidence * 100).toStringAsFixed(0)}%)');
            }
          }

          completed += batch.length;
          onProgress?.call(completed, ocrResults.length);
          print('  Progress: $completed/${ocrResults.length}');
        }),
        eagerError: false,
      );

      final isLastRound = i + _parallelBatches >= batches.length;
      if (!isLastRound) {
        print('⏳ Waiting ${_batchGap.inSeconds}s before next round...');
        await Future.delayed(_batchGap);
      }
    }

    print('🎉 Classification complete!');
    print('Final results: $results');
    return results;
  }

  // ── CLASSIFY ALL FROM PATHS ──────────────────────────────────────

  static Future<List<({String subject, double confidence})>>
      classifyAll(
    List<String> imagePaths,
    List<String> userSubjects, {
    void Function(int completed, int total)? onProgress,
  }) async {
    print('====== CLASSIFY ALL FROM PATHS ======');
    print('Paths: ${imagePaths.length}');

    if (imagePaths.isEmpty) return [];

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      return List.generate(
        imagePaths.length,
        (_) => (subject: 'No Internet', confidence: 0.0),
      );
    }

    print('🔍 Running OCR on all images...');
    final ocrResults = await Future.wait(
      imagePaths.map((path) => _safeOcr(path)),
      eagerError: false,
    );
    print('✅ OCR done for ${ocrResults.length} images');

    return classifyAllFromOcr(ocrResults, userSubjects,
        onProgress: onProgress);
  }

  // ── SINGLE CLASSIFY ──────────────────────────────────────────────

  static Future<({String subject, double confidence})> classify(
    OcrResult ocrResult,
    List<String> userSubjects,
  ) async {
    print('====== SINGLE CLASSIFY ======');
    print('Subjects: $userSubjects');
    print('Raw text length: ${ocrResult.rawText.length}');
    print('Keywords: ${ocrResult.keywords.take(8).toList()}');

    if (userSubjects.isEmpty) {
      print('❌ No subjects');
      return (subject: 'Unclassified', confidence: 0.0);
    }

    print('🌐 Checking internet...');
    final hasInternet = await _hasInternet();
    print('🌐 Internet: $hasInternet');

    if (!hasInternet) {
      print('❌ No internet');
      return (subject: 'No Internet', confidence: 0.0);
    }

    final (:subject, :confidence, reasoning: _) =
        await GeminiClassifier.classify(ocrResult, userSubjects);

    print('✅ Result: $subject ($confidence)');
    return (subject: subject, confidence: confidence);
  }

  // ── HELPERS ──────────────────────────────────────────────────────

  static Future<OcrResult> _safeOcr(String path) async {
    print('🔍 OCR: $path');
    try {
      final result = await OcrService.extractRich(path);
      print('✅ OCR done: ${result.keywords.length} keywords, '
          'rawLen=${result.rawText.length}');
      return result;
    } catch (e) {
      print('❌ OCR failed for $path: $e');
      return OcrResult(
        rawText: '',
        cleanedText: '',
        keywords: [],
        patterns: [],
        textDensity: 0.0,
      );
    }
  }

  static List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return chunks;
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('❌ Internet check failed: $e');
      return false;
    }
  }

  // ── LEGACY ───────────────────────────────────────────────────────

  static Future<({String subject, double confidence})>
      getBestMatchWithImage(
    String imagePath,
    String ocrText,
    List<String> userSubjects,
  ) async {
    final ocrResult = OcrResult(
      rawText: ocrText,
      cleanedText: ocrText,
      keywords: ocrText
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toList(),
      patterns: [],
      textDensity: ocrText.length > 50 ? 0.5 : 0.1,
    );
    return classify(ocrResult, userSubjects);
  }
}
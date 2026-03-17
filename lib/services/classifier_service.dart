import 'dart:io';
import 'ocr_result.dart';
import 'gemini_classifier.dart';

class ClassifierService {

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // classify all ocr results in ONE single Gemini request
  static Future<List<({String subject, double confidence})>> classifyAllFromOcr(
    List<OcrResult> ocrResults,
    List<String> userSubjects, {
    void Function(int completed, int total)? onProgress,
    void Function(String)? onLog,
  }) async {
    if (ocrResults.isEmpty) return [];

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      return List.generate(
        ocrResults.length,
        (_) => (subject: 'No Internet', confidence: 0.0),
      );
    }

    onProgress?.call(0, ocrResults.length);

    final results = await GeminiClassifier.classifyBatch(
      ocrResults,
      userSubjects,
      onLog: onLog,
    );

    onProgress?.call(ocrResults.length, ocrResults.length);

    return results;
  }

  // single image classify, used by camera pick
  static Future<({String subject, double confidence})> classify(
    OcrResult ocrResult,
    List<String> userSubjects,
  ) async {
    if (userSubjects.isEmpty) {
      return (subject: 'Unclassified', confidence: 0.0);
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      return (subject: 'No Internet', confidence: 0.0);
    }

    final result = await GeminiClassifier.classify(ocrResult, userSubjects);
    return (subject: result.subject, confidence: result.confidence);
  }
}
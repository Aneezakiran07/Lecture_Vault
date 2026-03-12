import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_enhancer.dart';
import 'ocr_result.dart';

class OcrService {
  static final _textRecognizer = TextRecognizer();

  static Future<OcrResult> extractRich(String imagePath) async {
    String enhancedPath = imagePath;
    try {
      // Step 1: Pre-process
      enhancedPath =
          await OcrEnhancer.preprocessImage(imagePath);

      // Step 2: OCR
      final inputImage =
          InputImage.fromFilePath(enhancedPath);
      final recognized =
          await _textRecognizer.processImage(inputImage);
      final rawText = recognized.text.trim();

      // Step 3: Post-process
      return OcrEnhancer.processRawText(rawText, imagePath);
    } catch (e) {
      // Try original image as fallback
      try {
        final inputImage =
            InputImage.fromFilePath(imagePath);
        final recognized =
            await _textRecognizer.processImage(inputImage);
        final rawText = recognized.text.trim();
        return OcrEnhancer.processRawText(rawText, imagePath);
      } catch (_) {
        // Total failure — return empty result, don't crash
        return OcrResult(
          rawText: '',
          cleanedText: '',
          keywords: [],
          patterns: [],
          textDensity: 0.0,
        );
      }
    } finally {
      // Always cleanup
      await OcrEnhancer.cleanupTempFile(enhancedPath);
    }
  }

  static Future<String> extractText(String imagePath) async {
    try {
      final result = await extractRich(imagePath);
      return result.cleanedText;
    } catch (_) {
      return '';
    }
  }

  static Future<OcrResult> extractFromMultiple(
      List<String> imagePaths) async {
    final allKeywords = <String>[];
    final allPatterns = <String>[];
    final allRaw = StringBuffer();
    final allClean = StringBuffer();
    double totalDensity = 0;
    bool anyDigital = false;
    bool anyHandwriting = false;

    for (final path in imagePaths) {
      try {
        final result = await extractRich(path);
        allKeywords.addAll(result.keywords);
        allPatterns.addAll(result.patterns);
        allRaw.writeln(result.rawText);
        allClean.writeln(result.cleanedText);
        totalDensity += result.textDensity;
        if (result.isDigitalScreenshot) anyDigital = true;
        if (result.hasHandwriting) anyHandwriting = true;
      } catch (_) {
        continue; // skip failed image, don't crash
      }
    }

    return OcrResult(
      rawText: allRaw.toString(),
      cleanedText: allClean.toString(),
      keywords: allKeywords.toSet().toList(),
      patterns: allPatterns.toSet().toList(),
      textDensity: imagePaths.isEmpty
          ? 0.0
          : totalDensity / imagePaths.length,
      isDigitalScreenshot: anyDigital,
      hasHandwriting: anyHandwriting,
    );
  }

  static void dispose() {
    try {
      _textRecognizer.close();
    } catch (_) {}
  }
}



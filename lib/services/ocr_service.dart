import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'ocr_enhancer.dart';
import 'ocr_result.dart';

class OcrService {
  static final _textRecognizer = TextRecognizer();

  static Future<OcrResult> extractRich(String imagePath) async {
    String enhancedPath = imagePath;
    try {
      // Step 1: Fix EXIF rotation FIRST — ML Kit does NOT auto-rotate,
      // so a 90° or 180° photo returns garbage text without this
      final rotatedFile = await FlutterExifRotation.rotateImage(
        path: imagePath,
      );
      final correctedPath = rotatedFile.path;

      // Step 2: Pre-process (currently a passthrough, kept for future use)
      enhancedPath = await OcrEnhancer.preprocessImage(correctedPath);

      // Step 3: OCR on the correctly-oriented image
      final inputImage = InputImage.fromFilePath(enhancedPath);
      final recognized = await _textRecognizer.processImage(inputImage);
      final rawText = recognized.text.trim();

      // Step 4: Post-process
      return OcrEnhancer.processRawText(rawText, imagePath);
    } catch (e) {
      // Fallback 1: try without rotation fix (covers edge cases where
      // flutter_exif_rotation fails on certain image formats)
      try {
        enhancedPath = await OcrEnhancer.preprocessImage(imagePath);
        final inputImage = InputImage.fromFilePath(enhancedPath);
        final recognized = await _textRecognizer.processImage(inputImage);
        final rawText = recognized.text.trim();
        return OcrEnhancer.processRawText(rawText, imagePath);
      } catch (_) {
        // Fallback 2: bare original image, no preprocessing at all
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognized = await _textRecognizer.processImage(inputImage);
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
      }
    } finally {
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
        continue;
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


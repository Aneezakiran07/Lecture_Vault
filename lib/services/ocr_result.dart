class OcrResult {
  final String rawText;
  final String cleanedText;
  final List<String> keywords;
  final List<String> patterns;
  final double textDensity;
  final bool isDigitalScreenshot;
  final bool hasHandwriting;

  const OcrResult({
    required this.rawText,
    required this.cleanedText,
    required this.keywords,
    required this.patterns,
    required this.textDensity,
    this.isDigitalScreenshot = false,
    this.hasHandwriting = false,
  });

  String get classifierInput =>
      '$cleanedText ${patterns.join(' ')} ${keywords.join(' ')}';

  // ← Lower from 3 to 1 — garbled OCR still has some words
  bool get hasEnoughText => keywords.isNotEmpty || rawText.length > 20;

  @override
  String toString() =>
      'OcrResult(keywords: ${keywords.length}, '
      'patterns: ${patterns.length}, '
      'density: ${textDensity.toStringAsFixed(2)})';
}
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import 'ocr_result.dart';

class OcrEnhancer {

  // Preprocessing skipped — ML Kit handles raw images well
  static Future<String> preprocessImage(String imagePath) async {
    return imagePath; // return original, no processing
  }

  static OcrResult processRawText(
      String rawText, String imagePath) {
    if (rawText.trim().isEmpty) {
      return OcrResult(
        rawText: '',
        cleanedText: '',
        keywords: [],
        patterns: [],
        textDensity: 0.0,
      );
    }

    try {
      final fixed = _fixOcrErrors(rawText);
      final patterns = _extractPatterns(fixed);
      final keywords = _extractKeywords(fixed);
      final expanded = _expandKeywords(keywords);
      final density = _calculateDensity(rawText, keywords);
      final isDigital = _isDigitalScreenshot(rawText);
      final hasHandwriting = _hasHandwriting(rawText);

      return OcrResult(
        rawText: rawText,
        cleanedText: fixed,
        keywords: [...keywords, ...expanded].toSet().toList(),
        patterns: patterns.toSet().toList(),
        textDensity: density,
        isDigitalScreenshot: isDigital,
        hasHandwriting: hasHandwriting,
      );
    } catch (e) {
      return OcrResult(
        rawText: rawText,
        cleanedText: rawText,
        keywords: rawText
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 3)
            .toList(),
        patterns: [],
        textDensity: 0.3,
      );
    }
  }

  static String _fixOcrErrors(String text) {
    try {
      final corrections = {
        'Ca1cu1us': 'Calculus',
        'ca1cu1us': 'calculus',
        'A1gebra': 'Algebra',
        'a1gebra': 'algebra',
        'Ph4sics': 'Physics',
        'B1ology': 'Biology',
        'Ch3mistry': 'Chemistry',
        'H1story': 'History',
        'G3ography': 'Geography',
      };

      String result = text;
      for (final entry in corrections.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
      return result.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return text;
    }
  }

  static List<String> _extractPatterns(String text) {
    final patterns = <String>[];
    try {
      final lower = text.toLowerCase();

      final patternMap = <RegExp, String>{
        RegExp(r'd/d[xy]|dy/dx'): 'derivative calculus',
        RegExp(r'\bintegral\b|∫'): 'integral calculus',
        RegExp(r'\blim\b|\blimit\b'): 'limit calculus',
        RegExp(r'\bsin\b|\bcos\b|\btan\b'): 'trigonometry',
        RegExp(r'\bmatrix\b|\bdeterminant\b'): 'matrix algebra',
        RegExp(r'\blog\b|\bln\b|\blogarithm\b'): 'logarithm mathematics',
        RegExp(r'\bprobability\b|\bstatistics\b'): 'probability statistics',
        RegExp(r'\bNewton\b|\bforce\b.*\bmass\b'): 'force newton physics',
        RegExp(r'\bvelocity\b|\bacceleration\b|\bkinematics\b'): 'kinematics motion',
        RegExp(r'\bcurrent\b|\bvoltage\b|\bresistance\b'): 'electricity circuit',
        RegExp(r'\bwavelength\b|\bfrequency\b|\bamplitude\b'): 'waves frequency physics',
        RegExp(r'\bkinetic energy\b|\bpotential energy\b'): 'energy physics',
        RegExp(r'\bacid\b|\bbase\b|\bpH\b'): 'acid base chemistry',
        RegExp(r'\boxidation\b|\breduction\b|\bredox\b'): 'redox chemistry',
        RegExp(r'\bionic\b|\bcovalent\b'): 'chemical bond',
        RegExp(r'\bperiodic table\b|\belement\b|\batom\b'): 'periodic table chemistry',
        RegExp(r'\bmole\b|\bmolecule\b'): 'mole chemistry',
        RegExp(r'\bDNA\b|\bRNA\b|\bgenetics\b'): 'genetics dna biology',
        RegExp(r'\bcell membrane\b|\bcell wall\b'): 'cell biology',
        RegExp(r'\bphotosynthesis\b'): 'photosynthesis biology',
        RegExp(r'\brespiration\b|\bATP\b'): 'respiration biology',
        RegExp(r'\bevolution\b|\bnatural selection\b'): 'evolution biology',
        RegExp(r'\bdef\s+\w|\bfunction\s+\w'): 'function programming',
        RegExp(r'\bfor\s*\(|\bwhile\s*\('): 'loop programming',
        RegExp(r'\bclass\s+[A-Z]|\binheritance\b'): 'oop programming',
        RegExp(r'\barray\b|\bstack\b|\bqueue\b'): 'data structure',
        RegExp(r'\bSELECT\b|\bFROM\b|\bSQL\b'): 'database sql',
        RegExp(r'\bsupply\b|\bdemand\b|\bequilibrium\b'): 'supply demand economics',
        RegExp(r'\bGDP\b|\binflation\b|\bdeflation\b'): 'macroeconomics',
        RegExp(r'\bdebit\b|\bcredit\b|\bbalance sheet\b'): 'accounting',
        RegExp(r'\b(1[0-9]{3}|20[0-2][0-9])\b'): 'year history',
        RegExp(r'\bWorld War\b|\bWWII\b|\bWWI\b'): 'world war history',
        RegExp(r'\brevolution\b|\bindependence movement\b'): 'revolution history',
      };

      for (final entry in patternMap.entries) {
        try {
          if (entry.key.hasMatch(lower) || entry.key.hasMatch(text)) {
            patterns.addAll(entry.value.split(' '));
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return patterns;
  }

  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at',
    'to', 'for', 'of', 'with', 'by', 'from', 'is', 'are',
    'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do',
    'does', 'did', 'will', 'would', 'could', 'should', 'this',
    'that', 'these', 'those', 'it', 'its', 'we', 'you', 'he',
    'she', 'they', 'not', 'no', 'so', 'if', 'as', 'up', 'out',
    'pg', 'page', 'ch', 'fig', 'note', 'notes', 'see', 'ref',
  };

  static List<String> _extractKeywords(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .where((w) => !_stopWords.contains(w))
          .where((w) => !RegExp(r'^\d+$').hasMatch(w))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<String> _expandKeywords(List<String> keywords) {
    final expansions = <String>[];
    try {
      const expandMap = <String, List<String>>{
        'calculus': ['mathematics', 'differentiation', 'integration'],
        'derivative': ['calculus', 'mathematics'],
        'integral': ['calculus', 'mathematics'],
        'matrix': ['algebra', 'mathematics'],
        'vector': ['mathematics', 'physics'],
        'probability': ['statistics', 'mathematics'],
        'velocity': ['physics', 'kinematics'],
        'acceleration': ['physics', 'kinematics'],
        'momentum': ['physics', 'motion'],
        'circuit': ['physics', 'electricity'],
        'molecule': ['chemistry', 'compound'],
        'element': ['chemistry', 'periodic'],
        'reaction': ['chemistry', 'equation'],
        'enzyme': ['biology', 'chemistry'],
        'cell': ['biology', 'organism'],
        'dna': ['biology', 'genetics'],
        'evolution': ['biology', 'darwin'],
        'photosynthesis': ['biology', 'plants'],
        'algorithm': ['computer science', 'programming'],
        'variable': ['programming', 'computer science'],
        'revolution': ['history', 'political'],
        'empire': ['history', 'civilization'],
        'inflation': ['economics', 'monetary'],
        'gdp': ['economics', 'macroeconomics'],
        'debit': ['accounting', 'finance'],
        'credit': ['accounting', 'finance'],
        'supply': ['economics', 'market'],
        'demand': ['economics', 'market'],
        'islamiat': ['islam', 'quran', 'religious'],
        'pakistan': ['history', 'pakistan studies'],
        'urdu': ['language', 'literature'],
      };

      for (final keyword in keywords) {
        final related = expandMap[keyword.toLowerCase()];
        if (related != null) expansions.addAll(related);
      }
    } catch (_) {}
    return expansions;
  }

  static double _calculateDensity(
      String rawText, List<String> keywords) {
    try {
      if (rawText.isEmpty) return 0.0;
      final wordCount = rawText.split(RegExp(r'\s+')).length;
      return (keywords.length / max(wordCount, 1)).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  static bool _isDigitalScreenshot(String text) {
    try {
      return RegExp(r'https?://').hasMatch(text) ||
          RegExp(r'Page \d+ of \d+').hasMatch(text);
    } catch (_) {
      return false;
    }
  }

  static bool _hasHandwriting(String text) {
    try {
      return RegExp(r'[a-z][A-Z][a-z]').allMatches(text).length > 3;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cleanupTempFile(String path) async {
    try {
      if (path.contains('lv_enhanced')) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }
}


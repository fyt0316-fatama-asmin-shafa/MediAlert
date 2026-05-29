import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MedicineScanner {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<Map<String, String>> extractMedicineInfo(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text;
      print('📸 OCR RAW TEXT:\n$fullText');

      String name = _extractMedicineName(fullText);
      String dose = _extractDose(fullText);

      print('✅ Extracted -> Name: "$name", Dose: "$dose"');
      return {
        'medicineName': name,
        'dose': dose,
      };
    } catch (e) {
      print('❌ OCR Error: $e');
      return {'medicineName': '', 'dose': ''};
    }
  }

  /// Extracts medicine name using smart filtering
  String _extractMedicineName(String text) {
    final lines = text.split('\n');

    // Common words that are NOT medicine names
    final ignoreWords = RegExp(
      r'^(rx|tablet|capsule|pill|dosage|take|once|daily|morning|night|after|before|meal|with|water|store|keep|out|of|reach|children|consult|doctor|pharmacist|manufacturer|exp|lot|no|ndc|generic|brand|strip|blister|pack|box|bottle|mg|mcg|g|ml|%|$|\d|\(|\))',
      caseSensitive: false,
    );

    // Priority: lines that look like a proper drug name
    String bestName = '';
    for (String line in lines) {
      String clean = line.trim();
      if (clean.isEmpty) continue;

      // Must be longer than 3 characters and contain letters
      if (clean.length < 3) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(clean)) continue;

      // Skip lines that start with common filler/irrelevant words
      if (ignoreWords.hasMatch(clean.toLowerCase())) continue;

      // Prefer lines that have no digits or only few (medicine name rarely has many digits)
      int digitCount = clean.replaceAll(RegExp(r'[^0-9]'), '').length;
      if (digitCount > 2) continue; // e.g., "12345" is not a name

      // Prefer lines that are mostly letters and spaces
      double letterRatio = clean.replaceAll(RegExp(r'[^A-Za-z ]'), '').length / clean.length;
      if (letterRatio < 0.6) continue;

      // Additional: if line contains 'mg' or strength, it's probably not the name
      if (RegExp(r'\d+\s?(mg|mcg|g|ml)', caseSensitive: false).hasMatch(clean)) continue;

      // Good candidate found
      if (bestName.isEmpty || clean.length > bestName.length) {
        bestName = clean;
      }
    }

    // If still empty, fallback to first line that has letters and is not too short
    if (bestName.isEmpty) {
      for (String line in lines) {
        String clean = line.trim();
        if (clean.length >= 3 && RegExp(r'[A-Za-z]').hasMatch(clean)) {
          bestName = clean;
          break;
        }
      }
    }

    // Clean up extra punctuation and common suffixes
    bestName = bestName.replaceAll(RegExp(r'[^A-Za-z0-9\s\-]'), '').trim();
    return bestName;
  }

  /// Extracts dose (strength) like "500mg", "250 mg", "10ml", "5 mcg", etc.
  String _extractDose(String text) {
    // Pattern: number + optional space + unit (mg, g, ml, mcg, etc.)
    final doseRegex = RegExp(
      r'\b(\d+(?:\.\d+)?)\s?(mg|mcg|µg|g|ml|iu)\b',
      caseSensitive: false,
    );
    final matches = doseRegex.allMatches(text);
    if (matches.isNotEmpty) {
      // Return first match, formatted as "500 mg" (with space)
      final match = matches.first;
      final value = match.group(1)!;
      String unit = match.group(2)!.toLowerCase();
      // Normalize unit
      if (unit == 'mcg' || unit == 'µg') unit = 'mcg';
      if (unit == 'iu') unit = 'IU';
      return '$value $unit'.toUpperCase();
    }

    // Also try to find standalone numbers near unit words (fallback)
    final altRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:milligram|gram|millilitre|microgram)', caseSensitive: false);
    final altMatches = altRegex.allMatches(text);
    if (altMatches.isNotEmpty) {
      final match = altMatches.first;
      final value = match.group(1)!;
      return '$value mg'; // default to mg
    }

    return '';
  }

  void dispose() {
    _textRecognizer.close();
  }
}
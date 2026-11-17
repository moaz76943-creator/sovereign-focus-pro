import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/core/i18n/language_registry_100.dart';

void main() {
  test('100-language registry has exactly 100 languages and strictly excludes Hebrew', () {
    final regFile = File('locales/registry_100.json');
    expect(regFile.existsSync(), isTrue);
    final data = jsonDecode(regFile.readAsStringSync()) as Map<String, dynamic>;
    final langs = data['languages'] as List<dynamic>;
    expect(langs.length, 100);

    final codes = langs.map((e) => (e['code'] as String).toLowerCase()).toSet();
    expect(codes.length, 100);
    expect(codes.contains('he'), isFalse);
    expect(codes.contains('iw'), isFalse);
  });

  test('Batch 1 (languages 1..35) locale files have 100% key coverage and Western digits', () {
    final regData = jsonDecode(File('locales/registry_100.json').readAsStringSync())
        as Map<String, dynamic>;
    final langs = (regData['languages'] as List<dynamic>).take(35).toList();
    expect(langs.length, 35);

    for (final item in langs) {
      final code = item['code'] as String;
      final f = File('locales/$code.json');
      expect(f.existsSync(), isTrue, reason: 'Missing locale file for $code');
      final rawMap = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final strMap = rawMap.map((k, v) => MapEntry(k, v.toString()));

      final report = LanguageRegistry100.evaluateLocalePack(
        languageCode: code,
        translations: strMap,
        deviceTtsVoiceInstalled: null, // Evaluated independently on device
      );
      expect(report.translationComplete, isTrue, reason: 'Incomplete keys in $code');
      expect(report.missingKeysCount, 0);
      expect(report.usesWesternDigitsOnly, isTrue, reason: 'Non-Western digits in $code');
    }
  });
}

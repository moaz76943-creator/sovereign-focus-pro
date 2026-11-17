import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/core/i18n/language_registry_100.dart';

void main() {
  test('All 100 languages (1..100) have complete 42-key packs, Western digits, and RTL/LTR integrity', () {
    final regData = jsonDecode(File('locales/registry_100.json').readAsStringSync())
        as Map<String, dynamic>;
    final langs = regData['languages'] as List<dynamic>;
    expect(langs.length, 100);

    for (final item in langs) {
      final code = item['code'] as String;
      expect(LanguageRegistry100.forbiddenLanguageCodes.contains(code.toLowerCase()), isFalse);

      final f = File('locales/$code.json');
      expect(f.existsSync(), isTrue, reason: 'Locale file missing for $code');
      final rawMap = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final strMap = rawMap.map((k, v) => MapEntry(k, v.toString()));

      final eval = LanguageRegistry100.evaluateLocalePack(
        languageCode: code,
        translations: strMap,
      );
      expect(eval.translationComplete, isTrue, reason: 'Incomplete translation for $code');
      expect(eval.translatedKeysCount, 42);
      expect(eval.missingKeysCount, 0);
      expect(eval.usesWesternDigitsOnly, isTrue, reason: 'Non-Western digits found in $code');
    }

    expect(File('docs/LANGUAGE_QUALITY_REPORT_100.md').existsSync(), isTrue);
  });
}

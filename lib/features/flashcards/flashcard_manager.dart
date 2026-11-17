class CardFieldSpec {
  final String key;
  final String label;
  final bool hidden;
  final int orderIndex;
  final String? languageTag;

  const CardFieldSpec({
    required this.key,
    required this.label,
    this.hidden = false,
    required this.orderIndex,
    this.languageTag,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'hidden': hidden,
        'orderIndex': orderIndex,
        'languageTag': languageTag,
      };
}

/// Normalizes Arabic text (removes harakat/tashkeel, tatweel, and normalizes hamzas)
/// so Arabic diacritic-insensitive search and duplicate detection work reliably.
class FlashcardTextUtils {
  static final RegExp _arabicDiacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]',
  );

  static String normalizeForSearch(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(_arabicDiacritics, '');
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matchesArabicInsensitive(String sourceText, String query) {
    final normSource = normalizeForSearch(sourceText);
    final normQuery = normalizeForSearch(query);
    if (normQuery.isEmpty) return true;
    return normSource.contains(normQuery);
  }

  /// Computes normalized similarity ratio [0.0 .. 1.0] for duplicate & near-duplicate detection.
  static double similarityRatio(String a, String b) {
    final s1 = normalizeForSearch(a);
    final s2 = normalizeForSearch(b);
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final dist = _levenshtein(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    var v0 = List<int>.generate(n + 1, (i) => i);
    var v1 = List<int>.filled(n + 1, 0);

    for (var i = 0; i < m; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < n; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        final del = v0[j + 1] + 1;
        final ins = v1[j] + 1;
        final sub = v0[j] + cost;
        v1[j + 1] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final tmp = v0;
      v0 = v1;
      v1 = tmp;
    }
    return v0[n];
  }
}

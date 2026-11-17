import 'flashcard_manager.dart';
import 'fsrs_engine.dart';

enum StudyModeType {
  standardFlip('flip', 'Standard Flip Review', 'المراجعة القياسية بالقلب'),
  typingDictation('dictation', 'Exact Typing & Dictation', 'وضع الإملاء والكتابة الدقيقة'),
  multipleChoiceQuiz('quiz', '4-Option Speed Quiz', 'اختبار الاختيار من متعدد السريع'),
  leechClinic('leech', 'Difficult & Leech Card Clinic', 'عيادة البطاقات الصعبة والمتعثرة');

  final String id;
  final String titleEn;
  final String titleAr;

  const StudyModeType(this.id, this.titleEn, this.titleAr);
}

class DictationEvaluation {
  final bool exactMatch;
  final bool normalizedMatch;
  final double similarityScore;
  final FsrsRating suggestedRating;

  const DictationEvaluation({
    required this.exactMatch,
    required this.normalizedMatch,
    required this.similarityScore,
    required this.suggestedRating,
  });
}

/// Active Recall, Dictation & Leech Clinic Engine (Stage 12).
/// Evaluates typed user answers with Arabic diacritic-insensitive matching
/// and recommends an objective FSRS-4.5 rating.
class ActiveRecallModesEngine {
  static DictationEvaluation evaluateTypedAnswer({
    required String expectedAnswer,
    required String userTypedAnswer,
  }) {
    final rawExpected = expectedAnswer.trim();
    final rawTyped = userTypedAnswer.trim();

    if (rawTyped.isEmpty) {
      return const DictationEvaluation(
        exactMatch: false,
        normalizedMatch: false,
        similarityScore: 0.0,
        suggestedRating: FsrsRating.again,
      );
    }

    final exact = rawExpected == rawTyped;
    final normExpected = FlashcardTextUtils.normalizeForSearch(rawExpected);
    final normTyped = FlashcardTextUtils.normalizeForSearch(rawTyped);
    final normMatch = normExpected == normTyped;
    final sim = FlashcardTextUtils.similarityRatio(rawExpected, rawTyped);

    final FsrsRating suggested;
    if (exact) {
      suggested = FsrsRating.easy;
    } else if (normMatch || sim >= 0.92) {
      suggested = FsrsRating.good;
    } else if (sim >= 0.75) {
      suggested = FsrsRating.hard;
    } else {
      suggested = FsrsRating.again;
    }

    return DictationEvaluation(
      exactMatch: exact,
      normalizedMatch: normMatch,
      similarityScore: double.parse(sim.toStringAsFixed(3)),
      suggestedRating: suggested,
    );
  }
}

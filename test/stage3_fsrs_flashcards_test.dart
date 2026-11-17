import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/features/flashcards/fsrs_engine.dart';
import 'package:focus_studio_pro/features/flashcards/flashcard_manager.dart';

void main() {
  test('FSRS-4.5 deterministic scheduling across Again, Hard, Good, Easy', () {
    const engine = Fsrs45Engine();
    final t0 = DateTime.utc(2026, 11, 17, 6, 0, 0);
    final initial = FsrsCardState.initial(t0);

    final rGood1 = engine.review(
      current: initial,
      rating: FsrsRating.good,
      reviewedAtUtc: t0,
    );
    expect(rGood1.nextState.phase, FsrsCardPhase.review);
    expect(rGood1.nextState.stability, closeTo(3.7145, 0.001));
    expect(rGood1.scheduledDays, greaterThanOrEqualTo(3.0));

    final t1 = rGood1.nextState.dueUtc;
    final rEasy2 = engine.review(
      current: rGood1.nextState,
      rating: FsrsRating.easy,
      reviewedAtUtc: t1,
    );
    expect(rEasy2.nextState.stability, greaterThan(rGood1.nextState.stability));

    final rAgain3 = engine.review(
      current: rEasy2.nextState,
      rating: FsrsRating.again,
      reviewedAtUtc: rEasy2.nextState.dueUtc,
    );
    expect(rAgain3.nextState.phase, FsrsCardPhase.relearning);
    expect(rAgain3.nextState.lapses, 1);
  });

  test('Arabic diacritic-insensitive search and near-duplicate detection', () {
    expect(
      FlashcardTextUtils.matchesArabicInsensitive('الْعِلْمُ نُورٌ وَالْجَهْلُ ظَلَامٌ', 'العلم نور'),
      isTrue,
    );
    expect(
      FlashcardTextUtils.matchesArabicInsensitive('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', 'الاعمال بالنيات'),
      isTrue,
    );
    expect(
      FlashcardTextUtils.similarityRatio('sich erinnern an', 'sich erinnern an!'),
      greaterThan(0.9),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/features/focus/focus_timer_controller.dart';
import 'package:focus_studio_pro/features/flashcards/fsrs_engine.dart';

void main() {
  group('FocusTimerController critical flows', () {
    test('configureCustom clamps unsafe values', () {
      final timer = FocusTimerController();
      timer.configureCustom(
        sets: 100, // clamp to 20
        workSeconds: 5, // clamp to 30
        restSeconds: 100000, // clamp to 3600
        skipFinalRest: false,
      );
      expect(timer.state.totalSets, 20);
      expect(timer.state.workSeconds, 30);
      expect(timer.state.restSeconds, 3600);
      expect(timer.state.skipFinalRest, isFalse);
    });

    test('tick overshoot on final work with skipFinalRest completes cleanly', () {
      final timer = FocusTimerController();
      timer.configureCustom(sets: 1, workSeconds: 60, restSeconds: 30, skipFinalRest: true);
      timer.start();
      timer.tick(90); // overshoot
      expect(timer.state.isRunning, isFalse);
      expect(timer.state.remainingSeconds, 0);
      expect(timer.state.isRestPhase, isFalse);
    });

    test('skipFinalRest=false enters final rest then completes', () {
      final timer = FocusTimerController();
      timer.configureCustom(sets: 1, workSeconds: 30, restSeconds: 15, skipFinalRest: false);
      timer.start();
      timer.tick(30);
      expect(timer.state.isRestPhase, isTrue);
      expect(timer.state.remainingSeconds, 15);
      timer.tick(15);
      expect(timer.state.isRunning, isFalse);
      expect(timer.state.remainingSeconds, 0);
    });

    test('zero rest seconds advances sets immediately', () {
      final timer = FocusTimerController();
      timer.configureCustom(sets: 2, workSeconds: 20, restSeconds: 0, skipFinalRest: true);
      timer.start();
      timer.tick(20);
      expect(timer.state.currentSet, 2);
      expect(timer.state.isRestPhase, isFalse);
      timer.tick(20);
      expect(timer.state.isRunning, isFalse);
    });
  });

  group('FSRS-4.5 edge cases & leech detection', () {
    const engine = Fsrs45Engine(leechLapseThreshold: 3);

    test('new card Again rating enters learning and increments lapse', () {
      final t0 = DateTime.utc(2026, 11, 23);
      final outcome = engine.review(
        current: FsrsCardState.initial(t0),
        rating: FsrsRating.again,
        reviewedAtUtc: t0,
      );
      expect(outcome.nextState.phase, FsrsCardPhase.learning);
      expect(outcome.nextState.lapses, 1);
      expect(outcome.isLeech, isFalse);
    });

    test('repeated Again ratings eventually mark leech', () {
      var state = FsrsCardState.initial(DateTime.utc(2026, 1, 1));
      var reviewed = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 4; i++) {
        reviewed = reviewed.add(const Duration(days: 1));
        final outcome = engine.review(
          current: state,
          rating: FsrsRating.again,
          reviewedAtUtc: reviewed,
        );
        state = outcome.nextState;
        if (i >= 2) {
          expect(outcome.isLeech, isTrue);
        }
      }
      expect(state.lapses, greaterThanOrEqualTo(3));
    });

    test('very large elapsed days still produces finite stability', () {
      final old = DateTime.utc(2000, 1, 1);
      final state = FsrsCardState(
        phase: FsrsCardPhase.review,
        stability: 10.0,
        difficulty: 5.0,
        reps: 5,
        lapses: 0,
        lastReviewUtc: old,
        dueUtc: old.add(const Duration(days: 30)),
      );
      final outcome = engine.review(
        current: state,
        rating: FsrsRating.good,
        reviewedAtUtc: DateTime.utc(2026, 11, 23),
      );
      expect(outcome.nextState.stability.isFinite, isTrue);
      expect(outcome.nextState.stability, greaterThan(0));
    });
  });
}

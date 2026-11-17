import '../flashcards/fsrs_engine.dart';

class AnalyticsSummary {
  final int recordedFocusMinutes;
  final int completedFocusSessions;
  final int currentStreakDays;
  final int totalCardsReviewed;
  final double averageRetentionPercent;
  final List<int> next30DaysWorkload;
  final Map<String, int> dailyActivityHeatmap;

  const AnalyticsSummary({
    required this.recordedFocusMinutes,
    required this.completedFocusSessions,
    required this.currentStreakDays,
    required this.totalCardsReviewed,
    required this.averageRetentionPercent,
    required this.next30DaysWorkload,
    required this.dailyActivityHeatmap,
  });
}

class AnalyticsEngine {
  /// Computes deterministic 30-day review workload forecast and retention stats
  /// using Western digits (0-9) date keys (`YYYY-MM-DD`).
  static AnalyticsSummary computeSummary({
    required List<FsrsCardState> cardStates,
    required List<int> focusSessionDurationsSeconds,
    required DateTime referenceNowUtc,
  }) {
    final now = referenceNowUtc.toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);

    final workload30 = List<int>.filled(30, 0);
    double totalRetrievability = 0.0;
    int reviewedCardsCount = 0;
    const engine = Fsrs45Engine();

    for (final st in cardStates) {
      if (st.reps > 0 && st.lastReviewUtc != null) {
        reviewedCardsCount += 1;
        final elapsed = now.difference(st.lastReviewUtc!).inSeconds / 86400.0;
        totalRetrievability += engine.computeRetrievability(elapsed, st.stability);
      }
      final dueDay = DateTime.utc(st.dueUtc.year, st.dueUtc.month, st.dueUtc.day);
      final diffDays = dueDay.difference(todayStart).inDays;
      if (diffDays >= 0 && diffDays < 30) {
        workload30[diffDays] += 1;
      } else if (diffDays < 0) {
        workload30[0] += 1; // Overdue cards scheduled for day 0 (today)
      }
    }

    final totalSeconds = focusSessionDurationsSeconds.fold<int>(0, (a, b) => a + b);
    final avgRet = reviewedCardsCount > 0
        ? double.parse(((totalRetrievability / reviewedCardsCount) * 100.0).toStringAsFixed(1))
        : 100.0;

    final dateKey =
        '${todayStart.year.toString().padLeft(4, '0')}-${todayStart.month.toString().padLeft(2, '0')}-${todayStart.day.toString().padLeft(2, '0')}';

    return AnalyticsSummary(
      recordedFocusMinutes: totalSeconds ~/ 60,
      completedFocusSessions: focusSessionDurationsSeconds.length,
      currentStreakDays: (focusSessionDurationsSeconds.isNotEmpty || reviewedCardsCount > 0) ? 1 : 0,
      totalCardsReviewed: reviewedCardsCount,
      averageRetentionPercent: avgRet,
      next30DaysWorkload: workload30,
      dailyActivityHeatmap: {
        dateKey: focusSessionDurationsSeconds.length + reviewedCardsCount,
      },
    );
  }
}

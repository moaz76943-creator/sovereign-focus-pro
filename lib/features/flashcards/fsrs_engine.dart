import 'dart:math' as math;

enum FsrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  final int value;
  const FsrsRating(this.value);

  static FsrsRating fromInt(int v) {
    return FsrsRating.values.firstWhere((e) => e.value == v, orElse: () => FsrsRating.good);
  }
}

enum FsrsCardPhase {
  newCard(0),
  learning(1),
  review(2),
  relearning(3);

  final int code;
  const FsrsCardPhase(this.code);

  static FsrsCardPhase fromCode(int c) {
    return FsrsCardPhase.values.firstWhere((e) => e.code == c, orElse: () => FsrsCardPhase.newCard);
  }
}

class FsrsCardState {
  final FsrsCardPhase phase;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final DateTime? lastReviewUtc;
  final DateTime dueUtc;

  const FsrsCardState({
    required this.phase,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.lastReviewUtc,
    required this.dueUtc,
  });

  factory FsrsCardState.initial(DateTime nowUtc) {
    return FsrsCardState(
      phase: FsrsCardPhase.newCard,
      stability: 0.0,
      difficulty: 0.0,
      reps: 0,
      lapses: 0,
      lastReviewUtc: null,
      dueUtc: nowUtc.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'phase': phase.code,
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'last_review_utc': lastReviewUtc?.toIso8601String(),
        'due_utc': dueUtc.toIso8601String(),
      };

  factory FsrsCardState.fromJson(Map<String, dynamic> json) {
    return FsrsCardState(
      phase: FsrsCardPhase.fromCode((json['phase'] as num?)?.toInt() ?? 0),
      stability: ((json['stability'] as num?) ?? 0.0).toDouble(),
      difficulty: ((json['difficulty'] as num?) ?? 0.0).toDouble(),
      reps: ((json['reps'] as num?) ?? 0).toInt(),
      lapses: ((json['lapses'] as num?) ?? 0).toInt(),
      lastReviewUtc: json['last_review_utc'] != null
          ? DateTime.parse(json['last_review_utc'] as String).toUtc()
          : null,
      dueUtc: DateTime.parse(json['due_utc'] as String).toUtc(),
    );
  }
}

class FsrsReviewOutcome {
  final FsrsCardState nextState;
  final double scheduledDays;
  final double elapsedDays;
  final double retrievability;
  final bool isLeech;

  const FsrsReviewOutcome({
    required this.nextState,
    required this.scheduledDays,
    required this.elapsedDays,
    required this.retrievability,
    required this.isLeech,
  });
}

/// Deterministic FSRS-4.5 (17-parameter power-law forgetting curve) scheduler.
class Fsrs45Engine {
  static const List<double> defaultWeights = [
    0.4872, 1.4003, 3.7145, 13.8206,
    5.1618, 1.2298, 0.8975, 0.031,
    1.6474, 0.1367, 1.0461, 2.1072,
    0.0793, 0.3246, 1.587, 0.2272,
    2.8755,
  ];

  static const double _decay = -0.5;
  static const double _factor = 19.0 / 81.0;

  final List<double> w;
  final double requestRetention;
  final int leechLapseThreshold;

  const Fsrs45Engine({
    this.w = defaultWeights,
    this.requestRetention = 0.9,
    this.leechLapseThreshold = 6,
  });

  double computeRetrievability(double elapsedDays, double stability) {
    if (stability <= 0.0 || elapsedDays <= 0.0) return 1.0;
    return math.pow(1.0 + _factor * (elapsedDays / stability), _decay).toDouble();
  }

  double nextIntervalDays(double stability) {
    if (stability <= 0.0) return 1.0;
    final raw = (stability / _factor) * (math.pow(requestRetention, 1.0 / _decay) - 1.0);
    return math.max(1.0, raw.roundToDouble());
  }

  FsrsReviewOutcome review({
    required FsrsCardState current,
    required FsrsRating rating,
    required DateTime reviewedAtUtc,
  }) {
    final now = reviewedAtUtc.toUtc();
    final elapsedDays = current.lastReviewUtc == null
        ? 0.0
        : math.max(0.0, now.difference(current.lastReviewUtc!).inSeconds / 86400.0);

    final double newStability;
    final double newDifficulty;
    final FsrsCardPhase nextPhase;
    int newLapses = current.lapses;

    if (current.phase == FsrsCardPhase.newCard || current.stability <= 0.0) {
      newStability = w[rating.value - 1];
      newDifficulty = _clampDifficulty(w[4] - w[5] * (rating.value - 3));
      nextPhase = rating == FsrsRating.again ? FsrsCardPhase.learning : FsrsCardPhase.review;
      if (rating == FsrsRating.again) newLapses += 1;
    } else {
      final r = computeRetrievability(elapsedDays, current.stability);
      final d0 = w[4];
      final deltaD = current.difficulty - w[6] * (rating.value - 3);
      newDifficulty = _clampDifficulty(w[7] * d0 + (1.0 - w[7]) * deltaD);

      if (rating == FsrsRating.again) {
        newLapses += 1;
        nextPhase = FsrsCardPhase.relearning;
        final sForget = w[11] *
            math.pow(newDifficulty, -w[12]) *
            (math.pow(current.stability + 1.0, w[13]) - 1.0) *
            math.exp(w[14] * (1.0 - r));
        newStability = math.max(0.1, math.min(current.stability, sForget));
      } else {
        nextPhase = FsrsCardPhase.review;
        final hardPenalty = (rating == FsrsRating.hard) ? w[15] : 1.0;
        final easyBonus = (rating == FsrsRating.easy) ? w[16] : 1.0;
        final inc = math.exp(w[8]) *
            (11.0 - newDifficulty) *
            math.pow(current.stability, -w[9]) *
            (math.exp(w[10] * (1.0 - r)) - 1.0) *
            hardPenalty *
            easyBonus;
        newStability = current.stability * (1.0 + inc);
      }
    }

    final scheduledDays = (rating == FsrsRating.again) ? 0.01 : nextIntervalDays(newStability);
    final dueUtc = now.add(Duration(seconds: (scheduledDays * 86400).round()));
    final retrievability = current.stability > 0
        ? computeRetrievability(elapsedDays, current.stability)
        : 1.0;

    final nextState = FsrsCardState(
      phase: nextPhase,
      stability: double.parse(newStability.toStringAsFixed(4)),
      difficulty: double.parse(newDifficulty.toStringAsFixed(4)),
      reps: current.reps + 1,
      lapses: newLapses,
      lastReviewUtc: now,
      dueUtc: dueUtc,
    );

    return FsrsReviewOutcome(
      nextState: nextState,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
      retrievability: retrievability,
      isLeech: newLapses >= leechLapseThreshold,
    );
  }

  double _clampDifficulty(double d) => math.max(1.0, math.min(10.0, d));
}

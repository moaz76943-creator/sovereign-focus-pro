enum FocusSessionMode {
  pomodoro('pomodoro', 25 * 60, 5 * 60, 4),
  deepWork50('deep50', 50 * 60, 10 * 60, 2),
  quickSprint10('sprint10', 10 * 60, 2 * 60, 4),
  customInterval('custom', 20 * 60, 5 * 60, 4);

  final String id;
  final int defaultWorkSeconds;
  final int defaultRestSeconds;
  final int defaultSets;

  const FocusSessionMode(
    this.id,
    this.defaultWorkSeconds,
    this.defaultRestSeconds,
    this.defaultSets,
  );
}

class FocusTimerState {
  final FocusSessionMode mode;
  final int workSeconds;
  final int restSeconds;
  final int totalSets;
  final int currentSet;
  final int remainingSeconds;
  final bool isRestPhase;
  final bool isRunning;
  final bool skipFinalRest;
  final List<String> exerciseSequence;

  const FocusTimerState({
    required this.mode,
    required this.workSeconds,
    required this.restSeconds,
    required this.totalSets,
    required this.currentSet,
    required this.remainingSeconds,
    required this.isRestPhase,
    required this.isRunning,
    required this.skipFinalRest,
    required this.exerciseSequence,
  });

  factory FocusTimerState.initial() {
    return FocusTimerState(
      mode: FocusSessionMode.pomodoro,
      workSeconds: FocusSessionMode.pomodoro.defaultWorkSeconds,
      restSeconds: FocusSessionMode.pomodoro.defaultRestSeconds,
      totalSets: FocusSessionMode.pomodoro.defaultSets,
      currentSet: 1,
      remainingSeconds: FocusSessionMode.pomodoro.defaultWorkSeconds,
      isRestPhase: false,
      isRunning: false,
      skipFinalRest: true,
      exerciseSequence: const [],
    );
  }

  /// Formats remaining time using Western digits (0-9) strictly (`MM:SS`).
  String get formattedWesternClock {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  FocusTimerState copyWith({
    FocusSessionMode? mode,
    int? workSeconds,
    int? restSeconds,
    int? totalSets,
    int? currentSet,
    int? remainingSeconds,
    bool? isRestPhase,
    bool? isRunning,
    bool? skipFinalRest,
    List<String>? exerciseSequence,
  }) {
    return FocusTimerState(
      mode: mode ?? this.mode,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      totalSets: totalSets ?? this.totalSets,
      currentSet: currentSet ?? this.currentSet,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRestPhase: isRestPhase ?? this.isRestPhase,
      isRunning: isRunning ?? this.isRunning,
      skipFinalRest: skipFinalRest ?? this.skipFinalRest,
      exerciseSequence: exerciseSequence ?? this.exerciseSequence,
    );
  }
}

class FocusTimerController {
  FocusTimerState _state = FocusTimerState.initial();

  FocusTimerState get state => _state;

  void configureCustom({
    required int sets,
    required int workSeconds,
    required int restSeconds,
    bool skipFinalRest = true,
    List<String>? exerciseSequence,
  }) {
    final safeSets = sets.clamp(1, 20);
    final safeWork = workSeconds.clamp(30, 180 * 60);
    final safeRest = restSeconds.clamp(0, 60 * 60);
    _state = _state.copyWith(
      mode: FocusSessionMode.customInterval,
      totalSets: safeSets,
      workSeconds: safeWork,
      restSeconds: safeRest,
      currentSet: 1,
      remainingSeconds: safeWork,
      isRestPhase: false,
      isRunning: false,
      skipFinalRest: skipFinalRest,
      exerciseSequence: exerciseSequence ?? _state.exerciseSequence,
    );
  }

  void start() {
    _state = _state.copyWith(isRunning: true);
  }

  void pause() {
    _state = _state.copyWith(isRunning: false);
  }

  void reset() {
    _state = _state.copyWith(
      currentSet: 1,
      remainingSeconds: _state.workSeconds,
      isRestPhase: false,
      isRunning: false,
    );
  }

  /// Advances the timer deterministically by `elapsedSeconds` and handles
  /// multi-set work/rest transitions and `skipFinalRest`.
  void tick(int elapsedSeconds) {
    if (!_state.isRunning || elapsedSeconds <= 0) return;
    final nextRem = _state.remainingSeconds - elapsedSeconds;
    if (nextRem > 0) {
      _state = _state.copyWith(remainingSeconds: nextRem);
      return;
    }

    if (!_state.isRestPhase) {
      final isFinalSet = _state.currentSet >= _state.totalSets;
      if (isFinalSet && (_state.skipFinalRest || _state.restSeconds == 0)) {
        _state = _state.copyWith(
          remainingSeconds: 0,
          isRunning: false,
        );
      } else if (_state.restSeconds > 0) {
        _state = _state.copyWith(
          isRestPhase: true,
          remainingSeconds: _state.restSeconds,
        );
      } else {
        _state = _state.copyWith(
          currentSet: _state.currentSet + 1,
          remainingSeconds: _state.workSeconds,
        );
      }
    } else {
      if (_state.currentSet >= _state.totalSets) {
        _state = _state.copyWith(
          remainingSeconds: 0,
          isRunning: false,
          isRestPhase: false,
        );
      } else {
        _state = _state.copyWith(
          currentSet: _state.currentSet + 1,
          isRestPhase: false,
          remainingSeconds: _state.workSeconds,
        );
      }
    }
  }
}

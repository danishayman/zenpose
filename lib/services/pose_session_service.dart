import '../models/pose_result.dart';
import '../models/pose_session_config.dart';
import 'pose_hold_service.dart';

/// Manages a single pose attempt session.
///
/// Tracks best score across frames and emits a [PoseResult] once the
/// [PoseHoldService] reports completion. This service is UI-agnostic.
class PoseSessionService {
  final String poseName;
  final PoseSessionConfig sessionConfig;
  final PoseHoldService poseHoldService;

  double _bestScore = 0.0;
  bool _completed = false;
  PoseResult? _lastResult;
  DateTime? _timedStartedAt;
  DateTime? _timedPauseStartedAt;
  Duration _timedPausedAccumulated = Duration.zero;
  Duration _timedElapsed = Duration.zero;
  bool _timedPaused = false;
  double _timedScoreSum = 0.0;
  int _timedScoreSamples = 0;

  PoseSessionService({
    required this.poseName,
    this.sessionConfig = PoseSessionConfig.defaultPractice,
    PoseHoldService? poseHoldService,
  }) : poseHoldService =
           poseHoldService ??
           PoseHoldService(
             scoreThreshold: sessionConfig.scoreThreshold,
             holdDuration: sessionConfig.holdDuration,
           );

  /// Best similarity score achieved so far (0–100).
  double get bestScore => _bestScore;

  /// Latest completed result (if any).
  PoseResult? get lastResult => _lastResult;

  /// Convenience: current hold time in seconds.
  double get holdTimeSeconds =>
      isTimedMode ? timedElapsedSeconds : poseHoldService.holdTimeSeconds;

  /// Convenience: hold progress from 0.0 to 1.0.
  double get holdProgress =>
      isTimedMode ? timedProgress : poseHoldService.holdProgress;

  /// Convenience: whether the hold duration has been completed.
  bool get poseCompleted => isTimedMode ? _completed : poseHoldService.poseCompleted;

  /// Convenience: configured hold duration.
  Duration get holdDuration =>
      isTimedMode ? timedDuration : poseHoldService.holdDuration;

  /// Convenience: configured score threshold for hold.
  double get scoreThreshold => poseHoldService.scoreThreshold;
  PoseSessionMode get mode => sessionConfig.mode;
  Duration get timedDuration => sessionConfig.timedDuration;
  bool get isTimedMode => mode == PoseSessionMode.timed;
  bool get isTimedPaused => _timedPaused;
  bool get isTimedRunning =>
      isTimedMode && _timedStartedAt != null && !_completed && !_timedPaused;
  double get averageScore =>
      _timedScoreSamples == 0 ? 0.0 : _timedScoreSum / _timedScoreSamples;
  double get timedElapsedSeconds =>
      _currentTimedElapsed().inMilliseconds / 1000.0;
  double get timedRemainingSeconds =>
      (timedDuration - _currentTimedElapsed()).inMilliseconds / 1000.0;
  double get timedProgress {
    final totalMs = timedDuration.inMilliseconds;
    if (totalMs <= 0) return 1.0;
    return (_currentTimedElapsed().inMilliseconds / totalMs)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void startTimedSession({DateTime? startedAt}) {
    if (!isTimedMode) return;
    _timedStartedAt = startedAt ?? DateTime.now();
    _timedPauseStartedAt = null;
    _timedPausedAccumulated = Duration.zero;
    _timedElapsed = Duration.zero;
    _timedPaused = false;
    _timedScoreSum = 0.0;
    _timedScoreSamples = 0;
  }

  void pauseTimedSession({DateTime? pausedAt}) {
    if (!isTimedMode || _timedPaused || _timedStartedAt == null || _completed) {
      return;
    }
    _timedPaused = true;
    _timedPauseStartedAt = pausedAt ?? DateTime.now();
  }

  void resumeTimedSession({DateTime? resumedAt}) {
    if (!isTimedMode || !_timedPaused || _timedPauseStartedAt == null) return;
    final at = resumedAt ?? DateTime.now();
    if (at.isAfter(_timedPauseStartedAt!)) {
      _timedPausedAccumulated += at.difference(_timedPauseStartedAt!);
    }
    _timedPauseStartedAt = null;
    _timedPaused = false;
  }

  PoseResult? finalizeTimedSession({DateTime? timestamp}) {
    if (!isTimedMode || _completed || _timedStartedAt == null) {
      return null;
    }
    final now = timestamp ?? DateTime.now();
    _timedElapsed = _currentTimedElapsed(now: now);
    _completed = true;
    _lastResult = PoseResult(
      poseName: poseName,
      bestScore: averageScore,
      holdDuration: _timedElapsed.inMilliseconds / 1000.0,
      completed: true,
      timestamp: now,
    );
    return _lastResult;
  }

  /// Update session state and return a [PoseResult] when completed.
  ///
  /// [currentScore] should be the **smoothed** similarity score.
  PoseResult? update(
    double currentScore, {
    bool poseStable = true,
    DateTime? timestamp,
  }) {
    if (_completed) {
      return null;
    }

    if (isTimedMode) {
      if (_timedStartedAt == null) {
        startTimedSession(startedAt: timestamp);
      }
      if (_timedPaused) {
        return null;
      }
      _timedElapsed = _currentTimedElapsed(now: timestamp);
      _timedScoreSum += currentScore;
      _timedScoreSamples += 1;
      if (currentScore > _bestScore) {
        _bestScore = currentScore;
      }
      if (_timedElapsed >= timedDuration) {
        return finalizeTimedSession(timestamp: timestamp);
      }
      return null;
    }

    final now = timestamp ?? DateTime.now();

    if (currentScore > _bestScore) {
      _bestScore = currentScore;
    }

    poseHoldService.update(
      currentScore,
      poseStable: poseStable,
      timestamp: now,
    );

    if (poseHoldService.poseCompleted) {
      _completed = true;
      _lastResult = PoseResult(
        poseName: poseName,
        bestScore: _bestScore,
        holdDuration: poseHoldService.holdTimeSeconds,
        completed: true,
        timestamp: now,
      );
      return _lastResult;
    }

    return null;
  }

  /// Reset session state and clear any completed result.
  void reset() {
    _bestScore = 0.0;
    _completed = false;
    _lastResult = null;
    _timedStartedAt = null;
    _timedPauseStartedAt = null;
    _timedPausedAccumulated = Duration.zero;
    _timedElapsed = Duration.zero;
    _timedPaused = false;
    _timedScoreSum = 0.0;
    _timedScoreSamples = 0;
    poseHoldService.reset();
  }

  Duration _currentTimedElapsed({DateTime? now}) {
    if (_timedStartedAt == null) return Duration.zero;
    if (_timedElapsed >= timedDuration) return timedDuration;

    final at = now ?? DateTime.now();
    DateTime effectiveNow = at;
    if (_timedPaused && _timedPauseStartedAt != null) {
      effectiveNow = _timedPauseStartedAt!;
    }
    if (effectiveNow.isBefore(_timedStartedAt!)) {
      return Duration.zero;
    }
    final active = effectiveNow
            .difference(_timedStartedAt!)
            .inMilliseconds -
        _timedPausedAccumulated.inMilliseconds;
    if (active <= 0) return Duration.zero;
    final elapsed = Duration(milliseconds: active);
    if (elapsed > timedDuration) return timedDuration;
    return elapsed;
  }
}

/// Tracks how long the user continuously holds a pose above a score threshold.
///
/// The service is designed to be reused across screens and does not depend on
/// Flutter. Call [update] on every frame with the **smoothed** similarity score.
class PoseHoldService {
  /// Minimum similarity score required to count towards the hold timer.
  final double scoreThreshold;

  /// Duration the pose must be held to be considered completed.
  final Duration holdDuration;

  /// Maximum time step applied per update to keep progress smooth.
  ///
  /// Large frame gaps (app pause, GC, etc.) can create sudden jumps in the
  /// progress bar; clamping keeps the UI stable and predictable.
  final Duration maxDelta;

  DateTime? _lastUpdateTime;
  double _holdSeconds = 0.0;
  bool _poseCompleted = false;

  PoseHoldService({
    this.scoreThreshold = 60.0,
    this.holdDuration = const Duration(seconds: 5),
    this.maxDelta = const Duration(milliseconds: 500),
  });

  /// Current hold time in seconds.
  double get holdTimeSeconds => _holdSeconds;

  /// Progress from 0.0 to 1.0.
  double get holdProgress =>
      _holdDurationSeconds <= 0.0
          ? 0.0
          : (_holdSeconds / _holdDurationSeconds)
              .clamp(0.0, 1.0)
              .toDouble();

  /// Whether the user has successfully held the pose long enough.
  bool get poseCompleted => _poseCompleted;

  /// Update the hold timer with the latest [smoothedScore].
  ///
  /// The timer only progresses when:
  /// - [smoothedScore] ≥ [scoreThreshold]
  /// - [poseStable] is true
  ///
  /// Otherwise, the timer resets instantly.
  void update(
    double smoothedScore, {
    bool poseStable = true,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    if (smoothedScore >= scoreThreshold && poseStable) {
      if (_lastUpdateTime == null) {
        _lastUpdateTime = now;
        _poseCompleted = _holdSeconds >= _holdDurationSeconds;
        return;
      }

      final dt = now.difference(_lastUpdateTime!).inMicroseconds / 1e6;
      final maxDt = maxDelta.inMicroseconds / 1e6;
      final safeDt = dt.clamp(0.0, maxDt).toDouble();
      _holdSeconds += safeDt;
      _lastUpdateTime = now;

      if (_holdSeconds >= _holdDurationSeconds) {
        _holdSeconds = _holdDurationSeconds;
        _poseCompleted = true;
      } else {
        _poseCompleted = false;
      }
    } else {
      reset();
    }
  }

  /// Reset the timer and completion state.
  void reset() {
    _lastUpdateTime = null;
    _holdSeconds = 0.0;
    _poseCompleted = false;
  }

  double get _holdDurationSeconds => holdDuration.inMicroseconds / 1e6;
}

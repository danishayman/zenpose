import '../models/pose_result.dart';
import '../models/pose_session_config.dart';
import 'pose_hold_service.dart';

/// Manages a single pose attempt session.
///
/// Tracks best score across frames and emits a [PoseResult] once the
/// [PoseHoldService] reports completion. This service is UI-agnostic.
class PoseSessionService {
  final String poseName;
  final PoseHoldService poseHoldService;

  double _bestScore = 0.0;
  bool _completed = false;
  PoseResult? _lastResult;

  PoseSessionService({
    required this.poseName,
    PoseSessionConfig sessionConfig = PoseSessionConfig.defaultPractice,
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
  double get holdTimeSeconds => poseHoldService.holdTimeSeconds;

  /// Convenience: hold progress from 0.0 to 1.0.
  double get holdProgress => poseHoldService.holdProgress;

  /// Convenience: whether the hold duration has been completed.
  bool get poseCompleted => poseHoldService.poseCompleted;

  /// Convenience: configured hold duration.
  Duration get holdDuration => poseHoldService.holdDuration;

  /// Convenience: configured score threshold for hold.
  double get scoreThreshold => poseHoldService.scoreThreshold;

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
    poseHoldService.reset();
  }
}

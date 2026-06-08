import '../models/pose_session_config.dart';

class PoseHoldEligibilityService {
  const PoseHoldEligibilityService();

  bool poseStableForHold({
    required PoseSessionMode mode,
    required bool poseStable,
    required double score,
    required double scoreThreshold,
  }) {
    if (mode == PoseSessionMode.timed) return poseStable;
    return poseStable || score >= scoreThreshold;
  }
}

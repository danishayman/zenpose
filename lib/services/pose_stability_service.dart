import 'dart:math' as math;

import '../models/pose_landmark_model.dart';

/// Result container for pose stability evaluation.
class PoseStabilityResult {
  /// True when the average inter-frame movement is below the threshold.
  final bool poseStable;

  /// Average movement across key joints (normalized units).
  final double movementScore;

  const PoseStabilityResult({
    required this.poseStable,
    required this.movementScore,
  });
}

/// PoseStabilityService detects whether the user's body is stable
/// between consecutive frames.
///
/// It compares the **average inter-frame movement** of key joints and
/// reports stability when the average movement is below
/// [stabilityThreshold].
///
/// The movement is computed in a **torso-normalized coordinate space**
/// (translation + scale invariant) so the threshold is consistent across
/// users and camera distances.
class PoseStabilityService {
  /// Joints used for stability checks (BlazePose indices).
  ///
  /// Order: L Shoulder, R Shoulder, L Elbow, R Elbow, L Wrist, R Wrist,
  ///        L Hip, R Hip, L Knee, R Knee, L Ankle, R Ankle.
  static const List<int> _keyJointIndices = [
    11,
    12,
    13,
    14,
    15,
    16,
    23,
    24,
    25,
    26,
    27,
    28,
  ];

  /// Default stability threshold for the average movement score.
  static const double defaultStabilityThreshold = 0.01;

  /// Minimum torso length to consider the pose reliable.
  static const double _minTorsoLength = 1e-6;

  /// Threshold below which the pose is considered stable.
  final double stabilityThreshold;

  List<PoseLandmark>? _previousLandmarks;

  PoseStabilityService({this.stabilityThreshold = defaultStabilityThreshold});

  /// Evaluate stability between the current frame and the previous one.
  ///
  /// Stores [currentLandmarks] internally so the next call can compare
  /// against it.
  PoseStabilityResult update(List<PoseLandmark> currentLandmarks) {
    final previousLandmarks = _previousLandmarks;
    _previousLandmarks = currentLandmarks;

    if (previousLandmarks == null) {
      return const PoseStabilityResult(poseStable: false, movementScore: 0.0);
    }

    return evaluate(currentLandmarks, previousLandmarks);
  }

  /// Compute stability between two landmark frames.
  PoseStabilityResult evaluate(
    List<PoseLandmark> currentLandmarks,
    List<PoseLandmark> previousLandmarks,
  ) {
    final currentNorm = _buildNormalizationData(currentLandmarks);
    final previousNorm = _buildNormalizationData(previousLandmarks);

    if (currentNorm == null || previousNorm == null) {
      return const PoseStabilityResult(poseStable: false, movementScore: 0.0);
    }

    double totalMovement = 0.0;
    int validCount = 0;

    for (final idx in _keyJointIndices) {
      if (idx >= currentLandmarks.length || idx >= previousLandmarks.length) {
        continue;
      }

      final current = currentLandmarks[idx];
      final previous = previousLandmarks[idx];

      if (!current.isValid || !previous.isValid) continue;

      final currentX = (current.x - currentNorm.hipCenterX) /
          currentNorm.torsoLength;
      final currentY = (current.y - currentNorm.hipCenterY) /
          currentNorm.torsoLength;

      final previousX = (previous.x - previousNorm.hipCenterX) /
          previousNorm.torsoLength;
      final previousY = (previous.y - previousNorm.hipCenterY) /
          previousNorm.torsoLength;

      final dx = currentX - previousX;
      final dy = currentY - previousY;
      totalMovement += math.sqrt(dx * dx + dy * dy);
      validCount++;
    }

    if (validCount == 0) {
      return const PoseStabilityResult(poseStable: false, movementScore: 0.0);
    }

    final averageMovement = totalMovement / validCount;
    final isStable = averageMovement < stabilityThreshold;

    return PoseStabilityResult(
      poseStable: isStable,
      movementScore: averageMovement,
    );
  }

  /// Clear the internal previous-frame cache.
  void reset() {
    _previousLandmarks = null;
  }

  _NormalizationData? _buildNormalizationData(List<PoseLandmark> landmarks) {
    if (landmarks.length < 25) return null;

    final leftHip = landmarks[23];
    final rightHip = landmarks[24];
    final leftShoulder = landmarks[11];
    final rightShoulder = landmarks[12];

    if (!leftHip.isValid ||
        !rightHip.isValid ||
        !leftShoulder.isValid ||
        !rightShoulder.isValid) {
      return null;
    }

    final hipCenterX = (leftHip.x + rightHip.x) / 2.0;
    final hipCenterY = (leftHip.y + rightHip.y) / 2.0;

    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2.0;

    final dx = shoulderCenterX - hipCenterX;
    final dy = shoulderCenterY - hipCenterY;
    final torsoLength = math.sqrt(dx * dx + dy * dy);

    if (torsoLength < _minTorsoLength) return null;

    return _NormalizationData(
      hipCenterX: hipCenterX,
      hipCenterY: hipCenterY,
      torsoLength: torsoLength,
    );
  }
}

class _NormalizationData {
  final double hipCenterX;
  final double hipCenterY;
  final double torsoLength;

  const _NormalizationData({
    required this.hipCenterX,
    required this.hipCenterY,
    required this.torsoLength,
  });
}

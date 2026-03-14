import 'pose_normalization_service.dart';

/// PoseMirrorService provides utilities for mirroring normalized pose vectors.
///
/// The pose vector layout is defined by [PoseNormalizationService] and follows
/// left/right joint pairs. Mirroring swaps left/right joints and flips the X
/// axis to represent the opposite side of the pose.
class PoseMirrorService {
  /// Mirror a 24-element normalized pose vector across the vertical axis.
  ///
  /// Returns the original vector if the length is unexpected.
  static List<double> mirrorVector(List<double> vector) {
    if (vector.length != PoseNormalizationService.vectorLength) {
      return vector;
    }

    final mirrored = List<double>.filled(vector.length, 0.0);

    // Each entry is the X index of a left/right joint pair.
    const pairs = <(int, int)>[
      (0, 2), // L Shoulder <-> R Shoulder
      (4, 6), // L Elbow <-> R Elbow
      (8, 10), // L Wrist <-> R Wrist
      (12, 14), // L Hip <-> R Hip
      (16, 18), // L Knee <-> R Knee
      (20, 22), // L Ankle <-> R Ankle
    ];

    for (final (leftX, rightX) in pairs) {
      mirrored[leftX] = -vector[rightX];
      mirrored[leftX + 1] = vector[rightX + 1];
      mirrored[rightX] = -vector[leftX];
      mirrored[rightX + 1] = vector[leftX + 1];
    }

    return mirrored;
  }
}

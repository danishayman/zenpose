import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'pose_landmark_model.dart';

/// A single frame of pose data, containing all 33 landmarks and a timestamp.
///
/// [PoseFrame] acts as the canonical input for downstream processing
/// (angle calculation, future cosine similarity scoring) and is intentionally
/// decoupled from ML Kit types.
class PoseFrame {
  /// The 33 BlazePose landmarks, indexed by [mlkit.PoseLandmarkType.index].
  ///
  /// Index mapping follows the standard BlazePose topology:
  ///  0  – nose              11 – left shoulder     23 – left knee
  ///  1  – left eye inner    12 – right shoulder    24 – right knee
  ///  2  – left eye          13 – left elbow        25 – left ankle
  ///  3  – left eye outer    14 – right elbow       26 – right ankle
  ///  4  – right eye inner   15 – left wrist        27 – left heel
  ///  5  – right eye         16 – right wrist       28 – right heel
  ///  6  – right eye outer   17 – left pinky        29 – left foot index
  ///  7  – left ear          18 – right pinky       30 – right foot index
  ///  8  – right ear         19 – left index        31 – left toe
  ///  9  – mouth left        20 – right index       32 – right toe
  /// 10  – mouth right       21 – left thumb
  ///                         22 – right thumb
  final List<PoseLandmark> landmarks;

  /// When this frame was captured.
  final DateTime timestamp;

  const PoseFrame({required this.landmarks, required this.timestamp});

  /// Factory: build a [PoseFrame] from an ML Kit [mlkit.Pose].
  ///
  /// Iterates over the 33 [mlkit.PoseLandmarkType] values in index order
  /// and converts each to our app-owned [PoseLandmark].  If a landmark is
  /// missing from the ML Kit result, a zero-confidence placeholder is used.
  factory PoseFrame.fromMLKitPose(mlkit.Pose pose) {
    // ML Kit exposes landmarks as a Map<PoseLandmarkType, PoseLandmark>.
    // We convert to a fixed-length list indexed by the enum's index value.
    final landmarks = List<PoseLandmark>.generate(
      mlkit.PoseLandmarkType.values.length,
      (i) {
        final type = mlkit.PoseLandmarkType.values[i];
        final mlLandmark = pose.landmarks[type];
        if (mlLandmark != null) {
          return PoseLandmark.fromMLKitLandmark(mlLandmark);
        }
        // Placeholder for missing landmarks – zero confidence ensures
        // downstream code skips them.
        return const PoseLandmark(x: 0, y: 0, z: 0, confidence: 0);
      },
    );

    return PoseFrame(landmarks: landmarks, timestamp: DateTime.now());
  }

  /// Convenience: retrieve a landmark by its ML Kit type enum.
  PoseLandmark landmarkAt(mlkit.PoseLandmarkType type) => landmarks[type.index];
}

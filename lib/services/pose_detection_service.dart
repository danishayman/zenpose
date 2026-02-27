import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// PoseDetectionService wraps Google ML Kit's on-device PoseDetector.
///
/// It accepts an [InputImage] and returns a list of detected [Pose] objects,
/// each containing 33 [PoseLandmark]s (x, y, likelihood).
///
/// This service is intentionally modular: future extensions (cosine similarity,
/// angle calculations) can consume the same landmark list without modifying
/// this class.
class PoseDetectionService {
  late final PoseDetector _poseDetector;

  PoseDetectionService() {
    // Use the streaming (fast) model for real-time detection.
    // PoseDetectionModel.base gives 33 BlazePose landmarks.
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );
    _poseDetector = PoseDetector(options: options);
  }

  /// Detect poses in the given [inputImage].
  ///
  /// Returns a list of [Pose] objects. Typically one pose is detected
  /// (single-person mode). Each pose contains 33 landmarks with
  /// (x, y, likelihood) values in image-space coordinates.
  Future<List<Pose>> detectPose(InputImage inputImage) async {
    try {
      return await _poseDetector.processImage(inputImage);
    } catch (e) {
      // Swallow detection errors to avoid crashing the stream.
      // In production, consider logging these.
      return [];
    }
  }

  /// Clean up the pose detector to free native resources.
  Future<void> dispose() async {
    await _poseDetector.close();
  }
}

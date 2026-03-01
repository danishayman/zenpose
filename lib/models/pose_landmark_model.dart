import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

/// App-owned landmark model, decoupled from ML Kit.
///
/// Each instance holds the normalised position (x, y, z) in image-space
/// coordinates and a [confidence] score (0.0 – 1.0) from the detector.
///
/// By owning this model we avoid leaking the ML Kit dependency into the
/// angle-calculation and (future) pose-scoring layers.
class PoseLandmark {
  /// Horizontal position in image-space pixels.
  final double x;

  /// Vertical position in image-space pixels.
  final double y;

  /// Depth estimate (relative, not absolute metres).
  final double z;

  /// Detection confidence for this landmark (0.0 – 1.0).
  final double confidence;

  const PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  /// Minimum confidence threshold to consider a landmark reliable.
  static const double confidenceThreshold = 0.5;

  /// Whether this landmark is reliable enough for angle calculations.
  bool get isValid => confidence >= confidenceThreshold;

  /// Factory: convert an ML Kit [mlkit.PoseLandmark] into our own model.
  factory PoseLandmark.fromMLKitLandmark(mlkit.PoseLandmark landmark) {
    return PoseLandmark(
      x: landmark.x,
      y: landmark.y,
      z: landmark.z,
      confidence: landmark.likelihood,
    );
  }

  /// Create a copy with optionally updated fields.
  PoseLandmark copyWith({double? x, double? y, double? z, double? confidence}) {
    return PoseLandmark(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() =>
      'PoseLandmark(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
      'z: ${z.toStringAsFixed(1)}, conf: ${confidence.toStringAsFixed(2)})';
}

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';

/// SkeletonPainter draws pose landmarks and bone connections on a [CustomPaint]
/// widget that overlays the camera preview.
///
/// It translates landmark coordinates from the ML Kit image-space into
/// screen-space, accounting for image resolution, preview aspect ratio,
/// and front/back camera mirroring.
class SkeletonPainter extends CustomPainter {
  /// Detected poses (usually one for single-person detection).
  final List<Pose> poses;

  /// Size of the camera image fed to ML Kit (in portrait orientation,
  /// i.e. width < height).
  final Size imageSize;

  /// The camera lens direction (used for optional mirroring).
  final CameraLensDirection lensDirection;

  /// Rotation value from the camera sensor.
  final InputImageRotation rotation;

  /// Minimum landmark confidence to draw (0.0 – 1.0).
  static const double _minConfidence = 0.5;

  SkeletonPainter({
    required this.poses,
    required this.imageSize,
    required this.lensDirection,
    required this.rotation,
  });

  // ── Paint styles ──────────────────────────────────────────────────────────

  /// Joint dot paint (green filled circles).
  static final Paint _jointPaint = Paint()
    ..color = const Color(0xFF00FF00)
    ..style = PaintingStyle.fill;

  /// Bone line paint (cyan lines).
  static final Paint _bonePaint = Paint()
    ..color = const Color(0xFF00FFFF)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  // ── Bone connections ──────────────────────────────────────────────────────

  /// Pairs of [PoseLandmarkType]s that should be connected by lines.
  static const List<(PoseLandmarkType, PoseLandmarkType)> _boneConnections = [
    // Arms – left
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    // Arms – right
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    // Legs – left
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    // Legs – right
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    // Cross connections
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    // Torso
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  ];

  // ── Coordinate translation ────────────────────────────────────────────────

  /// Translate a landmark's (x,y) from image-space to canvas (screen) space.
  ///
  /// Because the CustomPaint overlay is now constrained to the exact same
  /// AspectRatio as the camera preview, we can use a simple uniform scale.
  /// The image aspect ratio matches the canvas aspect ratio, so scaleX ≈ scaleY
  /// and no center-crop offset is needed.
  Offset _translatePoint(double x, double y, Size canvasSize) {
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;

    double translatedX = x * scaleX;
    double translatedY = y * scaleY;

    // Mirror for front camera.
    if (lensDirection == CameraLensDirection.front) {
      translatedX = canvasSize.width - translatedX;
    }

    return Offset(translatedX, translatedY);
  }

  // ── Paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      // Draw bone connections first (behind joints).
      for (final connection in _boneConnections) {
        final from = pose.landmarks[connection.$1];
        final to = pose.landmarks[connection.$2];
        if (from != null &&
            to != null &&
            from.likelihood >= _minConfidence &&
            to.likelihood >= _minConfidence) {
          canvas.drawLine(
            _translatePoint(from.x, from.y, size),
            _translatePoint(to.x, to.y, size),
            _bonePaint,
          );
        }
      }

      // Draw joints on top (only high-confidence ones).
      for (final landmark in pose.landmarks.values) {
        if (landmark.likelihood >= _minConfidence) {
          final point = _translatePoint(landmark.x, landmark.y, size);
          canvas.drawCircle(point, 4.0, _jointPaint);
        }
      }
    }
  }

  /// Repaint when pose data changes.
  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      !identical(oldDelegate.poses, poses);
}

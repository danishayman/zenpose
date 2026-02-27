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

  /// Size of the camera image fed to ML Kit.
  final Size imageSize;

  /// The camera lens direction (used for optional mirroring).
  final CameraLensDirection lensDirection;

  /// Rotation value from the camera sensor.
  final InputImageRotation rotation;

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
  /// The camera image and the preview widget typically have different sizes.
  /// We compute scale factors for both axes and apply them. For a front camera
  /// the x-axis is mirrored.
  Offset _translatePoint(double x, double y, Size canvasSize) {
    // The image dimensions might be rotated (landscape sensor → portrait display).
    // After rotation adjustment, imageSize already matches the portrait orientation
    // because we pass width/height from CameraImage which reports the raw sensor dims.
    // ML Kit returns coordinates already rotated, so we just need to scale.
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;

    // Use the larger scale to fill the preview (center-crop style).
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    // Offset to center the scaled image in the canvas.
    final double offsetX = (canvasSize.width - imageSize.width * scale) / 2;
    final double offsetY = (canvasSize.height - imageSize.height * scale) / 2;

    double translatedX = x * scale + offsetX;
    double translatedY = y * scale + offsetY;

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
        if (from != null && to != null) {
          canvas.drawLine(
            _translatePoint(from.x, from.y, size),
            _translatePoint(to.x, to.y, size),
            _bonePaint,
          );
        }
      }

      // Draw joints on top.
      for (final landmark in pose.landmarks.values) {
        final point = _translatePoint(landmark.x, landmark.y, size);
        canvas.drawCircle(point, 6.0, _jointPaint);
      }
    }
  }

  /// Always repaint – we receive new pose data every frame.
  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) => true;
}

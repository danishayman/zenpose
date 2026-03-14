import 'package:flutter/material.dart';

import '../models/landmark.dart';

/// SkeletonOverlayPainter draws key pose joints and bones on top of a camera
/// preview using **normalized** landmark coordinates (0–1).
///
/// This is optimized for MediaPipe/BlazePose landmark ordering.
class SkeletonOverlayPainter extends CustomPainter {
  /// Normalized landmarks (0–1). Index order must follow MediaPipe/BlazePose.
  final List<Landmark> landmarks;

  /// Optional similarity score (0–100). Drives joint color.
  final double? similarityScore;

  /// Whether to mirror horizontally (useful for front camera preview).
  final bool mirror;

  SkeletonOverlayPainter({
    required this.landmarks,
    this.similarityScore,
    this.mirror = false,
  });

  // ── MediaPipe landmark indices ──────────────────────────────────────────
  static const int _leftShoulder = 11;
  static const int _rightShoulder = 12;
  static const int _leftElbow = 13;
  static const int _rightElbow = 14;
  static const int _leftWrist = 15;
  static const int _rightWrist = 16;
  static const int _leftHip = 23;
  static const int _rightHip = 24;
  static const int _leftKnee = 25;
  static const int _rightKnee = 26;
  static const int _leftAnkle = 27;
  static const int _rightAnkle = 28;

  /// Key joints to draw (shoulders, elbows, wrists, hips, knees, ankles).
  static const List<int> _jointIndices = [
    _leftShoulder,
    _rightShoulder,
    _leftElbow,
    _rightElbow,
    _leftWrist,
    _rightWrist,
    _leftHip,
    _rightHip,
    _leftKnee,
    _rightKnee,
    _leftAnkle,
    _rightAnkle,
  ];

  /// Bone connections (pairs of landmark indices).
  static const List<(int, int)> _boneConnections = [
    // Arms – left
    (_leftShoulder, _leftElbow),
    (_leftElbow, _leftWrist),
    // Arms – right
    (_rightShoulder, _rightElbow),
    (_rightElbow, _rightWrist),
    // Legs – left
    (_leftHip, _leftKnee),
    (_leftKnee, _leftAnkle),
    // Legs – right
    (_rightHip, _rightKnee),
    (_rightKnee, _rightAnkle),
    // Shoulder ↔ shoulder
    (_leftShoulder, _rightShoulder),
    // Hip ↔ hip
    (_leftHip, _rightHip),
    // Shoulder ↔ hip (torso)
    (_leftShoulder, _leftHip),
    (_rightShoulder, _rightHip),
  ];

  // ── Paint styles ────────────────────────────────────────────────────────

  static const double _jointRadius = 4.0;
  static const double _boneStrokeWidth = 3.0;
  static const double _greenThreshold = 85.0;
  static const double _yellowThreshold = 70.0;

  final Paint _jointPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bonePaint = Paint()
    ..color = const Color(0xFF00FFFF)
    ..strokeWidth = _boneStrokeWidth
    ..style = PaintingStyle.stroke;

  // ── Helpers ─────────────────────────────────────────────────────────────

  Color _jointColorForScore(double? score) {
    if (score == null) return const Color(0xFF00FF00);
    if (score >= _greenThreshold) return const Color(0xFF00FF00); // green
    if (score >= _yellowThreshold) return const Color(0xFFFFFF00); // yellow
    return const Color(0xFFFF3B30); // red
  }

  Offset? _toScreen(Landmark lm, Size size) {
    if (!lm.isValid) return null;

    final double nx = lm.x.clamp(0.0, 1.0);
    final double ny = lm.y.clamp(0.0, 1.0);

    double x = nx * size.width;
    final double y = ny * size.height;

    if (mirror) {
      x = size.width - x;
    }

    return Offset(x, y);
  }

  // ── Paint ───────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    _jointPaint.color = _jointColorForScore(similarityScore);

    // Precompute the required joint offsets once.
    final points = <int, Offset>{};
    for (final idx in _jointIndices) {
      if (idx < 0 || idx >= landmarks.length) continue;
      final offset = _toScreen(landmarks[idx], size);
      if (offset != null) {
        points[idx] = offset;
      }
    }

    // Draw bones first (behind joints).
    for (final connection in _boneConnections) {
      final from = points[connection.$1];
      final to = points[connection.$2];
      if (from != null && to != null) {
        canvas.drawLine(from, to, _bonePaint);
      }
    }

    // Draw joints on top.
    for (final idx in _jointIndices) {
      final point = points[idx];
      if (point != null) {
        canvas.drawCircle(point, _jointRadius, _jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonOverlayPainter oldDelegate) =>
      !identical(oldDelegate.landmarks, landmarks) ||
      oldDelegate.similarityScore != similarityScore ||
      oldDelegate.mirror != mirror;
}

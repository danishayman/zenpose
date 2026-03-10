import 'dart:math' as math;

import '../models/pose_landmark_model.dart';

/// AngleCalculationService computes joint angles from a list of [PoseLandmark]s.
///
/// This is a pure computation class with **no Flutter/UI dependency**, making
/// it easily testable and reusable for future features such as cosine
/// similarity scoring against reference poses.
///
/// ## Supported joints
///
/// | Key            | Points A → B → C (vertex at B)     |
/// |----------------|-------------------------------------|
/// | leftElbow      | Left Shoulder → Elbow → Wrist      |
/// | rightElbow     | Right Shoulder → Elbow → Wrist     |
/// | leftKnee       | Left Hip → Knee → Ankle            |
/// | rightKnee      | Right Hip → Knee → Ankle           |
/// | leftShoulder   | Left Elbow → Shoulder → Hip        |
/// | rightShoulder  | Right Elbow → Shoulder → Hip       |
///
/// ## Vector math
///
/// Given three points A, B, C the angle at vertex B is:
///
/// ```
///   BA = A - B
///   BC = C - B
///   cos(θ) = (BA · BC) / (|BA| × |BC|)
///   θ = acos( clamp(cos(θ), -1, 1) ) × 180 / π
/// ```
class AngleCalculationService {
  /// Definition of a joint as three landmark indices (A, B, C).
  /// The angle is measured at point B (the vertex).
  static const Map<String, (int, int, int)> _jointDefinitions = {
    // ── Arms ────────────────────────────────────────────────────────────────
    // Left Elbow: angle between upper arm and forearm
    'leftElbow': (
      11, // A  – left shoulder  (mlkit.PoseLandmarkType.leftShoulder)
      13, // B  – left elbow     (mlkit.PoseLandmarkType.leftElbow)
      15, // C  – left wrist     (mlkit.PoseLandmarkType.leftWrist)
    ),
    // Right Elbow: angle between upper arm and forearm
    'rightElbow': (
      12, // A  – right shoulder (mlkit.PoseLandmarkType.rightShoulder)
      14, // B  – right elbow    (mlkit.PoseLandmarkType.rightElbow)
      16, // C  – right wrist    (mlkit.PoseLandmarkType.rightWrist)
    ),

    // ── Legs ────────────────────────────────────────────────────────────────
    // Left Knee: angle between thigh and shin
    'leftKnee': (
      23, // A  – left hip   (mlkit.PoseLandmarkType.leftHip)
      25, // B  – left knee  (mlkit.PoseLandmarkType.leftKnee)
      27, // C  – left ankle (mlkit.PoseLandmarkType.leftAnkle)
    ),
    // Right Knee: angle between thigh and shin
    'rightKnee': (
      24, // A  – right hip   (mlkit.PoseLandmarkType.rightHip)
      26, // B  – right knee  (mlkit.PoseLandmarkType.rightKnee)
      28, // C  – right ankle (mlkit.PoseLandmarkType.rightAnkle)
    ),

    // ── Shoulders ───────────────────────────────────────────────────────────
    // Left Shoulder: angle between upper arm and torso
    'leftShoulder': (
      13, // A  – left elbow    (mlkit.PoseLandmarkType.leftElbow)
      11, // B  – left shoulder (mlkit.PoseLandmarkType.leftShoulder)
      23, // C  – left hip      (mlkit.PoseLandmarkType.leftHip)
    ),
    // Right Shoulder: angle between upper arm and torso
    'rightShoulder': (
      14, // A  – right elbow    (mlkit.PoseLandmarkType.rightElbow)
      12, // B  – right shoulder (mlkit.PoseLandmarkType.rightShoulder)
      24, // C  – right hip      (mlkit.PoseLandmarkType.rightHip)
    ),

    // ── Hips ────────────────────────────────────────────────────────────────
    // Left Hip: angle between torso and thigh
    'leftHip': (
      11, // A  – left shoulder (mlkit.PoseLandmarkType.leftShoulder)
      23, // B  – left hip      (mlkit.PoseLandmarkType.leftHip)
      25, // C  – left knee     (mlkit.PoseLandmarkType.leftKnee)
    ),
    // Right Hip: angle between torso and thigh
    'rightHip': (
      12, // A  – right shoulder (mlkit.PoseLandmarkType.rightShoulder)
      24, // B  – right hip      (mlkit.PoseLandmarkType.rightHip)
      26, // C  – right knee     (mlkit.PoseLandmarkType.rightKnee)
    ),
  };

  /// Compute all available joint angles from a frame's landmarks.
  ///
  /// Returns a `Map<String, double>` where keys match the joint names above
  /// and values are angles in **degrees** (0–180).
  ///
  /// Joints whose constituent landmarks have low confidence (below
  /// [PoseLandmark.confidenceThreshold]) are silently omitted from the map.
  Map<String, double> calculateAngles(List<PoseLandmark> landmarks) {
    final angles = <String, double>{};

    for (final entry in _jointDefinitions.entries) {
      final name = entry.key;
      final (idxA, idxB, idxC) = entry.value;

      // ── Safety: bounds check ──────────────────────────────────────────
      if (idxA >= landmarks.length ||
          idxB >= landmarks.length ||
          idxC >= landmarks.length) {
        continue;
      }

      final a = landmarks[idxA];
      final b = landmarks[idxB];
      final c = landmarks[idxC];

      // ── Safety: confidence check ──────────────────────────────────────
      if (!a.isValid || !b.isValid || !c.isValid) continue;

      // ── Compute angle at vertex B ─────────────────────────────────────
      final angle = _angleBetweenPoints(a, b, c);
      if (angle != null) {
        angles[name] = angle;
      }
    }

    return angles;
  }

  /// Compute the angle at vertex B formed by points A–B–C.
  ///
  /// Uses the 2D dot-product formula:
  ///
  /// ```
  ///   BA = (A.x - B.x, A.y - B.y)
  ///   BC = (C.x - B.x, C.y - B.y)
  ///
  ///   dot   = BA.x * BC.x + BA.y * BC.y
  ///   magBA = sqrt(BA.x² + BA.y²)
  ///   magBC = sqrt(BC.x² + BC.y²)
  ///
  ///   cos(θ) = dot / (magBA * magBC)
  ///   θ      = acos( clamp(cos(θ), -1.0, 1.0) )
  /// ```
  ///
  /// Returns the angle in degrees, or `null` if the vectors are degenerate
  /// (zero length — would cause division by zero).
  static double? _angleBetweenPoints(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    // ── Build vectors BA and BC (vertex at B) ───────────────────────────
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    // ── Dot product ─────────────────────────────────────────────────────
    final dotProduct = baX * bcX + baY * bcY;

    // ── Magnitudes ──────────────────────────────────────────────────────
    final magnitudeBA = math.sqrt(baX * baX + baY * baY);
    final magnitudeBC = math.sqrt(bcX * bcX + bcY * bcY);

    // ── Guard: avoid division by zero for degenerate (collapsed) joints ─
    if (magnitudeBA == 0 || magnitudeBC == 0) return null;

    // ── Cosine of the angle ─────────────────────────────────────────────
    // Clamp to [-1, 1] to handle floating-point imprecision that could
    // push the value slightly outside the valid domain of acos.
    final cosTheta = (dotProduct / (magnitudeBA * magnitudeBC)).clamp(
      -1.0,
      1.0,
    );

    // ── Convert radians → degrees ───────────────────────────────────────
    final angleRadians = math.acos(cosTheta);
    final angleDegrees = angleRadians * (180.0 / math.pi);

    return angleDegrees;
  }

  /// Human-readable label for each joint key (used by the debug overlay).
  static const Map<String, String> jointLabels = {
    'leftElbow': 'L Elbow',
    'rightElbow': 'R Elbow',
    'leftKnee': 'L Knee',
    'rightKnee': 'R Knee',
    'leftShoulder': 'L Shoulder',
    'rightShoulder': 'R Shoulder',
    'leftHip': 'L Hip',
    'rightHip': 'R Hip',
  };
}

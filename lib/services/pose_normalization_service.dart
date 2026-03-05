import 'dart:math' as math;

import '../models/pose_landmark_model.dart';

/// PoseNormalizationService converts raw 33-landmark pose data into a
/// **translation-invariant** and **scale-invariant** 1D vector of key joints.
///
/// ## Pipeline
///
/// 1. **Translation normalisation** – subtract the hip center so the pose
///    origin is always at (0, 0).
/// 2. **Scale normalisation** – divide by torso length (shoulder center →
///    hip center) so the pose is size-independent.
/// 3. **Landmark selection** – pick 12 key joints and flatten to a 24-element
///    `[x1, y1, x2, y2, …]` vector.
///
/// Returns `null` when the frame is unreliable (torso too small or any
/// selected landmark has low confidence).
class PoseNormalizationService {
  // ── BlazePose indices for the 12 key joints ──────────────────────────────

  /// Indices into the 33-landmark list for the joints we care about.
  ///
  /// Order: L Shoulder, R Shoulder, L Elbow, R Elbow, L Wrist, R Wrist,
  ///        L Hip, R Hip, L Knee, R Knee, L Ankle, R Ankle.
  static const List<int> _keyJointIndices = [
    11, // left shoulder
    12, // right shoulder
    13, // left elbow
    14, // right elbow
    15, // left wrist
    16, // right wrist
    23, // left hip
    24, // right hip
    25, // left knee
    26, // right knee
    27, // left ankle
    28, // right ankle
  ];

  /// Human-readable labels matching [_keyJointIndices] order.
  static const List<String> keyJointLabels = [
    'L Shoulder',
    'R Shoulder',
    'L Elbow',
    'R Elbow',
    'L Wrist',
    'R Wrist',
    'L Hip',
    'R Hip',
    'L Knee',
    'R Knee',
    'L Ankle',
    'R Ankle',
  ];

  /// Number of key joints selected for the output vector.
  static int get keyJointCount => _keyJointIndices.length;

  /// Expected length of the output vector (2 values per joint: x, y).
  static int get vectorLength => keyJointCount * 2;

  /// Minimum torso length (in pixels) below which we consider the pose
  /// unreliable and return `null`.  Prevents division-by-zero and
  /// amplification of noise when the person is barely visible.
  static const double _minTorsoLength = 1e-6;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Normalize [landmarks] into a 24-element 1D vector.
  ///
  /// Returns `null` if:
  /// - The landmark list has fewer than 33 entries.
  /// - Any of the 12 selected landmarks has low confidence.
  /// - The computed torso length is effectively zero.
  ///
  /// ### Math
  ///
  /// ```
  /// hipCenter      = (leftHip + rightHip) / 2
  /// shoulderCenter = (leftShoulder + rightShoulder) / 2
  /// torsoLength    = ‖shoulderCenter − hipCenter‖
  ///
  /// For each landmark L:
  ///   L' = (L − hipCenter) / torsoLength
  ///
  /// Output = [L'₁.x, L'₁.y, L'₂.x, L'₂.y, …]
  /// ```
  List<double>? normalize(List<PoseLandmark> landmarks) {
    // ── Guard: need all 33 BlazePose landmarks ─────────────────────────
    if (landmarks.length < 33) return null;

    // ── Retrieve hip and shoulder landmarks ─────────────────────────────
    final leftHip = landmarks[23];
    final rightHip = landmarks[24];
    final leftShoulder = landmarks[11];
    final rightShoulder = landmarks[12];

    // ── Check confidence of the four torso anchors ─────────────────────
    if (!leftHip.isValid ||
        !rightHip.isValid ||
        !leftShoulder.isValid ||
        !rightShoulder.isValid) {
      return null;
    }

    // ── Step 1: Compute hip center (translation origin) ────────────────
    //
    //   hipCenter = midpoint(leftHip, rightHip)
    //
    final hipCenterX = (leftHip.x + rightHip.x) / 2.0;
    final hipCenterY = (leftHip.y + rightHip.y) / 2.0;

    // ── Step 2: Compute shoulder center & torso length (scale factor) ──
    //
    //   shoulderCenter = midpoint(leftShoulder, rightShoulder)
    //   torsoLength    = distance(shoulderCenter, hipCenter)
    //
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2.0;

    final dx = shoulderCenterX - hipCenterX;
    final dy = shoulderCenterY - hipCenterY;
    final torsoLength = math.sqrt(dx * dx + dy * dy);

    // Guard: avoid division by zero when torso is too small.
    if (torsoLength < _minTorsoLength) return null;

    // ── Step 3: Select key joints, translate, scale, flatten ───────────
    //
    //   For each key joint index i:
    //     normalizedX = (landmark[i].x − hipCenter.x) / torsoLength
    //     normalizedY = (landmark[i].y − hipCenter.y) / torsoLength
    //
    //   Output: [x₁, y₁, x₂, y₂, …]  (24 elements)
    //
    final vector = <double>[];

    for (final idx in _keyJointIndices) {
      final lm = landmarks[idx];

      // Skip frames where any key joint has low confidence.
      if (!lm.isValid) return null;

      // Translate: move origin to hip center.
      final translatedX = lm.x - hipCenterX;
      final translatedY = lm.y - hipCenterY;

      // Scale: divide by torso length for size invariance.
      vector.add(translatedX / torsoLength);
      vector.add(translatedY / torsoLength);
    }

    return vector;
  }
}

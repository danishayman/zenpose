import 'dart:math' as math;

/// PoseCorrectionService generates real-time corrective feedback by comparing
/// joint angles between the user's live pose and a reference pose template.
///
/// ## Pipeline
///
/// 1. **Reference angles** are computed once from the template's 24-element
///    mean vector when [computeReferenceAngles] is called.
/// 2. Each frame, [generateCorrections] compares user angles against the
///    reference and returns up to [maxFeedbackMessages] human-readable tips.
///
/// ## Angle error threshold
///
/// A joint is flagged when `|userAngle − referenceAngle| > errorThreshold`.
/// The default threshold is 20°.
class PoseCorrectionService {
  // ── Configuration ─────────────────────────────────────────────────────────

  /// Angle difference (degrees) above which corrective feedback is triggered.
  static const double errorThreshold = 20.0;

  /// Maximum number of feedback messages returned per frame (keeps the UI
  /// clean and avoids overwhelming the user).
  static const int maxFeedbackMessages = 3;

  // ── Reference angles ──────────────────────────────────────────────────────

  /// Pre-computed joint angles (degrees) for the selected reference pose.
  ///
  /// Keys match [AngleCalculationService] joint names:
  /// `leftElbow`, `rightElbow`, `leftKnee`, `rightKnee`,
  /// `leftShoulder`, `rightShoulder`, `leftHip`, `rightHip`.
  Map<String, double> _referenceAngles = {};

  /// Public read-only access to the reference angles (useful for debugging).
  Map<String, double> get referenceAngles => Map.unmodifiable(_referenceAngles);

  // ── Joint definitions (mirroring AngleCalculationService) ─────────────────
  //
  // The template's meanVector is a 24-element normalized vector laid out as:
  //
  //   Index 0,1   → L Shoulder     Index 12,13 → L Hip
  //   Index 2,3   → R Shoulder     Index 14,15 → R Hip
  //   Index 4,5   → L Elbow        Index 16,17 → L Knee
  //   Index 6,7   → R Elbow        Index 18,19 → R Knee
  //   Index 8,9   → L Wrist        Index 20,21 → L Ankle
  //   Index 10,11 → R Wrist        Index 22,23 → R Ankle
  //
  // Each joint angle triple is (A, B, C) where B is the vertex.
  // The indices below refer to the *joint index* (0-based) in the 12-joint
  // list above.  To get the vector offset: offset = jointIndex * 2.

  /// Joint angle definitions expressed as indices into the 12-joint list.
  ///
  /// Layout: `(A, B, C)` — angle measured at B.
  static const Map<String, (int, int, int)> _templateJointDefs = {
    'leftElbow': (0, 2, 4), // L Shoulder → L Elbow → L Wrist
    'rightElbow': (1, 3, 5), // R Shoulder → R Elbow → R Wrist
    'leftKnee': (6, 8, 10), // L Hip → L Knee → L Ankle
    'rightKnee': (7, 9, 11), // R Hip → R Knee → R Ankle
    'leftShoulder': (2, 0, 6), // L Elbow → L Shoulder → L Hip
    'rightShoulder': (3, 1, 7), // R Elbow → R Shoulder → R Hip
    'leftHip': (0, 6, 8), // L Shoulder → L Hip → L Knee
    'rightHip': (1, 7, 9), // R Shoulder → R Hip → R Knee
  };

  // ── Feedback message templates ────────────────────────────────────────────
  //
  // Each entry provides two messages: one for when the user's angle is
  // *larger* (more open / too straight) and one for *smaller* (more closed /
  // too bent) than the reference.

  static const Map<String, (String, String)> _feedbackTemplates = {
    //                         (user angle too large,          user angle too small)
    'leftElbow': ('Straighten your left arm', 'Bend your left elbow more'),
    'rightElbow': ('Straighten your right arm', 'Bend your right elbow more'),
    'leftKnee': ('Straighten your left leg', 'Bend your left knee more'),
    'rightKnee': ('Straighten your right leg', 'Bend your right knee more'),
    'leftShoulder': ('Lower your left arm', 'Raise your left arm'),
    'rightShoulder': ('Lower your right arm', 'Raise your right arm'),
    'leftHip': ('Open your left hip more', 'Close your left hip'),
    'rightHip': ('Open your right hip more', 'Close your right hip'),
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// Compute reference joint angles from a template's [meanVector].
  ///
  /// Call this **once** when a pose template is loaded / selected.
  /// The [meanVector] must be a 24-element normalised vector
  /// (`[x0, y0, x1, y1, …]` for 12 key joints).
  void computeReferenceAngles(List<double> meanVector) {
    if (meanVector.length < 24) {
      _referenceAngles = {};
      return;
    }

    final angles = <String, double>{};

    for (final entry in _templateJointDefs.entries) {
      final name = entry.key;
      final (idxA, idxB, idxC) = entry.value;

      // Convert joint index → vector offset (each joint occupies 2 slots).
      final ax = meanVector[idxA * 2];
      final ay = meanVector[idxA * 2 + 1];
      final bx = meanVector[idxB * 2];
      final by = meanVector[idxB * 2 + 1];
      final cx = meanVector[idxC * 2];
      final cy = meanVector[idxC * 2 + 1];

      final angle = _angleBetween(ax, ay, bx, by, cx, cy);
      if (angle != null) {
        angles[name] = angle;
      }
    }

    _referenceAngles = angles;
  }

  /// Compare [userAngles] against the stored reference angles and return
  /// up to [maxFeedbackMessages] corrective feedback strings.
  ///
  /// [userAngles] should be the output of
  /// `AngleCalculationService.calculateAngles()`.
  ///
  /// Joints are sorted by descending error so the worst misalignment
  /// appears first.
  List<String> generateCorrections(Map<String, double> userAngles) {
    if (_referenceAngles.isEmpty || userAngles.isEmpty) return [];

    // Collect all joints that exceed the error threshold.
    final errors = <_JointError>[];

    for (final joint in _referenceAngles.keys) {
      final refAngle = _referenceAngles[joint];
      final userAngle = userAngles[joint];
      if (refAngle == null || userAngle == null) continue;

      final error = (userAngle - refAngle).abs();
      if (error > errorThreshold) {
        errors.add(
          _JointError(
            joint: joint,
            error: error,
            userAngle: userAngle,
            refAngle: refAngle,
          ),
        );
      }
    }

    if (errors.isEmpty) return [];

    // Sort: largest error first (most important correction).
    errors.sort((a, b) => b.error.compareTo(a.error));

    // Build feedback messages (capped at maxFeedbackMessages).
    final messages = <String>[];
    for (final e in errors.take(maxFeedbackMessages)) {
      final templates = _feedbackTemplates[e.joint];
      if (templates == null) continue;

      // User angle **larger** than reference → joint is too open / straight.
      // User angle **smaller** than reference → joint is too closed / bent.
      final message = e.userAngle > e.refAngle ? templates.$1 : templates.$2;
      messages.add(message);
    }

    return messages;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Compute the angle (degrees) at vertex B given three 2D points.
  ///
  /// Returns `null` if either vector has zero length (degenerate case).
  static double? _angleBetween(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final baX = ax - bx;
    final baY = ay - by;
    final bcX = cx - bx;
    final bcY = cy - by;

    final dot = baX * bcX + baY * bcY;
    final magBA = math.sqrt(baX * baX + baY * baY);
    final magBC = math.sqrt(bcX * bcX + bcY * bcY);

    if (magBA == 0 || magBC == 0) return null;

    final cosTheta = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
    return math.acos(cosTheta) * (180.0 / math.pi);
  }
}

/// Internal helper to sort joints by error magnitude.
class _JointError {
  final String joint;
  final double error;
  final double userAngle;
  final double refAngle;

  const _JointError({
    required this.joint,
    required this.error,
    required this.userAngle,
    required this.refAngle,
  });
}

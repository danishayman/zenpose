import 'dart:math' as math;

/// CosineSimilarityService compares a user's normalised pose vector against
/// a hardcoded reference vector using **cosine similarity**.
///
/// ## Math recap
///
/// Cosine similarity measures the angle between two vectors, ignoring their
/// magnitude.  A value of 1 means the vectors point in the same direction
/// (identical pose), 0 means they are orthogonal, and −1 means opposite.
///
/// ```
/// cosine(A, B) = (A · B) / (‖A‖ × ‖B‖)
///
/// where
///   A · B  = Σ aᵢ·bᵢ          (dot product)
///   ‖A‖    = √(Σ aᵢ²)         (Euclidean magnitude / L2 norm)
/// ```
///
/// The raw cosine value (−1 to 1) is then mapped to a human-friendly
/// **percentage** (0 to 100):
///
/// ```
/// score = ((cosine + 1) / 2) × 100
/// ```
class CosineSimilarityService {
  // ── Reference vector ──────────────────────────────────────────────────────
  //
  // The reference vector is now **dynamic** — it is set at runtime from the
  // selected PoseTemplate rather than being hardcoded.  This allows the same
  // service to score the user's pose against any target pose in the library.
  //
  // Fallback: a neutral standing pose is kept as the default so existing
  // callers continue to work without changes.

  /// Default reference: neutral standing pose (24 elements = 12 joints × [x, y]).
  static const List<double> defaultReferenceVector = [
    -0.50, -1.00, // L Shoulder
    0.50, -1.00, // R Shoulder
    -0.55, -0.45, // L Elbow
    0.55, -0.45, // R Elbow
    -0.55, 0.10, // L Wrist
    0.55, 0.10, // R Wrist
    -0.20, 0.00, // L Hip
    0.20, 0.00, // R Hip
    -0.22, 1.00, // L Knee
    0.22, 1.00, // R Knee
    -0.24, 2.00, // L Ankle
    0.24, 2.00, // R Ankle
  ];

  /// The active reference vector used for pose comparison.
  ///
  /// Can be updated at runtime via [setReferenceVector] when the user
  /// selects a different pose from the Pose Library.
  List<double> _referenceVector;

  /// Backward-compatible getter so existing code referencing
  /// `referenceVector` continues to compile.
  List<double> get referenceVector => _referenceVector;

  /// Create the service, optionally injecting a custom reference vector.
  CosineSimilarityService({List<double>? referenceVector})
    : _referenceVector = referenceVector ?? defaultReferenceVector;

  /// Replace the reference vector at runtime (e.g. when the user picks a pose).
  void setReferenceVector(List<double> vector) {
    _referenceVector = vector;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Compare [userVector] against the current [referenceVector].
  ///
  /// Returns a **percentage** (0–100) indicating how closely the user's
  /// current pose matches the reference.  Returns `0.0` when the input is
  /// null, empty, or has a mismatched length.
  double compareToPose(List<double>? userVector) {
    if (userVector == null || userVector.length != _referenceVector.length) {
      return 0.0;
    }
    return computeSimilarity(userVector, _referenceVector);
  }

  /// Compute the cosine similarity between two vectors and return it as a
  /// **percentage** (0–100).
  ///
  /// ### Steps
  /// 1. Compute dot product  A · B.
  /// 2. Compute magnitudes   ‖A‖ and ‖B‖.
  /// 3. Guard against division by zero (return 0 %).
  /// 4. Compute raw cosine = (A · B) / (‖A‖ × ‖B‖).
  /// 5. Clamp to [−1, 1] to handle floating-point rounding.
  /// 6. Map from [−1, 1] → [0, 100].
  double computeSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Vectors must have the same length.');

    // Step 1 — dot product: Σ aᵢ·bᵢ
    final double dot = _dotProduct(a, b);

    // Step 2 — magnitudes (L2 norms)
    final double magA = _magnitude(a);
    final double magB = _magnitude(b);

    // Step 3 — avoid division by zero.
    //
    // A zero-magnitude vector means all coordinates are 0 (degenerate pose).
    // In that case the angle is undefined; we return 0 %.
    if (magA == 0.0 || magB == 0.0) return 0.0;

    // Step 4 — raw cosine similarity
    final double cosine = dot / (magA * magB);

    // Step 5 — clamp to [-1, 1].
    //
    // Floating-point arithmetic can produce values like 1.0000000000000002
    // which would cause issues downstream.  Clamping keeps us safe.
    final double clampedCosine = cosine.clamp(-1.0, 1.0);

    // Step 6 — map [-1, 1] → [0, 100].
    //
    //   cosine = -1  →  score =   0 %  (completely opposite)
    //   cosine =  0  →  score =  50 %  (orthogonal)
    //   cosine =  1  →  score = 100 %  (identical direction)
    final double score = ((clampedCosine + 1.0) / 2.0) * 100.0;

    return score;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Dot product of two equal-length vectors.
  ///
  /// ```
  /// A · B = a₁b₁ + a₂b₂ + … + aₙbₙ
  /// ```
  double _dotProduct(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  /// Euclidean magnitude (L2 norm) of a vector.
  ///
  /// ```
  /// ‖V‖ = √(v₁² + v₂² + … + vₙ²)
  /// ```
  double _magnitude(List<double> v) {
    double sumOfSquares = 0.0;
    for (final value in v) {
      sumOfSquares += value * value;
    }
    return math.sqrt(sumOfSquares);
  }
}

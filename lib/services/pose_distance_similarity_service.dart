import 'dart:math' as math;

/// PoseDistanceSimilarityService scores a user's pose by comparing the
/// **Euclidean distance** between the live normalised vector and the
/// reference template vector.
///
/// Unlike cosine similarity, Euclidean distance preserves the **absolute
/// joint layout**, which makes it more sensitive to poses that look
/// "different" despite sharing a similar overall orientation.
///
/// The raw distance is mapped to a 0-100 score using a linear falloff:
///
///   score = (1 - distance / maxDistance) * 100
///
/// Values below 0 are clamped to 0.
class PoseDistanceSimilarityService {
  /// Distance above which the score bottoms out at 0.
  ///
  /// Tuned against the current pose template spread (~3.1 max pairwise
  /// distance). Adjust as you collect more real-world calibration data.
  static const double defaultMaxDistance = 3.0;

  /// Compute a distance-based similarity score (0-100).
  ///
  /// Returns 0 when vectors are null or mismatched.
  double computeScore(
    List<double>? userVector,
    List<double> referenceVector, {
    double maxDistance = defaultMaxDistance,
  }) {
    if (userVector == null || userVector.length != referenceVector.length) {
      return 0.0;
    }

    final distance = _euclideanDistance(userVector, referenceVector);
    final normalized = (1.0 - (distance / maxDistance)).clamp(0.0, 1.0);
    return normalized * 100.0;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Vectors must have the same length.');
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }
}

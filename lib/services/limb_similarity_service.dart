import 'cosine_similarity_service.dart';

/// LimbSimilarityService computes **per-segment** cosine similarity scores
/// and generates corrective feedback messages.
///
/// ## Body segments
///
/// Each segment is a group of related joints whose normalised coordinates are
/// extracted from the 24-element pose vector produced by
/// [PoseNormalizationService] and compared against the matching sub-vector of
/// [CosineSimilarityService.referenceVector].
///
/// | Segment    | Joints                                      |
/// |------------|---------------------------------------------|
/// | Left Arm   | leftShoulder, leftElbow, leftWrist           |
/// | Right Arm  | rightShoulder, rightElbow, rightWrist        |
/// | Left Leg   | leftHip, leftKnee, leftAnkle                 |
/// | Right Leg  | rightHip, rightKnee, rightAnkle              |
/// | Torso      | leftShoulder, rightShoulder, leftHip, rightHip |
///
/// ## Feedback
///
/// When a segment scores below [feedbackThreshold] (default 70 %), a
/// human-readable corrective message is returned for that segment.
class LimbSimilarityService {
  // ── Dependencies ──────────────────────────────────────────────────────────

  final CosineSimilarityService _cosineSimilarityService;

  LimbSimilarityService({CosineSimilarityService? cosineSimilarityService})
    : _cosineSimilarityService =
          cosineSimilarityService ?? CosineSimilarityService();

  // ── Segment definitions ───────────────────────────────────────────────────
  //
  // The normalised vector produced by PoseNormalizationService has 24 elements
  // laid out as [x, y] pairs for 12 joints in this order:
  //
  //   Index 0,1   → L Shoulder
  //   Index 2,3   → R Shoulder
  //   Index 4,5   → L Elbow
  //   Index 6,7   → R Elbow
  //   Index 8,9   → L Wrist
  //   Index 10,11 → R Wrist
  //   Index 12,13 → L Hip
  //   Index 14,15 → R Hip
  //   Index 16,17 → L Knee
  //   Index 18,19 → R Knee
  //   Index 20,21 → L Ankle
  //   Index 22,23 → R Ankle

  /// Human-readable segment names **in display order**.
  static const List<String> segmentNames = [
    'Left Arm',
    'Right Arm',
    'Left Leg',
    'Right Leg',
    'Torso',
  ];

  /// Vector indices (into the 24-element normalised vector) for each segment.
  ///
  /// Order matches [segmentNames].
  static const List<List<int>> _segmentIndices = [
    // Left Arm:  L Shoulder (0,1) + L Elbow (4,5) + L Wrist (8,9)
    [0, 1, 4, 5, 8, 9],

    // Right Arm: R Shoulder (2,3) + R Elbow (6,7) + R Wrist (10,11)
    [2, 3, 6, 7, 10, 11],

    // Left Leg:  L Hip (12,13) + L Knee (16,17) + L Ankle (20,21)
    [12, 13, 16, 17, 20, 21],

    // Right Leg: R Hip (14,15) + R Knee (18,19) + R Ankle (22,23)
    [14, 15, 18, 19, 22, 23],

    // Torso: L Shoulder (0,1) + R Shoulder (2,3) + L Hip (12,13) + R Hip (14,15)
    [0, 1, 2, 3, 12, 13, 14, 15],
  ];

  /// Corrective feedback messages for each segment (same order as [segmentNames]).
  static const List<String> _feedbackMessages = [
    'Raise your left arm',
    'Raise your right arm',
    'Straighten your left leg',
    'Straighten your right leg',
    'Adjust torso alignment',
  ];

  /// Score below which corrective feedback is triggered (percentage, 0–100).
  static const double feedbackThreshold = 70.0;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Compute per-segment similarity scores between [userVector] and the
  /// active reference vector from [CosineSimilarityService].
  ///
  /// Returns a `Map<String, double>` keyed by segment name (see [segmentNames])
  /// with values in the range 0–100, or an empty map if the input is invalid.
  Map<String, double> computeLimbScores(List<double>? userVector) {
    // Use the dynamic reference vector from the injected similarity service.
    final reference = _cosineSimilarityService.referenceVector;
    if (userVector == null || userVector.length != reference.length) {
      return {};
    }
    final scores = <String, double>{};

    for (int i = 0; i < segmentNames.length; i++) {
      final indices = _segmentIndices[i];

      // Extract sub-vectors for this segment.
      final userSub = _extractSubVector(userVector, indices);
      final refSub = _extractSubVector(reference, indices);

      // Reuse the existing cosine similarity computation.
      scores[segmentNames[i]] = _cosineSimilarityService.computeSimilarity(
        userSub,
        refSub,
      );
    }

    return scores;
  }

  /// Generate corrective feedback for segments scoring below [feedbackThreshold].
  ///
  /// [limbScores] should be the output of [computeLimbScores].  Returns an
  /// empty list when all segments meet the threshold.
  List<String> generateFeedback(Map<String, double> limbScores) {
    final messages = <String>[];

    for (int i = 0; i < segmentNames.length; i++) {
      final score = limbScores[segmentNames[i]];
      if (score != null && score < feedbackThreshold) {
        messages.add(_feedbackMessages[i]);
      }
    }

    return messages;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Build a sub-vector by picking the elements at [indices] from [vector].
  List<double> _extractSubVector(List<double> vector, List<int> indices) {
    return [for (final idx in indices) vector[idx]];
  }
}

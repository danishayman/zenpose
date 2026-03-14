/// Configuration for a pose evaluation session.
///
/// This allows different modes (single pose practice vs daily challenge)
/// to control hold duration and score threshold without duplicating logic.
class PoseSessionConfig {
  final Duration holdDuration;
  final double scoreThreshold;
  final bool persistResult;

  const PoseSessionConfig({
    required this.holdDuration,
    required this.scoreThreshold,
    this.persistResult = true,
  });

  static const PoseSessionConfig defaultPractice = PoseSessionConfig(
    holdDuration: Duration(seconds: 5),
    scoreThreshold: 60,
    persistResult: true,
  );
}

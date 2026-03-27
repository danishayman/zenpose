/// Configuration for a pose evaluation session.
///
/// This allows different modes (single pose practice vs daily challenge)
/// to control hold duration and score threshold without duplicating logic.
enum PoseSessionMode { holdThreshold, timed }

class PoseSessionConfig {
  final PoseSessionMode mode;
  final Duration holdDuration;
  final double scoreThreshold;
  final bool persistResult;
  final Duration timedDuration;

  const PoseSessionConfig({
    this.mode = PoseSessionMode.holdThreshold,
    required this.holdDuration,
    required this.scoreThreshold,
    this.persistResult = true,
    this.timedDuration = const Duration(seconds: 45),
  });

  static const PoseSessionConfig defaultPractice = PoseSessionConfig(
    holdDuration: Duration(seconds: 5),
    scoreThreshold: 60,
    persistResult: true,
  );
}

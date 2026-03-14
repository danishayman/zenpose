class ChallengeStepResult {
  final String poseName;
  final double bestScore;
  final double holdDuration;
  final bool passed;
  final DateTime completedAt;

  const ChallengeStepResult({
    required this.poseName,
    required this.bestScore,
    required this.holdDuration,
    required this.passed,
    required this.completedAt,
  });
}

enum ChallengeStepNavigationAction { completed, previous, next }

class ChallengeStepResult {
  final String poseName;
  final double bestScore;
  final double holdDuration;
  final bool passed;
  final DateTime completedAt;
  final ChallengeStepNavigationAction action;

  const ChallengeStepResult({
    required this.poseName,
    required this.bestScore,
    required this.holdDuration,
    required this.passed,
    required this.completedAt,
    this.action = ChallengeStepNavigationAction.completed,
  });

  ChallengeStepResult copyWith({
    String? poseName,
    double? bestScore,
    double? holdDuration,
    bool? passed,
    DateTime? completedAt,
    ChallengeStepNavigationAction? action,
  }) {
    return ChallengeStepResult(
      poseName: poseName ?? this.poseName,
      bestScore: bestScore ?? this.bestScore,
      holdDuration: holdDuration ?? this.holdDuration,
      passed: passed ?? this.passed,
      completedAt: completedAt ?? this.completedAt,
      action: action ?? this.action,
    );
  }
}

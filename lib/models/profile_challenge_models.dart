enum ChallengeMetricType { sessions, minutes, scoreCount }

enum ChallengeLifecycleStatus { notJoined, joined, claimable, completed, ended }

enum UserProfileChallengeStatus { joined, completed }

extension UserProfileChallengeStatusX on UserProfileChallengeStatus {
  String get dbValue {
    switch (this) {
      case UserProfileChallengeStatus.joined:
        return 'joined';
      case UserProfileChallengeStatus.completed:
        return 'completed';
    }
  }

  static UserProfileChallengeStatus fromDbValue(String value) {
    switch (value) {
      case 'completed':
        return UserProfileChallengeStatus.completed;
      case 'joined':
      default:
        return UserProfileChallengeStatus.joined;
    }
  }
}

class ProfileChallengeDefinition {
  final String challengeId;
  final String title;
  final String description;
  final ChallengeMetricType metricType;
  final double targetValue;
  final double? scoreThreshold;
  final int rewardXp;
  final String rewardBadgeLabel;

  const ProfileChallengeDefinition({
    required this.challengeId,
    required this.title,
    required this.description,
    required this.metricType,
    required this.targetValue,
    required this.scoreThreshold,
    required this.rewardXp,
    required this.rewardBadgeLabel,
  });
}

class UserProfileChallengeState {
  final String userId;
  final String monthKey;
  final String challengeId;
  final UserProfileChallengeStatus status;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final String? rewardBadgeLabel;
  final DateTime updatedAt;
  final bool isSynced;

  const UserProfileChallengeState({
    required this.userId,
    required this.monthKey,
    required this.challengeId,
    required this.status,
    required this.joinedAt,
    required this.completedAt,
    required this.claimedAt,
    required this.rewardBadgeLabel,
    required this.updatedAt,
    required this.isSynced,
  });

  factory UserProfileChallengeState.fromMap(Map<String, Object?> map) {
    return UserProfileChallengeState(
      userId: map['user_id']?.toString() ?? '',
      monthKey: map['month_key']?.toString() ?? '',
      challengeId: map['challenge_id']?.toString() ?? '',
      status: UserProfileChallengeStatusX.fromDbValue(
        map['status']?.toString() ?? 'joined',
      ),
      joinedAt: _toDateTime(map['joined_at']) ?? DateTime.now(),
      completedAt: _toDateTime(map['completed_at']),
      claimedAt: _toDateTime(map['claimed_at']),
      rewardBadgeLabel: _toStringOrNull(map['reward_badge_label']),
      updatedAt: _toDateTime(map['updated_at']) ?? DateTime.now(),
      isSynced: _toBool(map['is_synced']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'user_id': userId,
      'month_key': monthKey,
      'challenge_id': challengeId,
      'status': status.dbValue,
      'joined_at': joinedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'claimed_at': claimedAt?.toIso8601String(),
      'reward_badge_label': rewardBadgeLabel,
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  UserProfileChallengeState copyWith({
    UserProfileChallengeStatus? status,
    DateTime? joinedAt,
    DateTime? completedAt,
    DateTime? claimedAt,
    String? rewardBadgeLabel,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return UserProfileChallengeState(
      userId: userId,
      monthKey: monthKey,
      challengeId: challengeId,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      completedAt: completedAt ?? this.completedAt,
      claimedAt: claimedAt ?? this.claimedAt,
      rewardBadgeLabel: rewardBadgeLabel ?? this.rewardBadgeLabel,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String? _toStringOrNull(Object? value) {
    final parsed = value?.toString();
    if (parsed == null || parsed.isEmpty) return null;
    return parsed;
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is num) return value != 0;
    return value?.toString() == '1' || value?.toString() == 'true';
  }
}

class ChallengeProgressSnapshot {
  final ProfileChallengeDefinition definition;
  final String monthKey;
  final ChallengeLifecycleStatus status;
  final bool isJoined;
  final double currentValue;
  final double targetValue;
  final double progressRatio;
  final String progressLabel;
  final String periodLabel;
  final String buttonLabel;
  final String? rewardBadgeLabel;
  final int rewardXp;

  const ChallengeProgressSnapshot({
    required this.definition,
    required this.monthKey,
    required this.status,
    required this.isJoined,
    required this.currentValue,
    required this.targetValue,
    required this.progressRatio,
    required this.progressLabel,
    required this.periodLabel,
    required this.buttonLabel,
    required this.rewardBadgeLabel,
    required this.rewardXp,
  });
}

class ChallengeClaimResult {
  final bool applied;
  final int xpGranted;
  final String badgeLabel;
  final String message;

  const ChallengeClaimResult({
    required this.applied,
    required this.xpGranted,
    required this.badgeLabel,
    required this.message,
  });
}

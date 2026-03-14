/// A badge unlocked by the local user.
class UnlockedBadge {
  final String badgeId;
  final String name;
  final String description;
  final DateTime unlockedAt;

  const UnlockedBadge({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.unlockedAt,
  });

  factory UnlockedBadge.fromMap(Map<String, Object?> map) {
    final unlockedAt = DateTime.tryParse(map['unlocked_at']?.toString() ?? '');
    return UnlockedBadge(
      badgeId: map['badge_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      unlockedAt: unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

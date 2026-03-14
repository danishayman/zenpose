/// Aggregated local gamification state for the single offline user profile.
class UserStats {
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final DateTime? lastActiveDate;

  const UserStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXp,
    required this.lastActiveDate,
  });

  const UserStats.initial()
    : currentStreak = 0,
      longestStreak = 0,
      totalXp = 0,
      lastActiveDate = null;

  factory UserStats.fromMap(Map<String, Object?> map) {
    return UserStats(
      currentStreak: _toInt(map['current_streak']),
      longestStreak: _toInt(map['longest_streak']),
      totalXp: _toInt(map['total_xp']),
      lastActiveDate: _toDateTime(map['last_active_date']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_xp': totalXp,
      'last_active_date': lastActiveDate == null
          ? null
          : _toDateKey(lastActiveDate!),
    };
  }

  UserStats copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    DateTime? lastActiveDate,
  }) {
    return UserStats(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _toDateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

import '../models/pose_result.dart';
import '../models/profile_activity_models.dart';

class ProfileActivityService {
  const ProfileActivityService();

  ProfileActivitySeries buildSeries({
    required List<PoseResult> results,
    required ProfileActivityMetric metric,
    required DateTime now,
    int days = 10,
  }) {
    final dayCount = days < 1 ? 1 : days;
    final completed = results.where((r) => r.completed).toList(growable: false);
    final anchor = DateTime(now.year, now.month, now.day);
    final start = anchor.subtract(Duration(days: dayCount - 1));
    final points = <ProfileActivityPoint>[];

    for (var i = 0; i < dayCount; i++) {
      final day = start.add(Duration(days: i));
      final dayResults = completed
          .where((r) {
            final ts = r.timestamp?.toLocal();
            if (ts == null) return false;
            return ts.year == day.year &&
                ts.month == day.month &&
                ts.day == day.day;
          })
          .toList(growable: false);

      final value = switch (metric) {
        ProfileActivityMetric.duration => _dailyDurationMinutes(dayResults),
        ProfileActivityMetric.score => _dailyAverageScore(dayResults),
        ProfileActivityMetric.sessions => dayResults.length.toDouble(),
      };

      points.add(ProfileActivityPoint(day: day, value: value));
    }

    return ProfileActivitySeries(metric: metric, points: points);
  }

  double _dailyDurationMinutes(List<PoseResult> dayResults) {
    if (dayResults.isEmpty) return 0;
    final totalSeconds = dayResults.fold<double>(
      0,
      (sum, item) => sum + item.holdDuration,
    );
    return totalSeconds / 60.0;
  }

  double _dailyAverageScore(List<PoseResult> dayResults) {
    if (dayResults.isEmpty) return 0;
    final total = dayResults.fold<double>(
      0,
      (sum, item) => sum + item.bestScore,
    );
    return total / dayResults.length;
  }
}

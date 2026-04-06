enum ProfileActivityMetric { duration, score, sessions }

class ProfileActivityPoint {
  final DateTime day;
  final double value;

  const ProfileActivityPoint({required this.day, required this.value});
}

class ProfileActivitySeries {
  final ProfileActivityMetric metric;
  final List<ProfileActivityPoint> points;

  const ProfileActivitySeries({required this.metric, required this.points});
}

enum BodyMetricType {
  bodyWeight,
  bodyFat;

  String get metricKey {
    switch (this) {
      case BodyMetricType.bodyWeight:
        return 'body_weight';
      case BodyMetricType.bodyFat:
        return 'body_fat';
    }
  }

  String get label {
    switch (this) {
      case BodyMetricType.bodyWeight:
        return 'Body weight';
      case BodyMetricType.bodyFat:
        return 'Body fat';
    }
  }

  String get unit {
    switch (this) {
      case BodyMetricType.bodyWeight:
        return 'kg';
      case BodyMetricType.bodyFat:
        return '%';
    }
  }

  static const List<BodyMetricType> coreMetrics = <BodyMetricType>[
    BodyMetricType.bodyWeight,
    BodyMetricType.bodyFat,
  ];

  static BodyMetricType? fromKey(String? key) {
    for (final metric in coreMetrics) {
      if (metric.metricKey == key) return metric;
    }
    return null;
  }
}

class BodyMeasurement {
  final String userId;
  final BodyMetricType metricType;
  final double value;
  final String unit;
  final DateTime measuredAt;
  final DateTime updatedAt;
  final bool isSynced;

  const BodyMeasurement({
    required this.userId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.updatedAt,
    required this.isSynced,
  });

  factory BodyMeasurement.fromMap(Map<String, Object?> map) {
    final metricType = BodyMetricType.fromKey(map['metric_key']?.toString());
    if (metricType == null) {
      throw const FormatException('Invalid metric_key for BodyMeasurement.');
    }
    return BodyMeasurement(
      userId: map['user_id']?.toString() ?? '',
      metricType: metricType,
      value: _toDouble(map['value']),
      unit: map['unit']?.toString() ?? metricType.unit,
      measuredAt: _toDate(map['measured_at']) ?? DateTime.now().toUtc(),
      updatedAt: _toDate(map['updated_at']) ?? DateTime.now().toUtc(),
      isSynced: _toBool(map['is_synced']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'user_id': userId,
      'metric_key': metricType.metricKey,
      'value': value,
      'unit': unit,
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  BodyMeasurement copyWith({
    String? userId,
    BodyMetricType? metricType,
    double? value,
    String? unit,
    DateTime? measuredAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return BodyMeasurement(
      userId: userId ?? this.userId,
      metricType: metricType ?? this.metricType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      measuredAt: measuredAt ?? this.measuredAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  static double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value != 0;
    return value?.toString() == 'true';
  }
}

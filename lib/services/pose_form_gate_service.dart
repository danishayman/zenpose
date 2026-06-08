import 'dart:math' as math;

import 'pose_normalization_service.dart';

class PoseFormGateResult {
  final bool passes;
  final List<String> feedbackMessages;
  final double? scoreCap;

  const PoseFormGateResult({
    required this.passes,
    required this.feedbackMessages,
    this.scoreCap,
  });

  static const PoseFormGateResult pass = PoseFormGateResult(
    passes: true,
    feedbackMessages: <String>[],
  );

  double applyToScore(double score) {
    final cap = scoreCap;
    if (cap == null) return score;
    return math.min(score, cap);
  }
}

/// Blocks false-green matches for poses whose silhouette alone is too broad.
///
/// The app still uses the existing template similarity score, but these gates
/// require a few essential yoga-form landmarks before the score can go green.
class PoseFormGateService {
  static const double scoreCapMargin = 8.0;

  PoseFormGateResult evaluate({
    required String poseKey,
    required List<double>? normalizedVector,
    required Map<String, double> angles,
    required double scoreThreshold,
  }) {
    final normalizedKey = _normalizePoseKey(poseKey);
    if (!_gatedPoseKeys.contains(normalizedKey)) {
      return PoseFormGateResult.pass;
    }

    if (normalizedVector == null ||
        normalizedVector.length != PoseNormalizationService.vectorLength) {
      return _fail(scoreThreshold, const <String>[
        'Keep your full body visible',
      ]);
    }

    final points = _PosePoints(normalizedVector);
    final failures = switch (normalizedKey) {
      'chair' => _chairFailures(points, angles),
      'downdog' => _downDogFailures(points, angles),
      'goddess' => _goddessFailures(points, angles),
      'halfmoon' => _halfMoonFailures(points, angles),
      'highlunge' => _highLungeFailures(points, angles),
      'plank' => _plankFailures(points, angles),
      'warrior2' => _warrior2Failures(points, angles),
      'cobra' => _cobraFailures(points),
      'triangle' => _triangleFailures(points, angles),
      _ => const <String>[],
    };

    if (failures.isEmpty) return PoseFormGateResult.pass;
    return _fail(scoreThreshold, failures);
  }

  static const Set<String> _gatedPoseKeys = <String>{
    'chair',
    'downdog',
    'goddess',
    'halfmoon',
    'highlunge',
    'plank',
    'warrior2',
    'cobra',
    'triangle',
  };

  PoseFormGateResult _fail(double scoreThreshold, List<String> messages) {
    final cap = math.max(0.0, scoreThreshold - scoreCapMargin);
    return PoseFormGateResult(
      passes: false,
      feedbackMessages: messages,
      scoreCap: cap,
    );
  }

  List<String> _chairFailures(_PosePoints points, Map<String, double> angles) {
    final failures = <String>[];
    if (!_bothArmsOverhead(points)) {
      failures.add('Raise both arms overhead');
    }
    final hasKneeBend = _atLeastOneKneeBent(angles, maxAngle: 172.0);
    if (!hasKneeBend) {
      failures.add('Bend your knees more');
    }
    if (points.averageKneeY > 0.95) {
      failures.add('Lower your hips like sitting');
    }
    return failures;
  }

  List<String> _goddessFailures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (points.ankleSpreadX < 1.05 || points.kneeSpreadX < 0.85) {
      failures.add('Step your feet wider');
    }
    if (!_bothKneesBent(angles, maxAngle: 135.0)) {
      failures.add('Bend both knees outward');
    }
    final kneesOpenNearAnkles =
        points.kneeSpreadX >= points.ankleSpreadX * 0.78;
    if (points.averageKneeY > 0.42 || !kneesOpenNearAnkles) {
      failures.add('Sink your hips lower');
    }
    return failures;
  }

  List<String> _downDogFailures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (points.averageHipY > points.averageWristY - 0.55 ||
        points.averageHipY > points.averageAnkleY - 0.55) {
      failures.add('Lift your hips higher');
    }
    if (points.torsoDeviationFromVertical < 50.0) {
      failures.add('Fold into an inverted V shape');
    }
    if (!_bothElbowsStraight(angles, minAngle: 150.0)) {
      failures.add('Straighten your arms');
    }
    if (!_bothKneesStraight(angles, minAngle: 150.0)) {
      failures.add('Lengthen both legs');
    }
    return failures;
  }

  List<String> _halfMoonFailures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (points.ankleYDiff < 0.45) {
      failures.add('Lift one leg higher');
    }
    if (points.torsoDeviationFromVertical < 35.0) {
      failures.add('Open your torso sideways');
    }
    if (!_bothKneesStraight(angles, minAngle: 155.0)) {
      failures.add('Keep both legs long');
    }
    return failures;
  }

  List<String> _highLungeFailures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (!_atLeastOneKneeBent(angles, maxAngle: 165.0)) {
      failures.add('Bend your front knee forward');
    }
    if (points.minKneeY > 0.70) {
      failures.add('Lower into your lunge');
    }
    return failures;
  }

  List<String> _plankFailures(_PosePoints points, Map<String, double> angles) {
    final failures = <String>[];
    if (points.torsoDeviationFromVertical > 25.0 ||
        points.hipDistanceFromShoulderAnkleLine > 0.25) {
      failures.add('Keep shoulders, hips, and heels in one line');
    }
    if ((points.averageWristY - points.averageShoulderY).abs() > 0.45) {
      failures.add('Stack your shoulders over your hands');
    }
    if (!_bothElbowsStraight(angles, minAngle: 150.0)) {
      failures.add('Press through straight arms');
    }
    if (!_bothKneesStraight(angles, minAngle: 155.0)) {
      failures.add('Straighten both legs');
    }
    return failures;
  }

  List<String> _warrior2Failures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (points.ankleSpreadX < 1.05) {
      failures.add('Step your feet wider');
    }
    if (!_bothArmsAtShoulderHeight(points) ||
        !_bothElbowsStraight(angles, minAngle: 150.0)) {
      failures.add('Stretch both arms out to the sides');
    }
    if (!_atLeastOneKneeBent(angles, maxAngle: 155.0)) {
      failures.add('Bend your front knee');
    }
    if (points.averageKneeY > 0.55) {
      failures.add('Lower your body into the stance');
    }
    return failures;
  }

  List<String> _cobraFailures(_PosePoints points) {
    final failures = <String>[];
    if (points.averageShoulderY > points.averageHipY - 0.45) {
      failures.add('Lift your chest higher');
    }
    if ((points.averageHipY - points.averageAnkleY).abs() > 0.35) {
      failures.add('Keep your hips low on the mat');
    }
    if ((points.averageWristY - points.averageHipY).abs() > 0.45) {
      failures.add('Place your hands under your shoulders');
    }
    return failures;
  }

  List<String> _triangleFailures(
    _PosePoints points,
    Map<String, double> angles,
  ) {
    final failures = <String>[];
    if (points.ankleSpreadX < 1.10) {
      failures.add('Step your feet wider');
    }
    if (!_bothKneesStraight(angles, minAngle: 160.0)) {
      failures.add('Straighten both legs');
    }
    if (points.torsoDeviationFromVertical < 25.0) {
      failures.add('Fold your torso sideways');
    }
    if (!_oneHandLowAndOneArmRaised(points)) {
      failures.add('Reach one hand down and the other up');
    }
    return failures;
  }

  bool _bothArmsOverhead(_PosePoints points) {
    return points.leftWrist.y < points.leftShoulder.y - 0.35 &&
        points.rightWrist.y < points.rightShoulder.y - 0.35;
  }

  bool _bothArmsAtShoulderHeight(_PosePoints points) {
    final leftLevel =
        (points.leftWrist.y - points.leftShoulder.y).abs() <= 0.25;
    final rightLevel =
        (points.rightWrist.y - points.rightShoulder.y).abs() <= 0.25;
    final wideEnough = points.wristSpreadX > points.shoulderSpreadX * 2.2;
    return leftLevel && rightLevel && wideEnough;
  }

  bool _oneHandLowAndOneArmRaised(_PosePoints points) {
    final leftHigh = points.leftWrist.y < points.leftShoulder.y - 0.25;
    final rightHigh = points.rightWrist.y < points.rightShoulder.y - 0.25;
    final leftLow = points.leftWrist.y > points.leftHip.y + 0.05;
    final rightLow = points.rightWrist.y > points.rightHip.y + 0.05;
    return (leftHigh && rightLow) || (rightHigh && leftLow);
  }

  bool _bothKneesBent(Map<String, double> angles, {required double maxAngle}) {
    final left = angles['leftKnee'];
    final right = angles['rightKnee'];
    if (left == null || right == null) return false;
    return left <= maxAngle && right <= maxAngle;
  }

  bool _atLeastOneKneeBent(
    Map<String, double> angles, {
    required double maxAngle,
  }) {
    final left = angles['leftKnee'];
    final right = angles['rightKnee'];
    if (left == null || right == null) return false;
    return left <= maxAngle || right <= maxAngle;
  }

  bool _bothKneesStraight(
    Map<String, double> angles, {
    required double minAngle,
  }) {
    final left = angles['leftKnee'];
    final right = angles['rightKnee'];
    if (left == null || right == null) return false;
    return left >= minAngle && right >= minAngle;
  }

  bool _bothElbowsStraight(
    Map<String, double> angles, {
    required double minAngle,
  }) {
    final left = angles['leftElbow'];
    final right = angles['rightElbow'];
    if (left == null || right == null) return false;
    return left >= minAngle && right >= minAngle;
  }

  String _normalizePoseKey(String key) {
    return key.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _PosePoints {
  final List<double> vector;

  const _PosePoints(this.vector);

  _Point get leftShoulder => _point(0);
  _Point get rightShoulder => _point(1);
  _Point get leftWrist => _point(4);
  _Point get rightWrist => _point(5);
  _Point get leftHip => _point(6);
  _Point get rightHip => _point(7);
  _Point get leftKnee => _point(8);
  _Point get rightKnee => _point(9);
  _Point get leftAnkle => _point(10);
  _Point get rightAnkle => _point(11);

  double get averageShoulderY => (leftShoulder.y + rightShoulder.y) / 2.0;
  double get averageWristY => (leftWrist.y + rightWrist.y) / 2.0;
  double get averageHipY => (leftHip.y + rightHip.y) / 2.0;
  double get averageKneeY => (leftKnee.y + rightKnee.y) / 2.0;
  double get minKneeY => math.min(leftKnee.y, rightKnee.y);
  double get averageAnkleY => (leftAnkle.y + rightAnkle.y) / 2.0;
  double get ankleSpreadX => (leftAnkle.x - rightAnkle.x).abs();
  double get kneeSpreadX => (leftKnee.x - rightKnee.x).abs();
  double get ankleYDiff => (leftAnkle.y - rightAnkle.y).abs();
  double get shoulderSpreadX => (leftShoulder.x - rightShoulder.x).abs();
  double get wristSpreadX => (leftWrist.x - rightWrist.x).abs();
  double get hipDistanceFromShoulderAnkleLine {
    final expectedHipY = (averageShoulderY + averageAnkleY) / 2.0;
    return (averageHipY - expectedHipY).abs();
  }

  double get torsoDeviationFromVertical {
    final shoulderCenter = _Point(
      (leftShoulder.x + rightShoulder.x) / 2.0,
      (leftShoulder.y + rightShoulder.y) / 2.0,
    );
    final hipCenter = _Point(
      (leftHip.x + rightHip.x) / 2.0,
      (leftHip.y + rightHip.y) / 2.0,
    );
    final dx = shoulderCenter.x - hipCenter.x;
    final dy = shoulderCenter.y - hipCenter.y;
    final angle = (math.atan2(dy, dx) * 180.0 / math.pi).abs();
    return (angle - 90.0).abs();
  }

  _Point _point(int jointIndex) {
    final offset = jointIndex * 2;
    return _Point(vector[offset], vector[offset + 1]);
  }
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}

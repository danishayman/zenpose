import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/services/pose_form_gate_service.dart';
import 'package:zenpose/services/pose_mirror_service.dart';

void main() {
  late PoseFormGateService service;

  setUp(() {
    service = PoseFormGateService();
  });

  group('PoseFormGateService', () {
    test('caps Chair when only one arm is raised', () {
      final result = service.evaluate(
        poseKey: 'chair',
        normalizedVector: _chairVector(rightWristY: -1.10),
        angles: _angles(leftKnee: 145, rightKnee: 150),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Raise both arms overhead'));
      expect(result.applyToScore(90), 52);
    });

    test('passes Chair when arms are overhead and knees are bent', () {
      final result = service.evaluate(
        poseKey: 'chair',
        normalizedVector: _chairVector(),
        angles: _angles(leftKnee: 145, rightKnee: 150),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
      expect(result.applyToScore(90), 90);
    });

    test('caps Goddess when the squat is too high', () {
      final result = service.evaluate(
        poseKey: 'goddess',
        normalizedVector: _goddessVector(kneeY: 0.70),
        angles: _angles(leftKnee: 150, rightKnee: 152),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Bend both knees outward'));
      expect(result.feedbackMessages, contains('Sink your hips lower'));
      expect(result.applyToScore(88), 52);
    });

    test('passes Goddess with wide low bent knees', () {
      final result = service.evaluate(
        poseKey: 'goddess',
        normalizedVector: _goddessVector(),
        angles: _angles(leftKnee: 118, rightKnee: 120),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Half Moon when the user only tilts sideways', () {
      final result = service.evaluate(
        poseKey: 'half-moon',
        normalizedVector: _halfMoonVector(ankleYDiff: 0.05),
        angles: _angles(leftKnee: 175, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Lift one leg higher'));
      expect(result.applyToScore(91), 52);
    });

    test('passes mirrored Half Moon when one leg is lifted', () {
      final result = service.evaluate(
        poseKey: 'half-moon',
        normalizedVector: PoseMirrorService.mirrorVector(_halfMoonVector()),
        angles: _angles(leftKnee: 175, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Warrior 2 when arms are raised overhead', () {
      final result = service.evaluate(
        poseKey: 'warrior2',
        normalizedVector: _warrior2Vector(
          leftWristY: -1.80,
          rightWristY: -1.80,
        ),
        angles: _angles(
          leftKnee: 142,
          rightKnee: 166,
          leftElbow: 172,
          rightElbow: 171,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(
        result.feedbackMessages,
        contains('Stretch both arms out to the sides'),
      );
      expect(result.applyToScore(85), 52);
    });

    test(
      'passes Warrior 2 with wide stance, side arms, and bent front knee',
      () {
        final result = service.evaluate(
          poseKey: 'warrior2',
          normalizedVector: _warrior2Vector(),
          angles: _angles(
            leftKnee: 142,
            rightKnee: 166,
            leftElbow: 172,
            rightElbow: 171,
          ),
          scoreThreshold: 60,
        );

        expect(result.passes, isTrue);
      },
    );

    test('caps Triangle when user is just standing', () {
      final result = service.evaluate(
        poseKey: 'triangle',
        normalizedVector: _standingVector(),
        angles: _angles(leftKnee: 176, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Step your feet wider'));
      expect(result.feedbackMessages, contains('Fold your torso sideways'));
      expect(
        result.feedbackMessages,
        contains('Reach one hand down and the other up'),
      );
      expect(result.applyToScore(95), 52);
    });

    test('passes mirrored Triangle with a side fold and one hand low', () {
      final result = service.evaluate(
        poseKey: 'triangle',
        normalizedVector: PoseMirrorService.mirrorVector(_triangleVector()),
        angles: _angles(leftKnee: 175, rightKnee: 174),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('does not gate Tree or High Lunge', () {
      final tree = service.evaluate(
        poseKey: 'tree',
        normalizedVector: null,
        angles: const <String, double>{},
        scoreThreshold: 60,
      );
      final highLunge = service.evaluate(
        poseKey: 'high lunge',
        normalizedVector: null,
        angles: const <String, double>{},
        scoreThreshold: 60,
      );

      expect(tree.passes, isTrue);
      expect(tree.scoreCap, isNull);
      expect(highLunge.passes, isTrue);
      expect(highLunge.scoreCap, isNull);
    });
  });
}

Map<String, double> _angles({
  double leftKnee = 175,
  double rightKnee = 175,
  double leftElbow = 170,
  double rightElbow = 170,
}) {
  return <String, double>{
    'leftKnee': leftKnee,
    'rightKnee': rightKnee,
    'leftElbow': leftElbow,
    'rightElbow': rightElbow,
  };
}

List<double> _chairVector({double rightWristY = -1.80}) {
  return _vector(<(double, double)>[
    (-0.35, -1.00),
    (0.35, -1.00),
    (-0.40, -1.35),
    (0.40, -1.35),
    (-0.45, -1.80),
    (0.45, rightWristY),
    (-0.20, 0.00),
    (0.20, 0.00),
    (-0.35, 0.65),
    (0.35, 0.65),
    (-0.42, 1.30),
    (0.42, 1.30),
  ]);
}

List<double> _goddessVector({double kneeY = 0.32}) {
  return _vector(<(double, double)>[
    (-0.25, -1.00),
    (0.25, -1.00),
    (-0.52, -0.88),
    (0.52, -0.88),
    (-0.53, -1.15),
    (0.53, -1.15),
    (-0.16, 0.00),
    (0.16, 0.00),
    (-0.65, kneeY),
    (0.65, kneeY),
    (-0.66, 0.98),
    (0.66, 0.98),
  ]);
}

List<double> _halfMoonVector({double ankleYDiff = 0.50}) {
  return _vector(<(double, double)>[
    (-0.30, 0.10),
    (-0.25, 0.40),
    (-0.28, -0.05),
    (-0.24, 0.56),
    (-0.30, -0.22),
    (-0.25, 0.75),
    (0.02, -0.06),
    (-0.02, 0.06),
    (0.34, 0.22),
    (-0.12, 0.52),
    (0.65, 0.46),
    (-0.25, 0.46 + ankleYDiff),
  ]);
}

List<double> _warrior2Vector({
  double leftWristY = -1.00,
  double rightWristY = -1.00,
}) {
  return _vector(<(double, double)>[
    (-0.20, -1.00),
    (0.20, -1.00),
    (-0.48, -1.00),
    (0.48, -1.00),
    (-0.78, leftWristY),
    (0.78, rightWristY),
    (-0.12, 0.00),
    (0.12, 0.00),
    (-0.50, 0.34),
    (0.50, 0.36),
    (-0.68, 0.92),
    (0.68, 0.92),
  ]);
}

List<double> _triangleVector() {
  return _vector(<(double, double)>[
    (-0.27, -0.68),
    (-0.41, -0.33),
    (-0.18, -0.95),
    (-0.49, -0.08),
    (-0.15, -1.20),
    (-0.60, 0.15),
    (0.11, -0.04),
    (-0.11, 0.04),
    (0.41, 0.73),
    (-0.49, 0.81),
    (0.67, 1.55),
    (-0.79, 1.62),
  ]);
}

List<double> _standingVector() {
  return _vector(<(double, double)>[
    (-0.35, -1.00),
    (0.35, -1.00),
    (-0.45, -0.45),
    (0.45, -0.45),
    (-0.45, 0.10),
    (0.45, 0.10),
    (-0.20, 0.00),
    (0.20, 0.00),
    (-0.22, 1.00),
    (0.22, 1.00),
    (-0.24, 1.95),
    (0.24, 1.95),
  ]);
}

List<double> _vector(List<(double, double)> points) {
  return <double>[
    for (final point in points) ...<double>[point.$1, point.$2],
  ];
}

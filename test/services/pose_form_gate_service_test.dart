import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/pose_landmark_model.dart';
import 'package:zenpose/services/pose_form_gate_service.dart';
import 'package:zenpose/services/pose_mirror_service.dart';

const double _imageHeight = 1000.0;

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

    test('passes Chair when one knee angle is noisy but body is lowered', () {
      final result = service.evaluate(
        poseKey: 'chair',
        normalizedVector: _chairVector(),
        angles: _angles(leftKnee: 148, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Chair when knees are not bent', () {
      final result = service.evaluate(
        poseKey: 'chair',
        normalizedVector: _chairVector(),
        angles: _angles(leftKnee: 176, rightKnee: 177),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Bend your knees more'));
      expect(result.applyToScore(90), 52);
    });

    test('caps Chair when arms are raised but body is not lowered', () {
      final result = service.evaluate(
        poseKey: 'chair',
        normalizedVector: _chairVector(kneeY: 1.02),
        angles: _angles(leftKnee: 148, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Lower your hips like sitting'));
      expect(result.applyToScore(90), 52);
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

    test('caps Goddess when stance is wide but knees are not open enough', () {
      final result = service.evaluate(
        poseKey: 'goddess',
        normalizedVector: _goddessVector(kneeX: 0.42, kneeY: 0.36),
        angles: _angles(leftKnee: 124, rightKnee: 126),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
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

    test('caps Down Dog when the user is in a plank-like line', () {
      final result = service.evaluate(
        poseKey: 'downdog',
        normalizedVector: _plankVector(),
        rawLandmarks: _floorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 165,
          rightKnee: 179,
          leftElbow: 159,
          rightElbow: 178,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Lift your hips higher'));
      expect(
        result.feedbackMessages,
        contains('Fold into an inverted V shape'),
      );
      expect(result.applyToScore(92), 52);
    });

    test('passes Down Dog with high hips and long limbs', () {
      final result = service.evaluate(
        poseKey: 'downdog',
        normalizedVector: _downDogVector(),
        rawLandmarks: _floorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 163,
          rightKnee: 178,
          leftElbow: 176,
          rightElbow: 177,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Down Dog when floor evidence is too high in frame', () {
      final result = service.evaluate(
        poseKey: 'downdog',
        normalizedVector: _downDogVector(),
        rawLandmarks: _standingFloorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 163,
          rightKnee: 178,
          leftElbow: 176,
          rightElbow: 177,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Move down onto the floor/mat'));
      expect(result.applyToScore(92), 52);
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

    test('caps High Lunge when only both arms are raised', () {
      final result = service.evaluate(
        poseKey: 'high lunge',
        normalizedVector: _highLungeArmsOnlyVector(),
        angles: _angles(leftKnee: 176, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Bend your front knee forward'));
      expect(result.applyToScore(88), 52);
    });

    test('passes High Lunge when one front knee is bent forward', () {
      final result = service.evaluate(
        poseKey: 'high lunge',
        normalizedVector: _highLungeVector(),
        angles: _angles(leftKnee: 148, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Plank when hips are lifted into Down Dog', () {
      final result = service.evaluate(
        poseKey: 'plank',
        normalizedVector: _downDogVector(),
        rawLandmarks: _floorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 163,
          rightKnee: 178,
          leftElbow: 176,
          rightElbow: 177,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(
        result.feedbackMessages,
        contains('Keep shoulders, hips, and heels in one line'),
      );
      expect(result.applyToScore(89), 52);
    });

    test('passes Plank with a straight shoulder-hip-heel line', () {
      final result = service.evaluate(
        poseKey: 'plank',
        normalizedVector: _plankVector(),
        rawLandmarks: _floorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 165,
          rightKnee: 179,
          leftElbow: 159,
          rightElbow: 178,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('passes Plank with softer beginner alignment on the floor', () {
      final result = service.evaluate(
        poseKey: 'plank',
        normalizedVector: _plankVector(),
        rawLandmarks: _floorLandmarks(wristY: 470, ankleY: 540),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 148,
          rightKnee: 151,
          leftElbow: 140,
          rightElbow: 146,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Plank when the user is upright instead of on the floor', () {
      final result = service.evaluate(
        poseKey: 'plank',
        normalizedVector: _plankVector(),
        rawLandmarks: _standingFloorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(
          leftKnee: 165,
          rightKnee: 179,
          leftElbow: 159,
          rightElbow: 178,
        ),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Move down onto the floor/mat'));
      expect(result.applyToScore(96), 52);
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

    test('caps Cobra when the user stays in Plank', () {
      final result = service.evaluate(
        poseKey: 'cobra',
        normalizedVector: _plankVector(),
        rawLandmarks: _floorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Lift your chest higher'));
      expect(
        result.feedbackMessages,
        contains('Keep your hips low on the mat'),
      );
      expect(result.applyToScore(86), 52);
    });

    test('passes Cobra with lifted chest and hips low', () {
      final result = service.evaluate(
        poseKey: 'cobra',
        normalizedVector: _cobraVector(),
        rawLandmarks: _cobraFloorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
    });

    test('caps Cobra when lower body is not near the floor', () {
      final result = service.evaluate(
        poseKey: 'cobra',
        normalizedVector: _cobraVector(),
        rawLandmarks: _standingFloorLandmarks(),
        imageHeight: _imageHeight,
        angles: _angles(),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(result.feedbackMessages, contains('Move down onto the floor/mat'));
      expect(result.applyToScore(90), 52);
    });

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

    test('caps Tree when both feet stay on the ground', () {
      final result = service.evaluate(
        poseKey: 'tree',
        normalizedVector: _standingVector(),
        angles: _angles(leftKnee: 176, rightKnee: 177),
        scoreThreshold: 60,
      );

      expect(result.passes, isFalse);
      expect(
        result.feedbackMessages,
        contains('Lift one foot onto your inner leg'),
      );
      expect(
        result.feedbackMessages,
        contains('Open one knee out to the side'),
      );
      expect(result.applyToScore(92), 52);
    });

    test('passes Tree when one knee opens and feet are close', () {
      final result = service.evaluate(
        poseKey: 'tree',
        normalizedVector: _treeVector(),
        angles: _angles(leftKnee: 92, rightKnee: 176),
        scoreThreshold: 60,
      );

      expect(result.passes, isTrue);
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

List<double> _chairVector({double rightWristY = -1.80, double kneeY = 0.65}) {
  return _vector(<(double, double)>[
    (-0.35, -1.00),
    (0.35, -1.00),
    (-0.40, -1.35),
    (0.40, -1.35),
    (-0.45, -1.80),
    (0.45, rightWristY),
    (-0.20, 0.00),
    (0.20, 0.00),
    (-0.35, kneeY),
    (0.35, kneeY),
    (-0.42, 1.30),
    (0.42, 1.30),
  ]);
}

List<double> _goddessVector({double kneeX = 0.65, double kneeY = 0.32}) {
  return _vector(<(double, double)>[
    (-0.25, -1.00),
    (0.25, -1.00),
    (-0.52, -0.88),
    (0.52, -0.88),
    (-0.53, -1.15),
    (0.53, -1.15),
    (-0.16, 0.00),
    (0.16, 0.00),
    (-kneeX, kneeY),
    (kneeX, kneeY),
    (-0.66, 0.98),
    (0.66, 0.98),
  ]);
}

List<double> _downDogVector() {
  return _vector(<(double, double)>[
    (0.55, 0.13),
    (0.46, -0.02),
    (0.53, 0.78),
    (0.39, 0.74),
    (0.51, 1.36),
    (0.29, 1.42),
    (0.09, 0.04),
    (-0.09, -0.04),
    (0.41, 0.70),
    (-0.69, 0.83),
    (0.52, 1.39),
    (-1.21, 1.60),
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

List<double> _highLungeArmsOnlyVector() {
  return _vector(<(double, double)>[
    (-0.35, -1.00),
    (0.35, -1.00),
    (-0.35, -1.48),
    (0.35, -1.48),
    (-0.35, -1.92),
    (0.35, -1.92),
    (-0.20, 0.00),
    (0.20, 0.00),
    (-0.22, 1.00),
    (0.22, 1.00),
    (-0.24, 1.80),
    (0.24, 1.80),
  ]);
}

List<double> _highLungeVector() {
  return _vector(<(double, double)>[
    (0.00, -0.99),
    (-0.01, -0.99),
    (0.00, -1.49),
    (-0.00, -1.51),
    (0.03, -1.93),
    (0.01, -1.94),
    (-0.00, 0.01),
    (0.00, -0.01),
    (-0.30, 0.30),
    (0.05, 0.10),
    (-0.62, 0.66),
    (0.02, 0.68),
  ]);
}

List<double> _plankVector() {
  return _vector(<(double, double)>[
    (-0.01, -0.51),
    (-0.17, -0.35),
    (0.10, -0.55),
    (-0.22, -0.10),
    (0.17, -0.60),
    (-0.26, 0.11),
    (0.07, -0.04),
    (-0.07, 0.04),
    (0.06, 0.35),
    (0.03, 0.43),
    (0.01, 0.55),
    (0.10, 0.72),
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

List<double> _cobraVector() {
  return _vector(<(double, double)>[
    (0.04, -0.90),
    (-0.02, -0.92),
    (0.05, -0.15),
    (-0.02, -0.16),
    (0.06, 0.24),
    (0.01, 0.23),
    (0.02, 0.01),
    (-0.02, -0.01),
    (0.03, 0.16),
    (-0.08, 0.11),
    (0.02, 0.16),
    (-0.14, 0.12),
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

List<double> _treeVector() {
  return _vector(<(double, double)>[
    (0.38, -0.99),
    (-0.37, -1.00),
    (0.54, -1.12),
    (-0.55, -1.12),
    (0.20, -1.46),
    (-0.22, -1.45),
    (0.24, -0.00),
    (-0.24, 0.00),
    (0.60, 0.55),
    (-0.49, 0.59),
    (0.08, 0.88),
    (-0.05, 1.01),
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

List<PoseLandmark> _floorLandmarks({
  double wristY = 700,
  double hipY = 620,
  double kneeY = 720,
  double ankleY = 800,
}) {
  final landmarks = _emptyLandmarks();
  landmarks[15] = _landmark(y: wristY);
  landmarks[16] = _landmark(y: wristY);
  landmarks[23] = _landmark(y: hipY);
  landmarks[24] = _landmark(y: hipY);
  landmarks[25] = _landmark(y: kneeY);
  landmarks[26] = _landmark(y: kneeY);
  landmarks[27] = _landmark(y: ankleY);
  landmarks[28] = _landmark(y: ankleY);
  return landmarks;
}

List<PoseLandmark> _cobraFloorLandmarks() {
  return _floorLandmarks(wristY: 590, hipY: 560, kneeY: 590, ankleY: 640);
}

List<PoseLandmark> _standingFloorLandmarks() {
  return _floorLandmarks(wristY: 340, hipY: 420, kneeY: 560, ankleY: 820);
}

List<PoseLandmark> _emptyLandmarks() {
  return List<PoseLandmark>.generate(
    33,
    (_) => const PoseLandmark(x: 0, y: 0, z: 0, confidence: 0),
  );
}

PoseLandmark _landmark({required double y}) {
  return PoseLandmark(x: 100, y: y, z: 0, confidence: 1);
}

List<double> _vector(List<(double, double)> points) {
  return <double>[
    for (final point in points) ...<double>[point.$1, point.$2],
  ];
}

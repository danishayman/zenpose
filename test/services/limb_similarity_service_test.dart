import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/services/limb_similarity_service.dart';

void main() {
  group('LimbSimilarityService', () {
    test('orders feedback by lowest segment score first', () {
      final service = LimbSimilarityService();

      final feedback = service.generateFeedback(const <String, double>{
        'Left Arm': 45,
        'Right Arm': 65,
        'Left Leg': 20,
        'Right Leg': 55,
        'Torso': 35,
      });

      expect(feedback, <String>[
        'Straighten your left leg',
        'Adjust torso alignment',
        'Raise your left arm',
        'Straighten your right leg',
        'Raise your right arm',
      ]);
    });
  });
}

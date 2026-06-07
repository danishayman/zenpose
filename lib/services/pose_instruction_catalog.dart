import '../models/pose_template.dart';

class PoseInstructionCatalog {
  static const List<String> _fallbackSteps = <String>[
    'Stand where your full body is visible.',
    'Move slowly into the pose.',
    'Keep breathing and stay steady.',
    'Open the camera when you feel ready.',
  ];

  static const Map<String, List<String>> _stepsByKey = <String, List<String>>{
    'chair': <String>[
      'Stand tall.',
      'Bend your knees.',
      'Push hips back like sitting.',
      'Keep chest lifted.',
    ],
    'downdog': <String>[
      'Start on hands and knees.',
      'Lift hips up.',
      'Straighten legs gently.',
      'Press heels down.',
    ],
    'goddess': <String>[
      'Step feet wide.',
      'Turn toes out.',
      'Bend knees over toes.',
      'Keep back straight.',
    ],
    'half-moon': <String>[
      'Stand on one leg.',
      'Place one hand down.',
      'Lift the back leg.',
      'Open your chest sideways.',
    ],
    'plank': <String>[
      'Place hands under shoulders.',
      'Step both feet back.',
      'Keep body in one line.',
      'Tighten your core.',
    ],
    'tree': <String>[
      'Stand tall.',
      'Place one foot on inner leg.',
      'Bring hands together.',
      'Keep your gaze steady.',
    ],
    'warrior2': <String>[
      'Step feet wide.',
      'Turn front foot forward.',
      'Bend front knee.',
      'Stretch arms out.',
    ],
    'cobra': <String>[
      'Lie on your belly.',
      'Place hands under shoulders.',
      'Lift chest gently.',
      'Keep elbows close.',
    ],
    'high lunge': <String>[
      'Step one foot forward.',
      'Bend front knee.',
      'Keep back leg straight.',
      'Lift chest and arms.',
    ],
    'triangle': <String>[
      'Step feet wide.',
      'Reach over front leg.',
      'Place hand on shin or floor.',
      'Open chest upward.',
    ],
  };

  static List<String> stepsFor(PoseTemplate template) {
    return _stepsByKey[template.templateKey.trim().toLowerCase()] ??
        _fallbackSteps;
  }
}

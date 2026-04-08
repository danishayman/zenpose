import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../theme/zen_theme.dart';
import 'pose_thumbnail_image.dart';

/// Difficulty level label for a yoga pose.
enum PoseDifficulty { beginner, intermediate, advanced }

extension PoseDifficultyX on PoseDifficulty {
  String get label => switch (this) {
    PoseDifficulty.beginner => 'Beginner',
    PoseDifficulty.intermediate => 'Intermediate',
    PoseDifficulty.advanced => 'Advanced',
  };

  Color get color => switch (this) {
    PoseDifficulty.beginner => ZenColors.success,
    PoseDifficulty.intermediate => ZenColors.warning,
    PoseDifficulty.advanced => ZenColors.error,
  };

  Color get bgColor => switch (this) {
    PoseDifficulty.beginner => ZenColors.successLight,
    PoseDifficulty.intermediate => ZenColors.warningLight,
    PoseDifficulty.advanced => ZenColors.errorLight,
  };
}

/// Infer difficulty from the pose name heuristically.
PoseDifficulty inferDifficulty(String poseName) {
  final lower = poseName.toLowerCase();
  if (lower.contains('warrior') ||
      lower.contains('crow') ||
      lower.contains('headstand') ||
      lower.contains('handstand') ||
      lower.contains('scorpion') ||
      lower.contains('wheel') ||
      lower.contains('downdog') ||
      lower.contains('down dog') ||
      lower.contains('half-moon') ||
      lower.contains('half moon') ||
      lower.contains('halfmoon') ||
      lower.contains('lotus')) {
    return PoseDifficulty.advanced;
  }
  if (lower.contains('triangle') ||
      lower.contains('eagle') ||
      lower.contains('boat') ||
      lower.contains('bridge') ||
      lower.contains('plank') ||
      lower.contains('chair')) {
    return PoseDifficulty.intermediate;
  }
  return PoseDifficulty.beginner;
}

/// Yoga pose card used in the Practice grid/list.
///
/// Shows pose name, static thumbnail, and a difficulty badge.
class ZenPoseCard extends StatelessWidget {
  final PoseTemplate template;
  final VoidCallback onTap;
  final bool compact;

  const ZenPoseCard({
    super.key,
    required this.template,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final difficulty = inferDifficulty(template.name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ZenDecor.elevatedCard(),
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: compact ? _compactLayout(difficulty) : _normalLayout(difficulty),
      ),
    );
  }

  Widget _thumbnail({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    return PoseThumbnailImage(
      template: template,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  Widget _difficultyBadge(PoseDifficulty difficulty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: difficulty.bgColor,
        borderRadius: ZenDecor.pillRadius,
      ),
      child: Text(
        difficulty.label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: difficulty.color,
        ),
      ),
    );
  }

  Widget _normalLayout(PoseDifficulty difficulty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumbnail(
          width: double.infinity,
          height: 92,
          borderRadius: BorderRadius.circular(14),
        ),
        const SizedBox(height: 12),
        Text(
          template.name,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ZenColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _difficultyBadge(difficulty),
      ],
    );
  }

  Widget _compactLayout(PoseDifficulty difficulty) {
    return Row(
      children: [
        _thumbnail(
          width: 56,
          height: 56,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ZenColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _difficultyBadge(difficulty),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: ZenColors.textMuted),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/badge_progress_snapshot.dart';
import '../theme/zen_theme.dart';

class ZenBadgePalette {
  final List<Color> gradient;
  final Color iconColor;
  final Color valueColor;

  const ZenBadgePalette({
    required this.gradient,
    required this.iconColor,
    required this.valueColor,
  });
}

class ZenBadgeVisuals {
  static IconData iconFor(BadgeProgressSnapshot snapshot) {
    final id = snapshot.definition.id;
    if (id.contains('streak')) {
      return Icons.local_fire_department_rounded;
    }
    if (id.contains('score')) {
      return Icons.track_changes_rounded;
    }
    if (id == 'first_completion') {
      return Icons.spa_rounded;
    }
    return Icons.self_improvement_rounded;
  }

  static ZenBadgePalette paletteFor(BadgeProgressSnapshot snapshot) {
    return switch (snapshot.definition.criteriaType) {
      'streak' => const ZenBadgePalette(
        gradient: <Color>[Color(0xFFE2A24D), Color(0xFFC47A1D)],
        iconColor: Colors.white,
        valueColor: Colors.white,
      ),
      'score' => const ZenBadgePalette(
        gradient: <Color>[Color(0xFF5EAEB5), Color(0xFF2F7D83)],
        iconColor: Colors.white,
        valueColor: Colors.white,
      ),
      _ => const ZenBadgePalette(
        gradient: <Color>[ZenColors.forest, ZenColors.teal],
        iconColor: Colors.white,
        valueColor: Colors.white,
      ),
    };
  }
}

class ZenHexBadgeMedallion extends StatelessWidget {
  final BadgeProgressSnapshot snapshot;
  final double size;

  const ZenHexBadgeMedallion({
    super.key,
    required this.snapshot,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ZenBadgeVisuals.paletteFor(snapshot);
    final icon = ZenBadgeVisuals.iconFor(snapshot);
    final valueText = snapshot.targetValue.round().toString();
    final isUnlocked = snapshot.isUnlocked;
    final lockedForeground = ZenColors.forest.withValues(alpha: 0.90);

    return SizedBox(
      width: size,
      height: size * 1.06,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _HexagonClipper(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: isUnlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: palette.gradient,
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          ZenColors.sage200.withValues(alpha: 0.92),
                          ZenColors.sage.withValues(alpha: 0.62),
                        ],
                      ),
                border: Border.all(
                  color: isUnlocked
                      ? Colors.white.withValues(alpha: 0.28)
                      : ZenColors.surface2,
                  width: 1.4,
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.28,
            child: Icon(
              icon,
              size: size * 0.32,
              color: isUnlocked ? palette.iconColor : lockedForeground,
            ),
          ),
          Positioned(
            bottom: size * 0.01,
            child: Text(
              valueText,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: size * 0.30,
                color: isUnlocked ? palette.valueColor : lockedForeground,
                height: 1.0,
                shadows: isUnlocked
                    ? null
                    : <Shadow>[
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.45),
                          blurRadius: 1.6,
                        ),
                      ],
              ),
            ),
          ),
          if (!isUnlocked)
            Positioned(
              top: size * 0.02,
              right: size * 0.10,
              child: Container(
                width: size * 0.20,
                height: size * 0.20,
                decoration: BoxDecoration(
                  color: ZenColors.surface1,
                  shape: BoxShape.circle,
                  border: Border.all(color: ZenColors.surface2),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: ZenColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.08;
    final points = <Offset>[
      Offset(w * 0.5, 0),
      Offset(w - r, h * 0.25),
      Offset(w - r, h * 0.75),
      Offset(w * 0.5, h),
      Offset(r, h * 0.75),
      Offset(r, h * 0.25),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

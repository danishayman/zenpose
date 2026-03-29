import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

/// A reusable metric tile showing a [label] above a large [value].
///
/// Used in the Home snapshot row, Progress dashboard, and Profile screen.
class ZenStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const ZenStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? ZenColors.forest;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZenDecor.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor ?? ZenColors.surface1,
            borderRadius: ZenDecor.cardRadius,
            boxShadow: [
              BoxShadow(
                color: ZenColors.earth.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 18),
                const SizedBox(height: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ZenColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

/// Section header with a bold [title] and an optional [subtitle] below.
///
/// Optionally shows a [trailing] widget (e.g., "See all" link).
class ZenSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ZenSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle case final subtitleText?) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small dot-divider pill used as a visual separator between metadata chips.
class ZenDot extends StatelessWidget {
  const ZenDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ZenColors.textMuted,
      ),
    );
  }
}

/// A small rounded chip for metadata like difficulty, duration, etc.
class ZenChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;

  const ZenChip({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? ZenColors.forest;
    final bg = backgroundColor ?? ZenColors.sage100;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: ZenDecor.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

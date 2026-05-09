import 'package:flutter/material.dart';

import '../models/user_rank.dart';
import '../theme/zen_theme.dart';

class RankUpDialog extends StatelessWidget {
  final UserRankTier rank;
  final int xpAfter;

  const RankUpDialog({super.key, required this.rank, required this.xpAfter});

  static Future<void> showIfRankedUp(
    BuildContext context, {
    required bool didRankUp,
    required UserRankTier rankAfter,
    required int xpAfter,
  }) async {
    if (!didRankUp) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RankUpDialog(rank: rankAfter, xpAfter: xpAfter),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Rank Up!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            rank.badgeAssetPath,
            width: 88,
            height: 88,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.workspace_premium_rounded,
              size: 72,
              color: ZenColors.forest,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rank.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: ZenColors.forest,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total XP: $xpAfter',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

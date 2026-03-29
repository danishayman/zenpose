import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../services/pose_demo_asset_resolver.dart';
import '../theme/zen_theme.dart';

class PoseThumbnailImage extends StatelessWidget {
  final PoseTemplate template;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const PoseThumbnailImage({
    super.key,
    required this.template,
    this.width,
    this.height = 220,
    this.borderRadius = ZenDecor.cardRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = PoseDemoAssetResolver.thumbnailPathForTemplate(template);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: Image.asset(
          assetPath,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZenColors.sage100, ZenColors.teal100],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.self_improvement_rounded,
          size: 56,
          color: ZenColors.forest,
        ),
      ),
    );
  }
}

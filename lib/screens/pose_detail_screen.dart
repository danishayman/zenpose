import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_pose_card.dart';
import '../widgets/zen_primary_button.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/pose_thumbnail_image.dart';
import 'main_screen.dart';
import 'pre_session_intro_screen.dart';

/// Pose Detail screen — shown between the Practice grid and the live session.
///
/// Shows the pose name, static thumbnail, description, difficulty pill,
/// and a "Start Practice" CTA that launches [PreSessionIntroScreen].
class PoseDetailScreen extends StatelessWidget {
  final PoseTemplate template;
  final Widget Function(PoseTemplate template)? sessionScreenBuilder;

  const PoseDetailScreen({
    super.key,
    required this.template,
    this.sessionScreenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final difficulty = inferDifficulty(template.name);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: ZenColors.surface1,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: ZenColors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 56),
                    // Illustration hero
                    _buildIllustration(template, difficulty),
                    const SizedBox(height: 24),

                    // Difficulty & category chips
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: difficulty.bgColor,
                            borderRadius: ZenDecor.pillRadius,
                          ),
                          child: Text(
                            difficulty.label,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: difficulty.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: ZenColors.sage100,
                            borderRadius: ZenDecor.pillRadius,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: ZenColors.forest,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '45s hold',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ZenColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pose name
                    Text(
                      template.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      template.description.isNotEmpty
                          ? template.description
                          : 'Hold this pose steadily while the AI evaluates '
                                'your alignment in real time. Focus on breathing '
                                'and maintaining a stable, balanced position.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),

                    // Tips card
                    _buildTipsCard(context),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: ZenColors.surface0,
                boxShadow: [
                  BoxShadow(
                    color: ZenColors.bark.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ZenPrimaryButton(
                label: 'Start Practice',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreSessionIntroScreen(
                      template: template,
                      destinationBuilder: (_, poseTemplate) =>
                          sessionScreenBuilder?.call(poseTemplate) ??
                          MainScreen(poseTemplate: poseTemplate),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(PoseTemplate template, PoseDifficulty difficulty) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: ZenDecor.cardRadius,
        border: Border.all(
          color: difficulty.color.withValues(alpha: 0.20),
          width: 1.2,
        ),
      ),
      child: PoseThumbnailImage(
        template: template,
        height: 220,
        borderRadius: ZenDecor.cardRadius,
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ZenDecor.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(title: 'Tips', subtitle: 'For best results'),
          const SizedBox(height: 12),
          _tip(
            context,
            Icons.space_bar_rounded,
            'Make sure your full body is visible to the camera.',
          ),
          _tip(
            context,
            Icons.wb_sunny_outlined,
            'Good lighting improves detection accuracy.',
          ),
          _tip(
            context,
            Icons.accessibility_new_rounded,
            'Hold each pose steadily for the timer to count.',
          ),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ZenColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

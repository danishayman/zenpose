import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../services/pose_template_service.dart';
import '../theme/zen_theme.dart';
import 'main_screen.dart';

/// Library tab showing available yoga poses.
class PoseSelectionScreen extends StatefulWidget {
  const PoseSelectionScreen({super.key});

  @override
  State<PoseSelectionScreen> createState() => _PoseSelectionScreenState();
}

class _PoseSelectionScreenState extends State<PoseSelectionScreen> {
  final PoseTemplateService _templateService = PoseTemplateService();
  late final Future<List<PoseTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = _templateService.loadTemplates();
  }

  void _openPose(PoseTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(poseTemplate: template)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<PoseTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load poses: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final templates = snapshot.data ?? const <PoseTemplate>[];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: templates.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader();
              }
              final template = templates[index - 1];
              return _PoseCard(
                template: template,
                onTap: () => _openPose(template),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pose Library',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose one pose for focused form practice.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ZenColors.earth),
          ),
        ],
      ),
    );
  }
}

class _PoseCard extends StatelessWidget {
  final PoseTemplate template;
  final VoidCallback onTap;

  const _PoseCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: ZenDecor.softCard(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZenColors.sage.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.self_improvement,
                color: ZenColors.forest,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.description.isNotEmpty
                        ? template.description
                        : 'Hold steady and align your posture with guided feedback.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: ZenColors.earth),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ZenColors.earth),
          ],
        ),
      ),
    );
  }
}

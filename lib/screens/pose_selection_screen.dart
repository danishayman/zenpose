import 'package:flutter/material.dart';
import '../models/pose_template.dart';
import '../services/pose_template_service.dart';
import 'main_screen.dart';

/// Pose Selection Screen — the entry point of the Pose Library system.
///
/// Displays a list of available yoga poses loaded from
/// `assets/pose_templates.json`.  When the user taps a pose the app
/// navigates to [MainScreen] (the camera evaluation screen), passing
/// the selected [PoseTemplate] so the camera can score against that
/// specific reference vector.
///
/// Architecture:
///   PoseSelectionScreen  ──(tap)──►  MainScreen(poseTemplate)
///       ↑ loads from                    ↑ uses meanVector as
///   PoseTemplateService              referenceVector for scoring
class PoseSelectionScreen extends StatefulWidget {
  const PoseSelectionScreen({super.key});

  @override
  State<PoseSelectionScreen> createState() => _PoseSelectionScreenState();
}

class _PoseSelectionScreenState extends State<PoseSelectionScreen> {
  /// Service responsible for loading & caching templates from JSON.
  final PoseTemplateService _templateService = PoseTemplateService();

  /// Future that resolves to the list of available pose templates.
  late final Future<List<PoseTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    // Kick off the async load once, cache the Future for FutureBuilder.
    _templatesFuture = _templateService.loadTemplates();
  }

  // ── Navigation ──

  /// Push the camera screen with the selected pose template.
  void _onPoseSelected(PoseTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(poseTemplate: template)),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ZenPose — Pose Library'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: FutureBuilder<List<PoseTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          // Loading state.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // Error state.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load poses:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Success — build the list.
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return const Center(
              child: Text(
                'No pose templates found.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _PoseCard(
                template: template,
                onTap: () => _onPoseSelected(template),
              );
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Private widget — individual pose card in the list.
// ──────────────────────────────────────────────────────────────────────────────

/// A tappable card that shows the pose [name] and [description].
class _PoseCard extends StatelessWidget {
  final PoseTemplate template;
  final VoidCallback onTap;

  const _PoseCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Leading icon — yoga pose silhouette.
              const Icon(
                Icons.self_improvement,
                color: Colors.cyanAccent,
                size: 36,
              ),
              const SizedBox(width: 16),
              // Pose name + description.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing chevron.
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

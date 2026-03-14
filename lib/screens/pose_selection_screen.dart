import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../services/pose_template_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_pose_card.dart';
import '../widgets/zen_section_header.dart';
import 'pose_detail_screen.dart';

/// Practice tab — shows all available yoga poses in a searchable grid.
class PoseSelectionScreen extends StatefulWidget {
  const PoseSelectionScreen({super.key});

  @override
  State<PoseSelectionScreen> createState() => _PoseSelectionScreenState();
}

class _PoseSelectionScreenState extends State<PoseSelectionScreen> {
  final PoseTemplateService _templateService = PoseTemplateService();
  late final Future<List<PoseTemplate>> _templatesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _templatesFuture = _templateService.loadTemplates();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPose(PoseTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoseDetailScreen(template: template)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<PoseTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ZenPageLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Failed to load poses: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final all = snapshot.data ?? <PoseTemplate>[];
          final filtered = _query.isEmpty
              ? all
              : all
                  .where((t) => t.name.toLowerCase().contains(_query))
                  .toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: filtered.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmpty())
                    : SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ZenPoseCard(
                            template: filtered[i],
                            onTap: () => _openPose(filtered[i]),
                          ),
                          childCount: filtered.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.88,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practice',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a pose for focused form training.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search poses…',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: ZenColors.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const ZenSectionHeader(title: 'All Poses'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: ZenColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No poses match "$_query"',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

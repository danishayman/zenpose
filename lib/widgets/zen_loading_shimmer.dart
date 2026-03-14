import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

/// Displays a shimmer-animated placeholder card while async data loads.
///
/// Replaces bare [CircularProgressIndicator] for a polished loading state.
class ZenLoadingShimmer extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ZenLoadingShimmer({
    super.key,
    this.height = 120,
    this.width,
    this.borderRadius,
  });

  @override
  State<ZenLoadingShimmer> createState() => _ZenLoadingShimmerState();
}

class _ZenLoadingShimmerState extends State<ZenLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? ZenDecor.cardRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.4).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.4).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFFEDE8DF),
                Color(0xFFF8F4EC),
                Color(0xFFEDE8DF),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A full-screen or section loading state with stacked shimmer cards.
class ZenPageLoadingShimmer extends StatelessWidget {
  const ZenPageLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ZenSpacing.pagePadding,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const ZenLoadingShimmer(height: 48, width: 200),
          const SizedBox(height: 20),
          const ZenLoadingShimmer(height: 160),
          const SizedBox(height: 14),
          const ZenLoadingShimmer(height: 100),
          const SizedBox(height: 14),
          const ZenLoadingShimmer(height: 220),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 0), child: w)).toList(),
      ),
    );
  }
}

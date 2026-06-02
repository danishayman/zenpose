import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<_OnboardingItem> _items = <_OnboardingItem>[
    _OnboardingItem(
      icon: Icons.self_improvement_rounded,
      title: 'Welcome to ZenPose',
      subtitle:
          'Build better yoga form with real-time camera guidance and focused practice.',
    ),
    _OnboardingItem(
      icon: Icons.camera_alt_rounded,
      title: 'Practice With Live Feedback',
      subtitle:
          'Track your posture as you move and get correction cues to improve safely.',
    ),
    _OnboardingItem(
      icon: Icons.insights_rounded,
      title: 'Grow With Consistency',
      subtitle:
          'Stay motivated with streaks, stats, and challenge progress in one place.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentIndex == _items.length - 1) {
      widget.onFinish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onFinish,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _OnboardingPage(item: item);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? ZenColors.forest
                            : ZenColors.sage200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _currentIndex == _items.length - 1
                          ? 'Get Started'
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingItem item;

  const _OnboardingPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZenColors.sage100,
                ),
                child: Icon(item.icon, size: 46, color: ZenColors.forest),
              ),
              const SizedBox(height: 24),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: ZenColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

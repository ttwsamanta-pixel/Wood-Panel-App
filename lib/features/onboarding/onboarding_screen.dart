import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/app_preferences_repository.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;

  static const slides = [
    (
      'Your Global Source for Wood And Panel News',
      'Follow market movement, technology, products, and company updates from one premium source.',
      'https://images.unsplash.com/photo-1618221118493-9cfa1a1c00da?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Expert Interviews & Industry Voices',
      'Follow decision makers shaping wood, panel, furniture and machinery markets.',
      'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Digital Magazines and Reports',
      'Read issues, save downloads, and keep industry reports close at hand.',
      'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Events, Trends, and Opportunities',
      'Stay ready for exhibitions, partnerships, industry launches, and regional growth stories.',
      'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  const WPLogo(height: 34),
                  const Spacer(),
                  TextButton(onPressed: _finishOnboarding, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              WPImage(url: slide.$3, width: double.infinity, borderRadius: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0x55000000)],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 14,
                                bottom: 14,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: WPLogo(height: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(slide.$1, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(
                          slide.$2,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Row(
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Container(
                      width: i == _page ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.copper : AppColors.line,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  const Spacer(),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.copper),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () {
                      if (_page == slides.length - 1) {
                        _finishOnboarding();
                      } else {
                        _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    await ref.read(appPreferencesRepositoryProvider).setOnboardingComplete();
    if (mounted) {
      context.go('/feed');
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/app_preferences_repository.dart';
import '../../widgets/wp_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () async {
      final completed = await ref
          .read(appPreferencesRepositoryProvider)
          .hasCompletedOnboarding();
      if (mounted) {
        context.go(completed ? '/feed' : '/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _WoodGrainPainter()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: WPLogo(
                width: MediaQuery.of(context).size.width * .78,
                height: 118,
              ),
            ),
          ),
          const Positioned(
            left: 84,
            right: 84,
            bottom: 54,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(99)),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.gold,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 28; i++) {
      paint.color = Color.lerp(AppColors.brown, AppColors.gold, i / 36)!
          .withValues(alpha: .36);
      final rect = Rect.fromLTWH(-size.width * .72 + i * 10, -40 + i * 18,
          size.width * 1.8, size.height * 1.05);
      canvas.drawArc(rect, -1.0, 3.05, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

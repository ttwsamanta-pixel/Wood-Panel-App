import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/app_preferences_repository.dart';
import '../../widgets/wp_components.dart';
import 'wood_corner_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    final results = await Future.wait<dynamic>([
      ref.read(appPreferencesRepositoryProvider).hasCompletedOnboarding(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    final completed = results.first as bool;
    final prefs = await SharedPreferences.getInstance();
    final profileSeen = prefs.getBool('profile_prompt_seen_v1') ?? false;
    if (mounted) {
      context.go(!profileSeen
          ? '/welcome-profile'
          : completed
              ? '/feed'
              : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: WoodCornerBackground()),
            Center(child: WPBrandLoader(size: 188, compact: true)),
          ]),
        ));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/app_preferences_repository.dart';
import '../../widgets/wp_components.dart';

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
    if (mounted) {
      context.go(completed ? '/feed' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: WPPageLoader());
  }
}

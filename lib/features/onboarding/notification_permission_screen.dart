import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/edition/edition_navigation.dart';
import '../../widgets/wp_logo.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_prompt_seen_v1', true);
    if (mounted) context.go('/feed');
  }

  Future<void> _allow() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(editionNavigationProvider);
      await service.ready;
      await service.setEnabled(true);
      if (!mounted) return;
      if (ref.read(editionPushProvider).values.every((enabled) => enabled)) {
        await _finish();
      } else {
        setState(() => _error = ref.read(notificationStatusProvider));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to enable alerts right now. Try again or continue and enable them in Preferences.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WPLogo(height: 44),
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 58,
                  backgroundColor: colors.primary.withValues(alpha: .10),
                  child: Icon(Icons.notifications_active_outlined,
                      size: 56, color: colors.primary),
                ),
                const SizedBox(height: 28),
                Text('Stay up to date',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                const Text(
                  'Get the latest news and industry updates from Wood & Panel Europe and USA.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can manage alerts for each edition separately in Preferences at any time.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error)),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _allow,
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(_busy ? 'Enabling…' : 'Allow Notifications'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('Not Now')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

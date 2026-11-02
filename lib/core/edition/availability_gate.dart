import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/profile/preferences_page.dart' show appVersionProvider;
import '../../routing/app_router.dart';
import 'availability_screen.dart';
import 'availability.dart';
import 'edition.dart';

class AvailabilityGate extends ConsumerStatefulWidget {
  const AvailabilityGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AvailabilityGate> createState() => _AvailabilityGateState();
}

class _AvailabilityGateState extends ConsumerState<AvailabilityGate>
    with WidgetsBindingObserver {
  final _dismissed = <String>{};
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() =>
      ref.invalidate(editionConfigProvider(ref.read(editionProvider)));

  Future<void> _open(String link) async {
    try {
      if (await launchUrl(Uri.parse(link),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {/* Show a recoverable error below. */}
    if (mounted) {
      setState(() => _error = 'Could not open the store. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(activeConfigProvider);
    final control = config.availability;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final mobile =
        !kIsWeb && (ios || defaultTargetPlatform == TargetPlatform.android);
    final link = ios ? config.iosStoreUrl : config.appStoreUrl;
    final info = ref.watch(appVersionProvider).valueOrNull;
    final access = control.evaluate(
        build: int.tryParse(info?.buildNumber ?? ''),
        ios: ios,
        hasStore: mobile && link.isNotEmpty);
    final optionalKey =
        '${config.edition.name}:${ios ? control.iosLatest : control.androidLatest}';
    if (access == AccessState.available ||
        (access == AccessState.optionalUpdate &&
            _dismissed.contains(optionalKey))) {
      return widget.child;
    }
    final maintenance = access == AccessState.maintenance;
    final other =
        config.edition == Edition.europe ? Edition.usa : Edition.europe;
    return PopScope(
      canPop: false,
      child: AvailabilityScreen(
        edition: config.edition,
        access: access,
        message:
            maintenance ? control.maintenanceMessage : control.updateMessage,
        error: _error,
        onRetry: _refresh,
        onUpdate: () => _open(link),
        onOtherEdition: () {
          ref.read(editionProvider.notifier).state = other;
          ref.invalidate(editionConfigProvider(other));
          ref.read(appRouterProvider).go('/feed');
        },
        onLater: () => setState(() => _dismissed.add(optionalKey)),
      ),
    );
  }
}

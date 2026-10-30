import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../core/edition/edition.dart';
import '../core/edition/ad_analytics.dart';

int adCountForItems(int count) => count ~/ 3;
bool isAdSlot(int index) => index % 4 == 3;
int contentIndexForSlot(int index) => index - index ~/ 4;
int rotatingAdIndex(int completedItems, int adCount) =>
    ((completedItems ~/ 3) - 1) % adCount;

final footerRotationProvider =
    ChangeNotifierProvider.family<FooterRotation, Edition>(
        (ref, edition) => FooterRotation());

class FooterRotation extends ChangeNotifier {
  int index = 0;
  String? route;
  int refreshVersion = 0;
  void visit(String nextRoute) {
    if (route != null && route != nextRoute) index++;
    route = nextRoute;
  }

  void nextTab() => index++;
  void refresh() {
    index++;
    refreshVersion++;
    notifyListeners();
  }
}

Future<void> refreshWithFooter(WidgetRef ref, Future<void> Function() refresh) {
  ref.read(footerRotationProvider(ref.read(editionProvider))).refresh();
  return refresh();
}

class PromoImage extends ConsumerStatefulWidget {
  const PromoImage(
      {super.key, required this.banner, this.fit = BoxFit.contain});
  final Map<String, String> banner;
  final BoxFit fit;
  @override
  ConsumerState<PromoImage> createState() => _PromoImageState();
}

class _PromoImageState extends ConsumerState<PromoImage>
    with WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  AdExposure _exposure = AdExposure();
  Timer? _timer;
  bool _loaded = false;
  double _fraction = 0;
  Map<String, String> get banner => widget.banner;
  bool get _tracked => (banner['tracking_token'] ?? '').isNotEmpty;
  bool get _eligible =>
      mounted &&
      _loaded &&
      _fraction >= .5 &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_tracked) {
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_exposure.sample(_eligible, DateTime.now())) _record('impression');
      });
    }
  }

  void _record(String type) => unawaited(ref.read(adAnalyticsProvider).record(
      ref.read(activeConfigProvider).edition, banner, _exposure.viewId, type));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _exposure.sample(false, DateTime.now());
    }
  }

  @override
  void didUpdateWidget(covariant PromoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner['id'] != banner['id'] ||
        oldWidget.banner['image_url'] != banner['image_url'] ||
        oldWidget.banner['tracking_url'] != banner['tracking_url']) {
      _exposure = AdExposure();
      _loaded = false;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(banner['link_url'] ?? '');
    final clickable = uri?.scheme == 'https';
    final image = Semantics(
      label: banner['label']?.isNotEmpty == true
          ? banner['label']
          : 'Advertisement',
      button: clickable,
      child: GestureDetector(
        onTap: clickable
            ? () async {
                if (_tracked && _eligible && !_exposure.clicked) {
                  if (_exposure.sample(true, DateTime.now())) {
                    _record('impression');
                  }
                  if (!_exposure.impressed) {
                    _exposure.impressed = true;
                    _record('impression');
                  }
                  _exposure.clicked = true;
                  _record('click');
                }
                try {
                  await launchUrl(uri!, mode: LaunchMode.externalApplication);
                } catch (_) {/* A missing browser must not crash the app. */}
              }
            : null,
        child: CachedNetworkImage(
          imageUrl: banner['image_url'] ?? '',
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          imageBuilder: (_, provider) {
            _loaded = true;
            return Image(
                image: provider,
                fit: widget.fit,
                width: double.infinity,
                height: double.infinity);
          },
          errorWidget: (_, __, ___) {
            _loaded = false;
            return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        semanticLabel: 'Advertisement unavailable')));
          },
        ),
      ),
    );
    if (!_tracked) return image;
    return VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: (info) {
          _fraction = info.visibleFraction;
          if (_fraction < .5) _exposure.sample(false, DateTime.now());
        },
        child: image);
  }
}

class InlineAdAfter extends ConsumerWidget {
  const InlineAdAfter({super.key, required this.completedItems});
  final int completedItems;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(activeConfigProvider).inlineAds;
    if (ads.isEmpty || completedItems == 0 || completedItems % 3 != 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Advertisement',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          AspectRatio(
              aspectRatio: 1,
              child: PromoImage(
                  banner: ads[rotatingAdIndex(completedItems, ads.length)])),
        ]),
      )),
    );
  }
}

class FooterAdvertisement extends ConsumerStatefulWidget {
  const FooterAdvertisement({super.key, this.pageKey = ''});
  final String pageKey;
  @override
  ConsumerState<FooterAdvertisement> createState() =>
      _FooterAdvertisementState();
}

class _FooterAdvertisementState extends ConsumerState<FooterAdvertisement> {
  bool _closed = false, _minimized = false;
  GoRouter? _router;
  String _route = '';
  int _refreshVersion = 0;
  FooterRotation get _rotation =>
      ref.read(footerRotationProvider(ref.read(editionProvider)));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routeInformationProvider.removeListener(_routeChanged);
    _router = router;
    _route = router?.routeInformationProvider.value.uri.toString() ?? '';
    _rotation.visit(_route);
    router?.routeInformationProvider.addListener(_routeChanged);
  }

  void _routeChanged() {
    final route = _router?.routeInformationProvider.value.uri.toString() ?? '';
    if (route == _route || !mounted) return;
    setState(() {
      _route = route;
      _closed = false;
      _minimized = false;
      _rotation.visit(route);
    });
  }

  @override
  void didUpdateWidget(covariant FooterAdvertisement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _closed = false;
      _minimized = false;
      _rotation.nextTab();
    }
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(activeConfigProvider);
    final rotation =
        ref.watch(footerRotationProvider(ref.watch(editionProvider)));
    if (_refreshVersion != rotation.refreshVersion) {
      _refreshVersion = rotation.refreshVersion;
      _closed = false;
      _minimized = false;
    }
    final ads = config.footerAds;
    if (_closed || ads.isEmpty) return const SizedBox.shrink();
    return Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('Advertisement',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            IconButton(
                tooltip: _minimized
                    ? 'Expand advertisement'
                    : 'Minimize advertisement',
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 32),
                iconSize: 18,
                icon: Icon(_minimized ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _minimized = !_minimized)),
            IconButton(
                tooltip: 'Close advertisement',
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 32),
                iconSize: 18,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _closed = true)),
          ]),
          if (!_minimized)
            LayoutBuilder(builder: (context, constraints) {
              final banner = ads[rotation.index % ads.length];
              final width = math.min(350.0, constraints.maxWidth);
              final height = banner['size'] == '350x100' ? 100.0 : 50.0;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: width,
                    height: width * height / 350,
                    child: PromoImage(
                        key: ValueKey(
                            '${config.edition.name}:${rotation.index}'),
                        banner: banner),
                  ));
            }),
        ]));
  }
}

// Rewarm the rotation after configuration changes, reusing the same caches.
class PromoImageWarmup extends ConsumerStatefulWidget {
  const PromoImageWarmup({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PromoImageWarmup> createState() => _PromoImageWarmupState();
}

class _PromoImageWarmupState extends ConsumerState<PromoImageWarmup> {
  String _signature = '';
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(activeConfigProvider);
    final urls = [...config.banners, ...config.inlineAds, ...config.footerAds]
        .map((banner) => banner['image_url'] ?? '')
        .where((url) => Uri.tryParse(url)?.scheme == 'https')
        .toSet();
    final signature = '${config.edition.name}:${urls.join('|')}';
    if (signature != _signature) {
      _signature = signature;
      config.preloadBanners();
    }
    return widget.child;
  }
}

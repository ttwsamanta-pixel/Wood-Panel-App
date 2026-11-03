import '../../widgets/wp_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/edition/edition.dart';
import '../../data/repositories/content_providers.dart';

final premiumCoversProvider = FutureProvider.autoDispose<List<String>>(
    (ref) async => (await ref.watch(contentRepositoryProvider).magazines())
        .map((issue) => issue.coverUrl)
        .where((url) => url.isNotEmpty)
        .take(3)
        .toList());

class BrandDirectoryPage extends ConsumerWidget {
  const BrandDirectoryPage({super.key, this.clients = false});
  final bool clients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(activeConfigProvider);
    final visible = clients ? config.showClients : config.showGroupMedia;
    final entries = clients ? config.clients : config.groupMedia;
    return WPScaffold(
        child: _PageBackground(
            child: !visible
                ? const _Unavailable()
                : ListView(padding: const EdgeInsets.all(16), children: [
                    _Heading(
                        title: clients ? 'Our Clients' : 'Group Media',
                        subtitle: clients
                            ? 'Partnering with leading brands globally.'
                            : 'Part of a trusted media family covering wood, panels, furniture and surfaces.'),
                    const SizedBox(height: 18),
                    if (clients)
                      LayoutBuilder(
                          builder: (context, box) =>
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                for (final entry in entries)
                                  SizedBox(
                                      width: (box.maxWidth - 12) / 2,
                                      child: _BrandCard(
                                          entry: entry, client: true))
                              ]))
                    else
                      for (final entry in entries)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BrandCard(entry: entry)),
                  ])));
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.entry, this.client = false});
  final Map<String, String> entry;
  final bool client;
  @override
  Widget build(BuildContext context) {
    final name = entry['name'] ?? '';
    final link = entry['link_url'] ?? '';
    final image = entry['image_url'] ?? '';
    return Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ]),
        child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: .12))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: link.isEmpty
                    ? null
                    : () async {
                        final success = await launchUrl(Uri.parse(link),
                            mode: LaunchMode.externalApplication);
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Could not open this link.')));
                        }
                      },
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: client
                        ? Semantics(
                            label: name,
                            child: SizedBox(
                                height: 82,
                                child: image.isEmpty
                                    ? Center(
                                        child: Text(name,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700)))
                                    : Image.network(image,
                                        fit: BoxFit.contain,
                                        semanticLabel: name,
                                        errorBuilder: (_, __, ___) => Center(
                                            child: Text(name,
                                                textAlign: TextAlign.center)))))
                        : Row(children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: SizedBox(
                                    width: 58,
                                    height: 68,
                                    child: image.isEmpty
                                        ? const Icon(
                                            Icons.auto_stories_outlined,
                                            size: 32)
                                        : Image.network(image,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.auto_stories_outlined,
                                                    size: 32)))),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                                  if ((entry['description'] ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(entry['description']!,
                                        style: const TextStyle(fontSize: 12))
                                  ],
                                ])),
                            if (link.isNotEmpty)
                              const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.chevron_right)),
                          ])))));
  }
}

class PremiumPage extends ConsumerWidget {
  const PremiumPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(activeConfigProvider);
    final color = Theme.of(context).colorScheme.primary;
    return WPScaffold(
        child: _PageBackground(
            child: !config.premiumEnabled
                ? const _Unavailable()
                : ListView(padding: const EdgeInsets.all(22), children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Icon(Icons.workspace_premium_outlined,
                                    color: color, size: 48),
                                const SizedBox(height: 8),
                                Text('Subscribe to\nWood & Panel Premium',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                              ])),
                          if (config.premiumImageUrl.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Image.network(config.premiumImageUrl,
                                    width: 104,
                                    height: 150,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.menu_book,
                                        color: color,
                                        size: 72)))
                          else
                            const _MagazineStack(),
                        ]),
                    const SizedBox(height: 24),
                    for (final benefit in const [
                      (Icons.menu_book_outlined, 'Read all magazine issues'),
                      (Icons.article_outlined, 'Access premium articles'),
                      (Icons.mic_none, 'Exclusive interviews'),
                      (Icons.bar_chart, 'Industry reports and data'),
                    ])
                      Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(15)),
                          child: Row(children: [
                            Icon(Icons.check_circle, color: color, size: 24),
                            const SizedBox(width: 12),
                            Icon(benefit.$1, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(benefit.$2,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                          ])),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                        onPressed: () => context.push('/contact'),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18))),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Subscribe Now')),
                    const SizedBox(height: 8),
                    const Text('Contact our team for subscription details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                  ])));
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 4,
            height: 28,
            margin: const EdgeInsets.only(top: 5, right: 14),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(3))),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle),
        ])),
      ]);
}

class _PageBackground extends StatelessWidget {
  const _PageBackground({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceContainerLowest
                    ]
                  : [
                      const Color(0xFFFFFCF8),
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .07)
                    ])),
      child: child);
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This section is not currently available.'),
        TextButton(
            onPressed: () => context.go('/profile'),
            child: const Text('Back to Profile')),
      ]));
}

class _MagazineStack extends ConsumerWidget {
  const _MagazineStack();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final covers = ref.watch(premiumCoversProvider).valueOrNull ?? [];
    if (covers.isEmpty) {
      return Icon(Icons.auto_stories,
          color: Theme.of(context).colorScheme.primary, size: 72);
    }
    return SizedBox(
        width: 106,
        height: 150,
        child: Stack(alignment: Alignment.center, children: [
          for (var i = covers.length - 1; i >= 0; i--)
            Transform.rotate(
                angle: -i * .13,
                child: Transform.translate(
                    offset: Offset(-i * 5, i * 3),
                    child: Image.network(covers[i],
                        width: 88,
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox()))),
        ]));
  }
}

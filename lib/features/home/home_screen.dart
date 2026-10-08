import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_models.dart';
import '../../data/models/news_category.dart';
import '../../data/repositories/cache_refresh_bus.dart';
import '../../data/repositories/content_providers.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/repositories/youtube_video_repository.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _homeFuture;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _homeFuture = _fetchHomeData();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (!mounted) return;
      setState(() => _homeFuture = _fetchHomeData());
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<_HomeData> _fetchHomeData() async {
    final contentRepository = ref.read(contentRepositoryProvider);
    final videoRepository = ref.read(youtubeVideoRepositoryProvider);
    final articlesFuture = contentRepository.latestArticles();
    final videosFuture =
        videoRepository.latestVideos().catchError((_) => <YouTubeVideo>[]);
    final magazinesFuture =
        contentRepository.magazines().catchError((_) => <MagazineIssue>[]);
    final eventsFuture =
        contentRepository.events().catchError((_) => <AppEvent>[]);
    final results = await Future.wait<dynamic>([
      articlesFuture,
      videosFuture,
      magazinesFuture,
      eventsFuture,
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    return _HomeData(
      articles: results[0] as List<Article>,
      videos: results[1] as List<YouTubeVideo>,
      magazines: results[2] as List<MagazineIssue>,
      events: results[3] as List<AppEvent>,
    );
  }

  Future<void> _reloadArticles() async {
    setState(() => _homeFuture = _fetchHomeData());
    await _homeFuture;
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      child: FutureBuilder<_HomeData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPPageLoader();
          }
          if (snapshot.hasError) {
            return WPErrorState(
              title: 'News could not load',
              message: 'Please check your connection and try again.',
              onRetry: () => _reloadArticles(),
            );
          }

          final homeData = snapshot.data ?? _HomeData.empty;
          if (homeData.articles.isEmpty) {
            return const WPEmptyState(
              icon: Icons.article_outlined,
              title: 'No articles yet',
              message: 'Latest Wood And Panel stories will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _reloadArticles,
            child: _HomeContent(
              data: homeData,
              onNewsletterPressed: () => context.push('/newsletter'),
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.articles,
    required this.videos,
    required this.magazines,
    required this.events,
  });

  static const empty = _HomeData(
    articles: <Article>[],
    videos: <YouTubeVideo>[],
    magazines: <MagazineIssue>[],
    events: <AppEvent>[],
  );

  final List<Article> articles;
  final List<YouTubeVideo> videos;
  final List<MagazineIssue> magazines;
  final List<AppEvent> events;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.onNewsletterPressed,
  });

  final _HomeData data;
  final VoidCallback onNewsletterPressed;

  @override
  Widget build(BuildContext context) {
    final articles = data.articles;
    return ListView(
      children: [
        WPHeroNewsCard(article: articles.first),
        WPSectionHeader(
          title: 'Latest News',
          actionLabel: 'See All',
          onAction: () => context.go('/feed'),
        ),
        for (final article in articles.skip(1).take(4))
          _LatestNewsRow(article: article),
        const WPSectionHeader(title: 'Trending'),
        SizedBox(
          height: 206,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: articles.length,
            itemBuilder: (context, index) =>
                _TrendingCard(article: articles[index]),
          ),
        ),
        const WPSectionHeader(title: 'News Categories'),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: NewsCategory.all.length,
            itemBuilder: (context, index) =>
                _CategoryTile(category: NewsCategory.all[index]),
          ),
        ),
        WPSectionHeader(
          title: 'Videos',
          actionLabel: 'See All',
          onAction: () => context.push('/videos'),
        ),
        _HomeVideoCarousel(videos: data.videos),
        WPSectionHeader(
          title: 'Magazine Highlight',
          actionLabel: 'All Issues',
          onAction: () => context.go('/magazine'),
        ),
        _HomeMagazineCarousel(magazines: data.magazines),
        WPSectionHeader(
          title: 'Upcoming Events',
          actionLabel: 'View',
          onAction: () => context.push('/events'),
        ),
        _HomeEventsCarousel(events: data.events),
        const WPSectionHeader(title: 'Newsletter'),
        _NewsletterCard(onPressed: onNewsletterPressed),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LatestNewsRow extends StatelessWidget {
  const _LatestNewsRow({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: WPImage(url: article.imageUrl, width: 82, height: 68),
      title: Text(
        article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          DateFormat('d MMM yyyy').format(article.date),
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/article/${article.id}'),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/article/${article.id}'),
      child: Container(
        width: 224,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WPImage(url: article.imageUrl, height: 124, width: 224),
            const SizedBox(height: 8),
            WPTag(article.category),
            const SizedBox(height: 7),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.16),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeVideoCarousel extends StatelessWidget {
  const _HomeVideoCarousel({required this.videos});

  final List<YouTubeVideo> videos;

  @override
  Widget build(BuildContext context) {
    final visibleVideos = videos.take(6).toList();
    if (visibleVideos.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.copper, size: 34),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Latest YouTube videos will appear here.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/videos'),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: visibleVideos.length,
        itemBuilder: (context, index) =>
            _HomeVideoCard(video: visibleVideos[index]),
      ),
    );
  }
}

class _HomeVideoCard extends StatelessWidget {
  const _HomeVideoCard({required this.video});

  final YouTubeVideo video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video/${video.id}'),
      child: Container(
        width: 224,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(url: video.thumbnailUrl, height: 124, width: 224),
                Positioned.fill(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: .66),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.12),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('d MMM yyyy').format(video.publishedAt),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMagazineCarousel extends StatelessWidget {
  const _HomeMagazineCarousel({required this.magazines});

  final List<MagazineIssue> magazines;

  @override
  Widget build(BuildContext context) {
    final issues = recentYearIssues(magazines);
    if (issues.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppColors.copper, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Magazine issues will appear here.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/magazine'),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 446,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: issues.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Align(
          alignment: Alignment.topCenter,
          child: _HomeMagazineCard(issue: issues[index]),
        ),
      ),
    );
  }

  static List<MagazineIssue> recentYearIssues(List<MagazineIssue> issues) {
    if (issues.isEmpty) {
      return const [];
    }
    final currentYear = DateTime.now().year;
    final currentYearIssues =
        issues.where((issue) => issue.date.year == currentYear).toList();
    if (currentYearIssues.isNotEmpty) {
      return currentYearIssues;
    }
    return issues.take(8).toList();
  }
}

class _HomeMagazineCard extends ConsumerWidget {
  const _HomeMagazineCard({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 252,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/magazine/${issue.id}'),
            child: WPImage(
              url: issue.coverUrl,
              width: double.infinity,
              height: 270,
              fit: BoxFit.cover,
              borderRadius: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  height: 1.04,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.description.isEmpty
                ? 'Wood and panel industry insights'
                : issue.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.14,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const _HomeMagazineIssueMeta(
                  icon: Icons.menu_book_rounded, label: 'Vol. 18'),
              const SizedBox(width: 12),
              _HomeMagazineIssueMeta(
                icon: Icons.article_outlined,
                label: 'Issue ${issue.date.month}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.copper,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    onPressed: () => context.push('/magazine/${issue.id}/read'),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Read',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: _HomeMagazinePdfButton(issue: issue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeMagazineIssueMeta extends StatelessWidget {
  const _HomeMagazineIssueMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMagazinePdfButton extends ConsumerWidget {
  const _HomeMagazinePdfButton({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (issue.pdfUrl.isEmpty) {
      return _HomeMagazineOutlineButton(
        label: 'PDF',
        icon: Icons.download_rounded,
        onPressed: null,
      );
    }
    final repository = ref.watch(downloadRepositoryProvider);
    return FutureBuilder<DownloadedFile?>(
      future: repository.fileForUrl(issue.pdfUrl),
      builder: (context, snapshot) {
        final downloaded = snapshot.data;
        if (downloaded != null) {
          return _HomeMagazineOutlineButton(
            label: 'View PDF',
            icon: Icons.visibility_outlined,
            onPressed: () => context.push('/downloaded-pdf', extra: downloaded),
          );
        }
        return _HomeMagazineOutlineButton(
          label: 'Download',
          icon: Icons.download_rounded,
          onPressed: () async {
            await _downloadHomeMagazinePdf(context, ref, issue);
          },
        );
      },
    );
  }
}

class _HomeMagazineOutlineButton extends StatelessWidget {
  const _HomeMagazineOutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size.fromHeight(42),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _downloadHomeMagazinePdf(
  BuildContext context,
  WidgetRef ref,
  MagazineIssue issue,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(content: Text('Downloading ${issue.title}...')),
  );
  try {
    final repository = ref.read(downloadRepositoryProvider);
    await repository.downloadPdf(
      title: issue.title,
      url: issue.pdfUrl,
      coverUrl: issue.coverUrl,
    );
    ref.invalidate(downloadRepositoryProvider);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('PDF downloaded'),
        action: SnackBarAction(
          label: 'Downloads',
          onPressed: () => context.push('/downloads'),
        ),
      ),
    );
  } on Object {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Download failed. Please try again.')),
    );
  }
}

class _HomeEventsCarousel extends StatelessWidget {
  const _HomeEventsCarousel({required this.events});

  final List<AppEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _FeatureBand(
        icon: Icons.event_busy_rounded,
        title: 'No website events found',
        subtitle: 'Events from Wood & Panel will appear here when listed.',
        button: 'Open Events',
        onPressed: () => context.push('/events'),
      );
    }
    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _HomeEventCard(
          event: events[index],
          onTap: () => context.push('/events'),
        ),
      ),
    );
  }
}

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({required this.event, required this.onTap});

  final AppEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WPImage(
              url: event.imageUrl,
              width: double.infinity,
              height: 92,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    event.date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE9D8C6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE9D8C6),
                      height: 1.12,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final NewsCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/category/${category.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_categoryIcon(category.id), color: AppColors.copper),
            const Spacer(),
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(int id) {
    return switch (id) {
      30036 => Icons.new_releases_rounded,
      27527 => Icons.handyman_rounded,
      31124 => Icons.event_available_rounded,
      33793 => Icons.business_center_rounded,
      33794 => Icons.eco_rounded,
      33795 => Icons.chair_rounded,
      31111 => Icons.format_paint_rounded,
      33796 => Icons.palette_rounded,
      31112 => Icons.computer_rounded,
      31118 => Icons.forest_rounded,
      33797 => Icons.layers_rounded,
      33798 => Icons.grid_on_rounded,
      31115 => Icons.construction_rounded,
      33799 => Icons.precision_manufacturing_rounded,
      _ => Icons.article_rounded,
    };
  }
}

class _FeatureBand extends StatelessWidget {
  const _FeatureBand({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.25),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onPressed,
                    child: Text(button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsletterCard extends StatelessWidget {
  const _NewsletterCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_rounded,
              color: AppColors.copper, size: 34),
          const SizedBox(height: 10),
          Text('Get the latest wood and panel updates',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'A concise industry briefing with news, events, and magazine highlights.'),
          const SizedBox(height: 14),
          WPPrimaryButton(label: 'Subscribe', onPressed: onPressed),
        ],
      ),
    );
  }
}

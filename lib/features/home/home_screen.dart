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
import '../../data/repositories/youtube_video_repository.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<Article>> _articlesFuture;
  late Future<List<YouTubeVideo>> _videosFuture;
  late Future<List<MagazineIssue>> _magazinesFuture;
  late Future<List<AppEvent>> _eventsFuture;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _articlesFuture = _fetchArticles();
    _videosFuture = _fetchVideos();
    _magazinesFuture = _fetchMagazines();
    _eventsFuture = _fetchEvents();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (!mounted) return;
      setState(() {
        if (type == CacheRefreshType.content) {
          _articlesFuture = _fetchArticles();
          _magazinesFuture = _fetchMagazines();
          _eventsFuture = _fetchEvents();
        } else if (type == CacheRefreshType.videos) {
          _videosFuture = _fetchVideos();
        }
      });
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<List<Article>> _fetchArticles() =>
      ref.read(contentRepositoryProvider).latestArticles();

  Future<List<YouTubeVideo>> _fetchVideos() =>
      ref.read(youtubeVideoRepositoryProvider).latestVideos();

  Future<List<MagazineIssue>> _fetchMagazines() =>
      ref.read(contentRepositoryProvider).magazines();

  Future<List<AppEvent>> _fetchEvents() =>
      ref.read(contentRepositoryProvider).events();

  Future<void> _reloadArticles() async {
    setState(() {
      _articlesFuture = _fetchArticles();
      _videosFuture = _fetchVideos();
      _magazinesFuture = _fetchMagazines();
      _eventsFuture = _fetchEvents();
    });
    await Future.wait([
      _articlesFuture,
      _videosFuture,
      _magazinesFuture,
      _eventsFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      child: FutureBuilder<List<Article>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(showHero: true, itemCount: 6);
          }
          if (snapshot.hasError) {
            return WPErrorState(
              title: 'News could not load',
              message: 'Please check your connection and try again.',
              onRetry: () => _reloadArticles(),
            );
          }

          final articles = snapshot.data ?? const <Article>[];
          if (articles.isEmpty) {
            return const WPEmptyState(
              icon: Icons.article_outlined,
              title: 'No articles yet',
              message: 'Latest Wood And Panel stories will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _reloadArticles,
            child: ListView(
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
                _HomeVideoCarousel(videosFuture: _videosFuture),
                WPSectionHeader(
                  title: 'Magazine Highlight',
                  actionLabel: 'All Issues',
                  onAction: () => context.go('/magazine'),
                ),
                _HomeMagazineCarousel(magazinesFuture: _magazinesFuture),
                WPSectionHeader(
                  title: 'Upcoming Events',
                  actionLabel: 'View',
                  onAction: () => context.push('/events'),
                ),
                _HomeEventsCarousel(eventsFuture: _eventsFuture),
                const WPSectionHeader(title: 'Newsletter'),
                _NewsletterCard(onPressed: () => context.push('/newsletter')),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
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
  const _HomeVideoCarousel({required this.videosFuture});

  final Future<List<YouTubeVideo>> videosFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<YouTubeVideo>>(
      future: videosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 210,
            child: WPBrandLoader(size: 96, compact: true),
          );
        }
        final videos =
            (snapshot.data ?? const <YouTubeVideo>[]).take(6).toList();
        if (snapshot.hasError || videos.isEmpty) {
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
            itemCount: videos.length,
            itemBuilder: (context, index) =>
                _HomeVideoCard(video: videos[index]),
          ),
        );
      },
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
  const _HomeMagazineCarousel({required this.magazinesFuture});

  final Future<List<MagazineIssue>> magazinesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MagazineIssue>>(
      future: magazinesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 230,
            child: WPBrandLoader(size: 96, compact: true),
          );
        }
        final issues = _recentYearIssues(snapshot.data ?? const []);
        if (snapshot.hasError || issues.isEmpty) {
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
          height: 242,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: issues.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _HomeMagazineCard(issue: issues[index]),
          ),
        );
      },
    );
  }

  List<MagazineIssue> _recentYearIssues(List<MagazineIssue> issues) {
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

class _HomeMagazineCard extends StatelessWidget {
  const _HomeMagazineCard({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/magazine/${issue.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WPImage(
              url: issue.coverUrl,
              width: double.infinity,
              height: 132,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 9),
            Text(
              issue.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              'Vol. 18 | Issue ${issue.date.month}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: FilledButton.icon(
                onPressed: () => context.push('/magazine/${issue.id}/read'),
                icon: const Icon(Icons.menu_book_rounded, size: 17),
                label: const Text('Read'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEventsCarousel extends StatelessWidget {
  const _HomeEventsCarousel({required this.eventsFuture});

  final Future<List<AppEvent>> eventsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppEvent>>(
      future: eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 212,
            child: WPBrandLoader(size: 96, compact: true),
          );
        }
        final events = snapshot.data ?? const <AppEvent>[];
        if (snapshot.hasError || events.isEmpty) {
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
      },
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

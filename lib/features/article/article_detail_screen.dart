import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_models.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/content_providers.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_scaffold.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  const ArticleDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ArticleDetailScreen> createState() =>
      _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  final _tts = FlutterTts();
  late Future<Article> _articleFuture;
  var _isBookmarked = false;
  var _isSpeaking = false;
  var _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _articleFuture = _fetchArticle();
    _loadBookmark();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<Article> _fetchArticle() =>
      ref.read(contentRepositoryProvider).articleById(widget.id);

  Future<void> _retryArticle() async {
    setState(() => _articleFuture = _fetchArticle());
    await _articleFuture;
  }

  Future<void> _loadBookmark() async {
    final repository = ref.read(bookmarkRepositoryProvider);
    final isBookmarked = await repository.isBookmarked(widget.id);
    if (mounted) {
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  Future<void> _toggleBookmark(Article article) async {
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    await ref
        .read(bookmarkRepositoryProvider)
        .setArticleBookmark(article.id, next);
  }

  Future<void> _toggleSpeech(Article article) async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak('${article.title}. ${article.excerpt}');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      child: FutureBuilder<Article>(
        future: _articleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(showHero: true, itemCount: 5);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return WPErrorState(
              title: 'Article could not load',
              message: 'Please check your connection and try again.',
              onRetry: () => _retryArticle(),
            );
          }

          final article = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _retryArticle,
            child: ListView(
              children: [
                _ArticleHero(article: article),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontSize: 22,
                                  height: 1.06,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.excerpt,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.28,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _ArticleInfoBar(
                        article: article,
                        isBookmarked: _isBookmarked,
                        isSpeaking: _isSpeaking,
                        onBookmark: () => _toggleBookmark(article),
                        onShare: () =>
                            Share.share('${article.title}\n${article.url}'),
                        onListen: () => _toggleSpeech(article),
                        onSmallerText: () => setState(() =>
                            _fontScale = (_fontScale - .1).clamp(.85, 1.35)),
                        onLargerText: () => setState(() =>
                            _fontScale = (_fontScale + .1).clamp(.85, 1.35)),
                      ),
                      const Divider(height: 26),
                      DefaultTextStyle.merge(
                        style: TextStyle(
                            fontSize: 16 * _fontScale,
                            height: 1.7,
                            color: AppColors.ink),
                        child: HtmlWidget(article.html),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArticleHero extends StatelessWidget {
  const _ArticleHero({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WPImage(
          url: article.imageUrl,
          height: 220,
          width: double.infinity,
          borderRadius: 0,
        ),
        Positioned(
          left: 18,
          bottom: 18,
          child: WPTag(article.category),
        ),
      ],
    );
  }
}

class _ArticleInfoBar extends StatelessWidget {
  const _ArticleInfoBar({
    required this.article,
    required this.isBookmarked,
    required this.isSpeaking,
    required this.onBookmark,
    required this.onShare,
    required this.onListen,
    required this.onSmallerText,
    required this.onLargerText,
  });

  final Article article;
  final bool isBookmarked;
  final bool isSpeaking;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onListen;
  final VoidCallback onSmallerText;
  final VoidCallback onLargerText;

  @override
  Widget build(BuildContext context) {
    final authorInitial = article.author.trim().isEmpty
        ? 'W'
        : article.author.trim()[0].toUpperCase();
    final hasAuthorAvatar = article.authorAvatarUrl.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF5EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF8EBDD),
                  backgroundImage: hasAuthorAvatar
                      ? NetworkImage(article.authorAvatarUrl)
                      : null,
                  child: Text(
                    hasAuthorAvatar ? '' : authorInitial,
                    style: const TextStyle(
                      color: AppColors.copper,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Written by',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontSize: 10.5,
                              height: 1,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        article.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  height: 1.05,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _CompactIconButton(
                  tooltip: isBookmarked ? 'Saved' : 'Save',
                  icon: isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onPressed: onBookmark,
                ),
                const SizedBox(width: 6),
                _CompactIconButton(
                  tooltip: 'Share',
                  icon: Icons.share_rounded,
                  onPressed: onShare,
                ),
                const SizedBox(width: 6),
                _CompactIconButton(
                  tooltip: isSpeaking ? 'Stop' : 'Listen',
                  icon: isSpeaking
                      ? Icons.stop_circle_rounded
                      : Icons.volume_up_rounded,
                  onPressed: onListen,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  DateFormat('d MMM yyyy').format(article.date),
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
                const SizedBox(width: 9),
                const Text('|',
                    style: TextStyle(
                        color: AppColors.line, fontWeight: FontWeight.w900)),
                const SizedBox(width: 9),
                const Icon(Icons.schedule_rounded,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${article.readingMinutes} min read',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                _CompactIconButton(
                  tooltip: 'Smaller text',
                  icon: Icons.text_decrease_rounded,
                  onPressed: onSmallerText,
                  dense: true,
                ),
                const SizedBox(width: 6),
                _CompactIconButton(
                  tooltip: 'Larger text',
                  icon: Icons.text_increase_rounded,
                  onPressed: onLargerText,
                  dense: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.dense = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 30.0 : 34.0;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6C9B2)),
        ),
        child: SizedBox.square(
          dimension: size,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tight(Size.square(size)),
            iconSize: dense ? 16 : 18,
            color: AppColors.copper,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}

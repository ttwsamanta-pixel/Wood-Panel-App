import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../data/models/content_models.dart';
import 'wp_logo.dart';

class WPSectionHeader extends StatelessWidget {
  const WPSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class WPImage extends StatelessWidget {
  const WPImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholderColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        placeholder: (context, _) => Container(color: placeholderColor),
        errorWidget: (context, _, __) => Container(
          color: placeholderColor,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}

class WPHeroNewsCard extends StatelessWidget {
  const WPHeroNewsCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/article/${article.id}'),
      child: Container(
        height: 282,
        margin: const EdgeInsets.fromLTRB(18, 14, 18, 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WPImage(url: article.imageUrl, borderRadius: 8),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WPTag(article.category),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('d MMM yyyy').format(article.date)} - ${article.readingMinutes} min read',
                    style: const TextStyle(color: Colors.white70),
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

class WPCompactNewsCard extends StatelessWidget {
  const WPCompactNewsCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: WPImage(url: article.imageUrl, width: 82, height: 68),
      title: Text(
        article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${article.category} - ${DateFormat('d MMM yyyy').format(article.date)}',
        maxLines: 1,
      ),
      onTap: () => context.push('/article/${article.id}'),
    );
  }
}

class WPTag extends StatelessWidget {
  const WPTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.copper,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class WPPrimaryButton extends StatelessWidget {
  const WPPrimaryButton(
      {super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.copper,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class WPEmptyState extends StatelessWidget {
  const WPEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.copper),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class WPErrorState extends StatelessWidget {
  const WPErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 42, color: AppColors.error),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WPBrandLoader extends StatefulWidget {
  const WPBrandLoader({
    super.key,
    this.size = 132,
    this.label,
    this.compact = false,
    this.logoScale = .52,
  });

  final double size;
  final String? label;
  final bool compact;
  final double logoScale;

  @override
  State<WPBrandLoader> createState() => _WPBrandLoaderState();
}

class _WPBrandLoaderState extends State<WPBrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.size * widget.logoScale;
    final loader = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _BrandLoaderPainter(progress: _controller.value),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(logoSize * .18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: .18),
                      blurRadius: widget.size * .16,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(logoSize * .18),
                  child: Image.asset(
                    'assets/app_icon_source.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (widget.compact && widget.label == null) {
      return Center(child: loader);
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loader,
            if (widget.label != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WPPageLoader extends StatelessWidget {
  const WPPageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BrandedPageLoader();
  }
}

class _BrandedPageLoader extends StatefulWidget {
  const _BrandedPageLoader();

  @override
  State<_BrandedPageLoader> createState() => _BrandedPageLoaderState();
}

class _BrandedPageLoaderState extends State<_BrandedPageLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _PageLoaderBackgroundPainter()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: WPLogo(
                width: MediaQuery.sizeOf(context).width * .7,
                height: 88,
              ),
            ),
          ),
          Positioned(
            left: 92,
            right: 92,
            bottom: 54,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size.fromHeight(4),
                  painter: _PageLoaderLinePainter(progress: _controller.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageLoaderBackgroundPainter extends CustomPainter {
  const _PageLoaderBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 10; i++) {
      paint.color = AppColors.copper.withValues(alpha: .22 - (i * .012));
      final inset = i * 18.0;
      final rightRect = Rect.fromLTWH(
        size.width * .52 + inset,
        -size.height * .18 + inset,
        size.width * .96,
        size.height * .78,
      );
      canvas.drawArc(rightRect, math.pi * .52, math.pi * .82, false, paint);

      final bottomRect = Rect.fromLTWH(
        -size.width * .62 - inset,
        size.height * .66 - inset,
        size.width * 1.52,
        size.height * .62,
      );
      canvas.drawArc(bottomRect, -math.pi * .18, math.pi * .64, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PageLoaderLinePainter extends CustomPainter {
  const _PageLoaderLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final trackPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .34);
    canvas.drawLine(Offset.zero.translate(0, centerY),
        Offset(size.width, centerY), trackPaint);

    final segmentWidth = size.width * .28;
    final start = (size.width + segmentWidth) * progress - segmentWidth;
    final end = math.min(start + segmentWidth, size.width);
    final clampedStart = math.max(start, 0.0);
    if (end <= 0 || clampedStart >= size.width) {
      return;
    }

    final progressPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.brown, AppColors.gold],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(
      Offset(clampedStart, centerY),
      Offset(end, centerY),
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PageLoaderLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BrandLoaderPainter extends CustomPainter {
  const _BrandLoaderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .43;
    final stroke = size.shortestSide * .055;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final rotation = (progress * math.pi * 2) - math.pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEFEAE4);
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.green, Color(0xFF0F7041)],
      ).createShader(rect);
    canvas.drawArc(rect, rotation, math.pi * .86, false, greenPaint);

    final brownPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.brown, AppColors.copper],
      ).createShader(rect);
    canvas.drawArc(
        rect, rotation + math.pi * 1.34, math.pi * .64, false, brownPaint);

    final dotAngle = rotation + math.pi * .86;
    final dotCenter = Offset(
      center.dx + math.cos(dotAngle) * radius,
      center.dy + math.sin(dotAngle) * radius,
    );
    final glowPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: .24)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.9);
    canvas.drawCircle(dotCenter, stroke * 1.35, glowPaint);
    canvas.drawCircle(
      dotCenter,
      stroke * .72,
      Paint()..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class WPSkeletonList extends StatelessWidget {
  const WPSkeletonList({
    super.key,
    this.itemCount = 5,
    this.showHero = false,
  });

  final int itemCount;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return const WPPageLoader();
  }
}

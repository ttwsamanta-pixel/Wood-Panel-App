import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/wallpaper_repository.dart';
import '../../widgets/wp_scaffold.dart';

class WallpaperGalleryScreen extends ConsumerStatefulWidget {
  const WallpaperGalleryScreen({super.key});

  @override
  ConsumerState<WallpaperGalleryScreen> createState() =>
      _WallpaperGalleryScreenState();
}

class _WallpaperGalleryScreenState
    extends ConsumerState<WallpaperGalleryScreen> {
  String _category = 'All';
  bool _savedOnly = false;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedWallpapersProvider);
    final catalog = ref.watch(wallpaperCatalogProvider);
    final items = catalog
        .where((item) =>
            (_category == 'All' || item.category == _category) &&
            (!_savedOnly || (saved.valueOrNull?.contains(item.id) ?? false)))
        .toList();
    return WPScaffold(
      showBack: true,
      title: 'Wallpapers',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(children: [
              Expanded(
                  child: Text('Wallpapers',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800))),
              FilterChip(
                avatar: Icon(
                    _savedOnly ? Icons.bookmark : Icons.bookmark_border,
                    size: 18),
                label: const Text('Saved'),
                selected: _savedOnly,
                onSelected: (value) => setState(() => _savedOnly = value),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              for (final category in [
                'All',
                ...catalog.map((item) => item.category).toSet()
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _savedOnly && saved.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedOnly && saved.hasError
                    ? Center(
                        child: TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(savedWallpapersProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry saved wallpapers')))
                    : items.isEmpty
                        ? Center(
                            child: Text(_savedOnly
                                ? 'No saved wallpapers in this category.'
                                : 'No wallpapers in this category.'))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              childAspectRatio: .66,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Material(
                                color: Colors.white,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                        color: AppColors.line)),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) => _WallpaperPreview(
                                              wallpaper: item))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: SizedBox(
                                                width: double.infinity,
                                                child: _WallpaperImage(
                                                    wallpaper: item,
                                                    width: 480,
                                                    fit: BoxFit.cover))),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 8, 4, 8),
                                          child: Row(children: [
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(item.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13)),
                                                  const SizedBox(height: 3),
                                                  Text(item.category,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color:
                                                              AppColors.muted,
                                                          fontSize: 11)),
                                                ])),
                                            _SaveWallpaperButton(id: item.id),
                                          ]),
                                        ),
                                      ]),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _WallpaperImage extends StatefulWidget {
  const _WallpaperImage(
      {required this.wallpaper, required this.width, required this.fit});
  final Wallpaper wallpaper;
  final int width;
  final BoxFit fit;

  @override
  State<_WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<_WallpaperImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) =>
      widget.wallpaper.photo.startsWith('assets/')
          ? Image.asset(widget.wallpaper.photo,
              fit: widget.fit, cacheWidth: widget.width)
          : CachedNetworkImage(
              key: ValueKey(_attempt),
              imageUrl: widget.wallpaper.imageUrl(widget.width),
              fit: widget.fit,
              memCacheWidth: widget.width,
              placeholder: (_, __) => const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (_, __, ___) => Center(
                  child: IconButton(
                tooltip: 'Retry image',
                icon: Icon(Icons.refresh,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () async {
                  await CachedNetworkImage.evictFromCache(
                      widget.wallpaper.imageUrl(widget.width));
                  if (mounted) setState(() => _attempt++);
                },
              )),
            );
}

class _SaveWallpaperButton extends ConsumerStatefulWidget {
  const _SaveWallpaperButton({required this.id, this.light = false});
  final String id;
  final bool light;

  @override
  ConsumerState<_SaveWallpaperButton> createState() =>
      _SaveWallpaperButtonState();
}

class _SaveWallpaperButtonState extends ConsumerState<_SaveWallpaperButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedWallpapersProvider);
    final saved = state.valueOrNull?.contains(widget.id) ?? false;
    return IconButton(
      tooltip: saved ? 'Remove from saved' : 'Save wallpaper',
      color:
          widget.light ? Colors.white : Theme.of(context).colorScheme.primary,
      icon:
          Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
      onPressed: _busy || state.isLoading
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await ref
                    .read(savedWallpapersProvider.notifier)
                    .toggle(widget.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Could not save wallpaper. Please try again.')));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}

class _WallpaperPreview extends StatefulWidget {
  const _WallpaperPreview({required this.wallpaper});
  final Wallpaper wallpaper;

  @override
  State<_WallpaperPreview> createState() => _WallpaperPreviewState();
}

class _WallpaperPreviewState extends State<_WallpaperPreview> {
  final _repository = WallpaperRepository();
  CancelToken? _cancelToken;
  bool _busy = false;
  double? _progress;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _export({required bool share}) async {
    if (_busy) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _progress = null;
    });
    _cancelToken = CancelToken();
    try {
      if (!share && !await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const _GalleryAccessDenied();
      }
      if (_cancelToken!.isCancelled) throw _cancelToken!.cancelError!;
      final file = await _repository.temporaryImage(widget.wallpaper,
          cancelToken: _cancelToken!, onProgress: (received, total) {
        if (mounted) {
          setState(() => _progress = total > 0 ? received / total : null);
        }
      });
      if (!mounted) {
        await file.delete();
        return;
      }
      if (share) {
        // Retain the temporary export briefly so the chosen share target can read it.
        await Share.shareXFiles([
          XFile(file.path,
              mimeType: file.path.endsWith('.png') ? 'image/png' : 'image/jpeg')
        ], text: widget.wallpaper.title, sharePositionOrigin: origin);
      } else {
        try {
          await Gal.putImage(file.path);
        } finally {
          if (await file.exists()) await file.delete();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Wallpaper downloaded to your gallery.')));
        }
      }
    } catch (error) {
      if (mounted && !(error is DioException && CancelToken.isCancel(error))) {
        final message = error is _GalleryAccessDenied
            ? 'Photo access is required to download. You can allow it in app settings.'
            : error is GalException
                ? error.type.message
                : 'Could not download the wallpaper. Check your connection and try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF141414),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141414),
          foregroundColor: Colors.white,
          title: Text(widget.wallpaper.title,
              style: const TextStyle(fontSize: 17)),
          actions: [_SaveWallpaperButton(id: widget.wallpaper.id, light: true)],
        ),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: SizedBox.expand(
                  child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: _WallpaperImage(
                wallpaper: widget.wallpaper, width: 1200, fit: BoxFit.contain),
          ))),
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(value: _progress),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: FilledButton.icon(
                onPressed: _busy ? null : () => _export(share: false),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              )),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Share wallpaper',
                color: Colors.white,
                onPressed: _busy ? null : () => _export(share: true),
                icon: const Icon(Icons.share_outlined),
              ),
              if (_busy)
                IconButton(
                  tooltip: 'Cancel download',
                  color: Colors.white,
                  onPressed: () => _cancelToken?.cancel(),
                  icon: const Icon(Icons.close),
                ),
            ]),
          ),
        ])),
      );
}

class _GalleryAccessDenied implements Exception {
  const _GalleryAccessDenied();
}

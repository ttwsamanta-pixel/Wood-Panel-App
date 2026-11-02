import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/repositories/pdf_reading_repository.dart';
import '../../widgets/wp_scaffold.dart';

class DownloadedPdfScreen extends StatefulWidget {
  const DownloadedPdfScreen({super.key, required this.file});
  final DownloadedFile file;
  @override
  State<DownloadedPdfScreen> createState() => _DownloadedPdfScreenState();
}

class _DownloadedPdfScreenState extends State<DownloadedPdfScreen> {
  PdfReadingRepository? _repository;
  PdfReadingState _reading = const PdfReadingState();
  PDFViewController? _controller;
  int _pages = 0;
  bool _loaded = false, _ready = false, _restoring = false;
  String? _error;
  Future<void> _writes = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repository =
          PdfReadingRepository(await SharedPreferences.getInstance());
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _reading = repository.read(widget.file);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_controller == null || _pages == 0 || _ready || _restoring) return;
    _restoring = true;
    final bounded = _reading.bounded(_pages);
    try {
      if (bounded.page > 0) await _controller!.setPage(bounded.page);
      if (!mounted) return;
      setState(() {
        _reading = bounded;
        _ready = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not restore this PDF. Please reopen it.';
        });
      }
    } finally {
      _restoring = false;
    }
  }

  void _save() {
    final snapshot = _reading;
    final file = widget.file;
    // Serialize snapshots so rapid page swipes cannot overwrite newer progress.
    _writes = _writes.then((_) async {
      if (_repository == null) throw StateError('Storage unavailable');
      await _repository!.save(file, snapshot);
    }).catchError((Object _) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not save reading progress. Please try again.')));
      }
    });
  }

  void _bookmark() {
    final marks = _reading.bookmarks.toSet();
    if (!marks.add(_reading.page)) marks.remove(_reading.page);
    setState(() => _reading = PdfReadingState(
        page: _reading.page, bookmarks: marks.toList()..sort()));
    _save();
  }

  Future<void> _jump(int page) async {
    try {
      await _controller?.setPage(page);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this page.')));
      }
    }
  }

  Future<void> _showBookmarks() async {
    final page = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: 340,
                child: Column(children: [
                  Text('Bookmarked pages',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Expanded(
                      child: _reading.bookmarks.isEmpty
                          ? const Center(
                              child:
                                  Text('Tap the bookmark icon to save a page.'))
                          : ListView(children: [
                              for (final page in _reading.bookmarks)
                                ListTile(
                                    leading: const Icon(Icons.bookmark),
                                    title: Text('Page ${page + 1}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.pop(context, page))
                            ])),
                ]))));
    if (page != null && mounted) await _jump(page);
  }

  @override
  Widget build(BuildContext context) => WPScaffold(
      showBack: true,
      showBottomNav: true,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
            child: Row(children: [
              Expanded(
                  child: Text(widget.file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(
                  tooltip: _reading.bookmarks.contains(_reading.page)
                      ? 'Remove page bookmark'
                      : 'Bookmark page',
                  onPressed: _ready ? _bookmark : null,
                  icon: Icon(_reading.bookmarks.contains(_reading.page)
                      ? Icons.bookmark
                      : Icons.bookmark_border)),
              IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () =>
                      Share.shareXFiles([XFile(widget.file.path)])),
            ])),
        const Divider(height: 1),
        Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!)))
                    : PDFView(
                        filePath: widget.file.path,
                        enableSwipe: true,
                        swipeHorizontal: false,
                        autoSpacing: false,
                        pageFling: false,
                        pageSnap: false,
                        fitPolicy: FitPolicy.WIDTH,
                        onViewCreated: (controller) {
                          _controller = controller;
                          _restore();
                        },
                        onRender: (pages) {
                          _pages = pages ?? 0;
                          _restore();
                        },
                        onPageChanged: (page, total) {
                          if (!_ready || !mounted || page == null || page < 0) {
                            return;
                          }
                          setState(() => _reading = PdfReadingState(
                              page: page, bookmarks: _reading.bookmarks));
                          _save();
                        },
                        onError: (_) {
                          if (mounted) {
                            setState(() => _error =
                                'Could not open this PDF. Please download it again.');
                          }
                        },
                      )),
        const Divider(height: 1),
        Row(children: [
          IconButton(
              tooltip: 'Previous page',
              onPressed: _ready && _reading.page > 0
                  ? () => _jump(_reading.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: Text(
                  _ready
                      ? 'Page ${_reading.page + 1} of $_pages'
                      : 'Opening PDF…',
                  textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'Next page',
              onPressed: _ready && _reading.page + 1 < _pages
                  ? () => _jump(_reading.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right)),
          IconButton(
              tooltip: 'Bookmarked pages',
              onPressed: _ready ? _showBookmarks : null,
              icon: const Icon(Icons.bookmarks_outlined)),
        ]),
      ]));
}

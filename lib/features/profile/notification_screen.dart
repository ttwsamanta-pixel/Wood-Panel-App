import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/edition/edition.dart';
import '../../core/edition/notification_inbox.dart';
import '../../widgets/wp_scaffold.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool unreadOnly = false;
  String elapsed(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '';
    final duration = DateTime.now().difference(date);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes} min ago';
    if (duration.inDays < 1) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }

  Color _categoryColor(String category) {
    const palette = [
      Color(0xff146b35),
      Color(0xff2257b5),
      Color(0xffb44b0c),
      Color(0xff7135b0),
      Color(0xffa42035)
    ];
    final hash = category.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  Widget _filter(
      String label, IconData icon, bool selected, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        selected: selected,
        child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: TextButton.styleFrom(
                foregroundColor: selected ? colors.onPrimary : colors.secondary,
                backgroundColor:
                    selected ? colors.primary : colors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)))));
  }

  @override
  Widget build(BuildContext context) {
    final edition = ref.watch(editionProvider);
    final inbox = ref.watch(notificationInboxProvider(edition));
    final service = ref.read(notificationInboxProvider(edition).notifier);
    final colors = Theme.of(context).colorScheme;
    final items = inbox.items
        .where((item) => !unreadOnly || !inbox.read.contains('${item['id']}'))
        .toList();
    return WPScaffold(
        child: RefreshIndicator(
      onRefresh: service.refresh,
      child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text('News Notifications',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.secondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('The latest news from Wood & Panel ${edition.label}.',
                style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _filter(
                      'All (${inbox.items.length})',
                      Icons.notifications_none,
                      !unreadOnly,
                      () => setState(() => unreadOnly = false))),
              const SizedBox(width: 10),
              Expanded(
                  child: _filter('Unread (${inbox.unread})', Icons.mail_outline,
                      unreadOnly, () => setState(() => unreadOnly = true))),
            ]),
            const SizedBox(height: 12),
            if (inbox.loading && inbox.items.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (inbox.error)
              TextButton.icon(
                  onPressed: service.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Unable to refresh notifications. Retry')),
            if (!inbox.loading && !inbox.error && items.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      unreadOnly
                          ? 'You’re all caught up.'
                          : 'No notifications yet.',
                      textAlign: TextAlign.center)),
            for (final item in items)
              Builder(builder: (context) {
                final unread = !inbox.read.contains('${item['id']}');
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: unread
                            ? colors.primary.withValues(alpha: .055)
                            : Colors.white,
                        border: Border.all(
                            color:
                                colors.outlineVariant.withValues(alpha: .35)),
                        borderRadius: BorderRadius.circular(14)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        service.markRead('${item['id']}');
                        context.push('/article/${item['article_id']}');
                      },
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: (item['image'] as String? ?? '')
                                          .isNotEmpty
                                      ? Image.network(item['image'],
                                          width: 68,
                                          height: 82,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(
                                                  width: 68,
                                                  height: 82,
                                                  child: Icon(Icons
                                                      .newspaper_outlined)))
                                      : Container(
                                          width: 68,
                                          height: 82,
                                          color: colors.surfaceContainerLow,
                                          child: const Icon(
                                              Icons.newspaper_outlined)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: (item['category'] as String? ?? '').isEmpty
                                                    ? const SizedBox.shrink()
                                                    : Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                                horizontal: 4,
                                                                vertical: 2),
                                                        decoration: BoxDecoration(
                                                            color: _categoryColor('${item['category']}')
                                                                .withValues(
                                                                    alpha: .12),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    4)),
                                                        child: Text('${item['category']}'.toUpperCase(),
                                                            maxLines: 1,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                            style: TextStyle(
                                                                fontSize: 9,
                                                                height: 1.15,
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                                color: _categoryColor('${item['category']}')))))),
                                        const SizedBox(width: 5),
                                        Text(elapsed('${item['sent_at']}'),
                                            style: TextStyle(
                                                fontSize: 9,
                                                color:
                                                    colors.onSurfaceVariant)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text('${item['title'] ?? ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700)),
                                      if ((item['body'] as String? ?? '')
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text('${item['body']}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1.2,
                                                color:
                                                    colors.onSurfaceVariant)),
                                      ],
                                    ])),
                                const SizedBox(width: 5),
                                Column(children: [
                                  SizedBox(
                                      height: 14,
                                      width: 10,
                                      child: unread
                                          ? const Icon(Icons.circle,
                                              size: 6, color: Colors.red)
                                          : null),
                                  const SizedBox(height: 20),
                                  const Icon(Icons.chevron_right, size: 16),
                                ]),
                              ])),
                    ));
              }),
          ]),
    ));
  }
}

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
                  child: ChoiceChip(
                      label: Text('All (${inbox.items.length})'),
                      avatar: const Icon(Icons.notifications_none, size: 18),
                      selected: !unreadOnly,
                      onSelected: (_) => setState(() => unreadOnly = false))),
              const SizedBox(width: 10),
              Expanded(
                  child: ChoiceChip(
                      label: Text('Unread (${inbox.unread})'),
                      avatar: const Icon(Icons.mark_email_unread_outlined,
                          size: 18),
                      selected: unreadOnly,
                      onSelected: (_) => setState(() => unreadOnly = true))),
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
                    margin: const EdgeInsets.only(bottom: 10),
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
                          padding: const EdgeInsets.all(12),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((item['image'] as String? ?? '')
                                    .isNotEmpty) ...[
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.network(item['image'],
                                          width: 74,
                                          height: 86,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const SizedBox(
                                                  width: 74,
                                                  height: 86,
                                                  child:
                                                      Icon(Icons.newspaper)))),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(
                                                elapsed('${item['sent_at']}'),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: colors
                                                        .onSurfaceVariant))),
                                        if (unread)
                                          Icon(Icons.circle,
                                              size: 8, color: colors.primary)
                                      ]),
                                      if ((item['category'] as String? ?? '')
                                          .isNotEmpty)
                                        Container(
                                            decoration: BoxDecoration(
                                                color: colors.primary
                                                    .withValues(alpha: .1),
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 3, horizontal: 5),
                                            child: Text(
                                                '${item['category']}'
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.primary))),
                                      Text('${item['title']}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text('${item['body']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant)),
                                    ])),
                              ])),
                    ));
              }),
          ]),
    ));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/edition/edition.dart';
import '../core/edition/notification_inbox.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});
  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        refresh();
      }
    });
  }

  void refresh() => ref
      .read(notificationInboxProvider(ref.read(editionProvider)).notifier)
      .refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count =
        ref.watch(notificationInboxProvider(ref.watch(editionProvider))).unread;
    return IconButton(
        tooltip: 'Notifications${count > 0 ? ', $count unread' : ''}',
        onPressed: () {
          refresh();
          context.push('/notifications');
        },
        icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_none_rounded)));
  }
}

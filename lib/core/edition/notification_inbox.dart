import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'edition.dart';

final notificationInboxProvider =
    StateNotifierProvider.family<NotificationInbox, InboxState, Edition>(
        (ref, edition) => NotificationInbox(edition));

class InboxState {
  const InboxState(
      {this.items = const [],
      this.read = const {},
      this.loading = false,
      this.error = false});
  final List<Map<String, dynamic>> items;
  final Set<String> read;
  final bool loading, error;
  int get unread =>
      items.where((item) => !read.contains('${item['id']}')).length;
}

class NotificationInbox extends StateNotifier<InboxState> {
  NotificationInbox(this.edition, {ApiClient Function()? clientFactory})
      : _clientFactory = clientFactory,
        super(const InboxState()) {
    ready = refresh();
  }
  final Edition edition;
  final ApiClient Function()? _clientFactory;
  late final Future<void> ready;
  bool _busy = false;
  String get _key => 'notification_inbox_v1:${edition.name}';

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final client = _clientFactory?.call() ?? ApiClient(baseUrl: edition.site);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      var items = state.items;
      if (items.isEmpty) {
        try {
          items = (jsonDecode(prefs.getString(_key) ?? '[]') as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {/* Ignore obsolete cache. */}
      }
      state = InboxState(
          items: items,
          read: {...?prefs.getStringList('$_key:read'), ...state.read},
          loading: true);
      final fresh = <Map<String, dynamic>>[];
      var page = 1;
      var pages = 1;
      do {
        final response = await client.get<Map<String, dynamic>>(
            '/wp-json/wood-panel-app/v1/notifications',
            queryParameters: {'page': page});
        fresh.addAll((response['items'] as List)
            .map((e) => Map<String, dynamic>.from(e)));
        pages = (response['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= pages && mounted);
      if (!mounted) return;
      final unique =
          {for (final item in fresh) '${item['id']}': item}.values.toList();
      state = InboxState(items: unique, read: state.read);
      await prefs.setString(_key, jsonEncode(unique));
    } catch (_) {
      if (mounted) {
        state = InboxState(items: state.items, read: state.read, error: true);
      }
    } finally {
      _busy = false;
      client.dio.close();
    }
  }

  Future<void> markRead(String id) async {
    state = InboxState(
        items: state.items,
        read: {...state.read, id},
        loading: state.loading,
        error: state.error);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final ids = {...?prefs.getStringList('$_key:read'), ...state.read, id};
    await prefs.setStringList('$_key:read', ids.toList());
    if (mounted) {
      state = InboxState(
          items: state.items,
          read: ids,
          loading: state.loading,
          error: state.error);
    }
  }
}

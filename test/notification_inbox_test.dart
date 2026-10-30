import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/notification_inbox.dart';
import 'package:wood_panel_app/core/network/api_client.dart';

class InboxApi extends ApiClient {
  InboxApi({this.fail = false});
  final bool fail;
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    if (fail) throw Exception('offline');
    final page = queryParameters!['page'];
    return {
      'pages': 2,
      'items': [
        {'id': page, 'article_id': page * 10, 'title': 'News $page'}
      ]
    } as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Fetch all pages, retain read state and isolate editions', () async {
    final europe =
        NotificationInbox(Edition.europe, clientFactory: InboxApi.new);
    final usa = NotificationInbox(Edition.usa, clientFactory: InboxApi.new);
    await Future.wait([europe.ready, usa.ready]);
    expect(europe.state.unread, 2);
    await europe.markRead('1');
    await europe.refresh();
    expect(europe.state.unread, 1);
    expect(usa.state.unread, 2);
    europe.dispose();
    usa.dispose();
    final restored = NotificationInbox(Edition.europe,
        clientFactory: () => InboxApi(fail: true));
    await restored.ready;
    expect(restored.state.items.length, 2);
    expect(restored.state.unread, 1);
    expect(restored.state.error, true);
    restored.dispose();
  });
  test('OS notification tap before history arrives stays read', () async {
    final inbox = NotificationInbox(Edition.usa, clientFactory: InboxApi.new);
    await inbox.markRead('1');
    await inbox.ready;
    expect(inbox.state.unread, 1);
    inbox.dispose();
  });
}

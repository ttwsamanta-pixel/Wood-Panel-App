import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/edition_navigation.dart';

void main() {
  test('Enabled notifications subscribe to both editions without unsubscribing',
      () async {
    final subscribed = <String>[];
    final removed = <String>[];
    await syncEditionPushSubscriptions(
        enabled: true,
        subscribe: (topic) async {
          subscribed.add(topic);
        },
        unsubscribe: (topic) async {
          removed.add(topic);
        });
    expect(subscribed, ['wood_panel_europe', 'wood_panel_usa']);
    expect(removed, isEmpty);
  });
  test('Disabling notifications removes both editions', () async {
    final subscribed = <String>[];
    final removed = <String>[];
    await syncEditionPushSubscriptions(
        enabled: false,
        subscribe: (topic) async {
          subscribed.add(topic);
        },
        unsubscribe: (topic) async {
          removed.add(topic);
        });
    expect(removed, ['wood_panel_europe', 'wood_panel_usa']);
    expect(subscribed, isEmpty);
  });
}

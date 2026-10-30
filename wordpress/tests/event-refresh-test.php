<?php
require __DIR__ . '/archive-test.php';

$GLOBALS['event_transients'] = ['wpam_home_events_v1' => [['imageUrl' => '']]];
$GLOBALS['event_requests'] = 0;
function get_transient($key) { return $GLOBALS['event_transients'][$key] ?? false; }
function set_transient($key, $value, $ttl) { $GLOBALS['event_transients'][$key] = $value; check($ttl === 300, 'Retain five-minute cache'); }
function add_query_arg($key, $value, $url) { return $url . '?' . urlencode($key) . '=' . urlencode($value); }
function is_wp_error($value) { return $value instanceof WP_Error; }
function wp_safe_remote_get($url, $args) {
    $GLOBALS['event_requests']++;
    check(str_contains($url, '?wpam_events_refresh='), 'Do not fetch stale bare homepage');
    check(($args['headers']['Cache-Control'] ?? '') === 'no-cache, max-age=0', 'Ask upstream to revalidate');
    return ['body' => '<div class="upcoming-event"><div class="upcoming-event-logo"><img src="data:image/svg+xml;base64,AA" data-breeze="https://www.woodandpanel.com/wp-content/uploads/2025/12/Mumbai-wood.jpg"></div><div class="upcoming-event-info"><strong>MUMBAI WOOD</strong><span>Sep 18 - Sep 20, 2026</span><span>Venue : Bombay Exhibition Centre</span></div></div>'];
}
function wp_remote_retrieve_response_code($r) { return 200; }
function wp_remote_retrieve_body($r) { return $r['body']; }

$GLOBALS['test_site'] = 'https://www.woodandpanel.com';
$events = wpam_home_events();
check($events[0]['imageUrl'] === 'https://www.woodandpanel.com/wp-content/uploads/2025/12/Mumbai-wood.jpg', 'Use current Breeze logo instead of placeholder');
check($events[0]['location'] === 'Bombay Exhibition Centre', 'Preserve event details');
check(wpam_home_events() === $events && $GLOBALS['event_requests'] === 1, 'Repeated app requests reuse transient');
echo "Event refresh: passed.\n";

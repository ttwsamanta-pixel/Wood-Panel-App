<?php
// Standalone contract tests. WordPress activation/database tests require staging.
define('ABSPATH', __DIR__);
class WP_Error { public function __construct(public string $code, public string $message, public array $data = []) {} }
function home_url($path = '') { return ($GLOBALS['test_site'] ?? 'https://www.woodandpanel.com') . $path; }
function wp_parse_url($url, $component = -1) { return parse_url($url, $component); }
function esc_url_raw($url, $protocols = []) { return filter_var($url, FILTER_VALIDATE_URL) ? $url : ''; }
require __DIR__ . '/../wood-panel-app-manager/includes/config.php';
require __DIR__ . '/../wood-panel-app-manager/includes/rest.php';
function check($condition, $message) { if (!$condition) { throw new RuntimeException($message); } }
$card = '<div class="archive-card"><img data-breeze="https://www.woodandpanel.com/cover.jpg" src="data:placeholder"><h2>JUL &ndash; AUG 2026</h2><ul><li>Engineered Wood</li></ul><a href="https://www.woodandpanel.com/flipbooks/2026/jul_aug/index.html">Read Online</a></div>';
$items = wpam_parse_archive($card, 2026);
check(count($items) === 1, 'Expected one archive issue');
check($items[0]['id'] === 202608, 'Issue identity must be stable');
check($items[0]['date'] === '2026-08-01T00:00:00Z', 'Expected issue month, not publication month');
check($items[0]['coverUrl'] === 'https://www.woodandpanel.com/cover.jpg', 'Lazy-loaded image must be used');
check($items[0]['pdfUrl'] === '', 'Do not invent a PDF URL');
check($items[0]['description'] === 'Engineered Wood', 'Expected clean topic text');
$other = str_replace('/flipbooks/', '.evil.example/flipbooks/', $card);
check(wpam_parse_archive($other, 2026) === [], 'Reject cross-site reader links');
check(wpam_https_url('javascript:alert(1)') === '', 'Reject unsafe URL scheme');
echo "Archive contract: 8 checks passed.\n";
$GLOBALS['test_site'] = 'https://www.woodandpanel.us';
$usa = '<li class="wpusa-interview-item"><h3>JUL - AUG 2026</h3><img src="data:placeholder" data-src="https://www.woodandpanel.us/cover.jpg"><ul><li>Mass Timber</li></ul><a href="https://www.woodandpanel.us/flipbook/2026/jul_aug26/index.html">Read Online</a></li>';
$items = wpam_parse_archive($usa, 2026);
check(count($items) === 1 && $items[0]['coverUrl'] === 'https://www.woodandpanel.us/cover.jpg', 'USA archive cover must use lazy image');
check($items[0]['date'] === '2026-08-01T00:00:00Z' && $items[0]['description'] === 'Mass Timber', 'USA issue date and topics');
check($items[0]['pdfUrl'] === '', 'USA PDF must not be guessed');
$events = wpam_parse_home_events('<article class="event-card"><img data-src="https://www.woodandpanel.us/event.jpg"><h3>IWF Atlanta</h3><p class="event-meta">Aug 25 - Aug 28, 2026</p><p class="event-meta">Venue: Atlanta</p></article><div class="upcoming-event"><div class="upcoming-event-date">Apr 07</div><div class="upcoming-event-info"><strong>UMIDS 2026</strong><span>Apr 07 - Apr 10, 2026</span><span>Venue : Krasnodar</span></div></div>');
check(count($events) === 2, 'Both event layouts must parse');
check($events[0]['location'] === 'Atlanta' && $events[0]['imageUrl'] !== '', 'USA event image and venue');
check($events[1]['date'] === 'Apr 07 - Apr 10, 2026' && $events[1]['location'] === 'Krasnodar', 'Europe event details');
check($events[1]['url'] === '' && $events[1]['imageUrl'] === '', 'Missing event links and images must not be invented');
echo "Regional archive and event layouts: 7 checks passed.\n";

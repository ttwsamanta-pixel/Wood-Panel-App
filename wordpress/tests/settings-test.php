<?php
define('ABSPATH', __DIR__);
function home_url($path = '') { return 'https://www.woodandpanel.us' . $path; }
function wp_parse_url($url, $part = -1) { return parse_url($url, $part); }
function wp_get_attachment_image_url($id, $size) { return ''; }
function get_theme_mod($key) { return 0; }
function post_type_exists($type) { return in_array($type, ['magazine', 'tribe_events'], true); }
function get_option($key, $default = []) { return $default; }
function esc_url_raw($url, $protocols = []) { return filter_var($url, FILTER_VALIDATE_URL) ? $url : ''; }
function sanitize_text_field($value) { return trim(strip_tags((string) $value)); }
function sanitize_key($value) { return preg_replace('/[^a-z0-9_-]/', '', strtolower($value)); }
function sanitize_hex_color($value) { return preg_match('/^#[a-f0-9]{6}$/i', $value) ? $value : ''; }
function absint($value) { return abs((int) $value); }
function term_exists($id, $taxonomy) { return $id > 0; }
function get_post_status($id) { return $id ? 'publish' : false; }
function get_post_type($id) { return $id === 8 ? 'page' : 'post'; }
function get_post_type_object($type) { return post_type_exists($type) ? (object) ['public' => true] : null; }
function add_settings_error(...$args) {}
require __DIR__ . '/../wood-panel-app-manager/includes/config.php';
function check($condition, $message) { if (!$condition) throw new RuntimeException($message); }
$input = ['edition' => 'usa', 'home_categories' => [5, 3, 5], 'explore_categories' => [9],
    'event_type' => 'tribe_events', 'event_date_key' => '_EventStartDate',
    'logo_url' => 'https://example.com/logo.png', 'preloader_url' => 'https://example.com/load.png',
    'preloader_color' => '#123456', 'branding_confirmed' => 1, 'sections' => ['latest', 'events'],
    'banners' => [['image_url' => 'https://example.com/banner.jpg', 'link_url' => 'javascript:alert(1)', 'label' => 'Banner']],
    'about_page_id' => 8, 'featured_ids' => '22,23', 'wallpapers_json' => '[]'];
$saved = wpam_sanitize_settings($input);
check($saved['home_categories'] === [5, 3], 'Category order and deduplication');
check($saved['explore_categories'] === [5, 3], 'Explore must share home selection');
check($saved['event_date_key'] === '_EventStartDate', 'Metadata keys are case-sensitive');
check($saved['preloader_url'] === $input['preloader_url'], 'Preloader image must save');
check($saved['preloader_color'] === '#123456', 'Preloader color must save');
check($saved['banners'][0]['link_url'] === '', 'Reject unsafe banner link');
check($saved['about_page_id'] === 8, 'Published page selection must save');
check($saved['featured_ids'] === [22, 23], 'Trending override must save');
check($saved['sections'] === ['latest', 'events'], 'Preserve section order');
check(wpam_sanitize_settings([])['home_categories'] === [], 'Unchecking all categories must clear them');
$input['inline_ads'] = [['image_url' => 'https://example.com/square.png', 'link_url' => 'https://example.com', 'label' => 'Square'], ['image_url' => 'javascript:bad']];
$input['footer_ads'] = [['image_url' => 'https://example.com/footer.png', 'label' => 'Footer']];
$ads = wpam_sanitize_settings($input);
check(count($ads['inline_ads']) === 1, 'Reject unsafe inline image URLs');
check($ads['inline_ads'][0]['label'] === 'Square', 'Keep inline ads separate');
check($ads['footer_ads'][0]['label'] === 'Footer', 'Keep footer ads separate');
check($ads['banners'][0]['label'] === 'Banner', 'Keep home banners unchanged');
check(wpam_sanitize_settings([])['footer_ads'] === [], 'Removing all ads disables placement');
check($ads['footer_ads'][0]['size'] === '350x50', 'Legacy footer defaults to short size');
$input['footer_ads'][0]['size'] = '350x100';
check(wpam_sanitize_settings($input)['footer_ads'][0]['size'] === '350x100', 'Tall footer size saves');
$input['footer_ads'][0]['size'] = 'invalid';
check(wpam_sanitize_settings($input)['footer_ads'][0]['size'] === '350x50', 'Invalid footer size uses safe default');
if (basename($_SERVER['SCRIPT_FILENAME']) === basename(__FILE__)) echo "Settings save contract: 18 checks passed.\n";

$storeInput = $input;
$storeInput['app_store_url'] = 'https://play.google.com/store/apps/details?id=com.example.app';
check(wpam_sanitize_settings($storeInput)['app_store_url'] === $storeInput['app_store_url'], 'Preserve Play Store link');
$storeInput['app_store_url'] = 'https://evil.example/store/apps/details?id=x';
check(wpam_sanitize_settings($storeInput)['app_store_url'] === '', 'Reject non-Play host');
$storeInput['app_store_url'] = 'https://play.google.com/store/apps/details';
check(wpam_sanitize_settings($storeInput)['app_store_url'] === '', 'Require package id');
echo "App store setting: passed.\n";

$storeInput['ios_store_url'] = 'https://apps.apple.com/us/app/wood-panel/id123456789';
check(wpam_sanitize_settings($storeInput)['ios_store_url'] === $storeInput['ios_store_url'], 'Preserve iOS App Store URL');
$storeInput['ios_store_url'] = 'https://apps.apple.com.evil.test/app/id123';
check(wpam_sanitize_settings($storeInput)['ios_store_url'] === '', 'Reject fake Apple host');
$storeInput['ios_store_url'] = 'https://apps.apple.com/app/missing-id';
check(wpam_sanitize_settings($storeInput)['ios_store_url'] === '', 'Require numeric Apple app ID');
echo "iOS store setting: passed.\n";

<?php
// Isolated tests: no network requests or live notifications.
define('ABSPATH', __DIR__);
class WP_Error { public function __construct(public $code, public $message) {} public function get_error_message() { return $this->message; } }
function is_wp_error($v) { return $v instanceof WP_Error; }
function add_action(...$args) {}
function current_user_can($cap) { return $GLOBALS['allowed']; }
function user_can($id, $cap) { return $GLOBALS['allowed']; }
function wpam_edition() { return $GLOBALS['edition']; }
function get_post($id) { return $GLOBALS['posts'][$id] ?? null; }
function get_post_type($id) { return get_post($id)->post_type ?? ''; }
function get_post_meta($id, $key, $single) { return $GLOBALS['meta'][$id][$key] ?? ''; }
function update_post_meta($id, $key, $value) { $GLOBALS['meta'][$id][$key] = $value; }
function add_option($key, $value, ...$args) { if (isset($GLOBALS['options'][$key])) return false; $GLOBALS['options'][$key] = $value; return true; }
function delete_option($key) { unset($GLOBALS['options'][$key]); }
function wp_timezone() { return new DateTimeZone('Asia/Kolkata'); }
function get_post_thumbnail_id($id) { return $GLOBALS['attachment']; }
function wp_get_attachment_metadata($id) { return ['sizes' => ['medium' => ['file' => 'sample.jpg']]]; }
function wp_get_attachment_image_src($id, $size) { return [$GLOBALS['image'], 300, 200, true]; }
function get_attached_file($id) { return $GLOBALS['directory'] . '/original.jpg'; }
function esc_url_raw($url, $protocols = []) { return $url; }
function wp_parse_url($url, $part) { return parse_url($url, $part); }
function get_the_title($id) { return get_post($id)->post_title; }
function get_the_excerpt($post) { return 'Some <b>news</b> for readers.'; }
function wp_strip_all_tags($v) { return strip_tags($v); }
function wp_trim_words($v, $n) { return $v; }
function wp_json_encode($v) { return json_encode($v); }
function wp_remote_post($url, $args) {
    if (str_contains($url, 'oauth2')) return ['code' => 200, 'body' => '{"access_token":"test"}'];
    $GLOBALS['sent'][] = json_decode($args['body'], true);
    return ['code' => $GLOBALS['http_code'], 'body' => '{}'];
}
function wp_remote_retrieve_response_code($r) { return $r['code']; }
function wp_remote_retrieve_body($r) { return $r['body']; }
function check($condition, $message) { if (!$condition) throw new RuntimeException($message); $GLOBALS['checks']++; }
$checks = 0; $allowed = true; $edition = 'europe'; $attachment = 1; $options = []; $meta = []; $sent = []; $http_code = 200;
$image = 'https://example.com/sample.jpg';
$directory = sys_get_temp_dir() . '/wpam-push-test-' . bin2hex(random_bytes(6));
mkdir($directory);
file_put_contents($directory . '/sample.jpg', 'test-image');
$key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA, 'config' => 'C:/xampp/php/extras/ssl/openssl.cnf']);
openssl_pkey_export($key, $private, null, ['config' => 'C:/xampp/php/extras/ssl/openssl.cnf']);
define('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE', $directory . '/test-key.json');
file_put_contents(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE, json_encode(['private_key' => $private, 'client_email' => 'test@example.com', 'project_id' => 'test-project']));
$posts = [1 => (object) ['ID' => 1, 'post_type' => 'post', 'post_status' => 'publish', 'post_password' => '', 'post_title' => 'Wood &amp; Panel']];
require __DIR__ . '/../wood-panel-app-manager/includes/notifications.php';
function job($id, $extra = []) {
    $GLOBALS['posts'][$id] = (object) ['post_type' => 'wpam_push_job', 'post_author' => 1];
    $GLOBALS['meta'][$id] = array_merge(['state' => 'scheduled', 'article_id' => 1, 'edition' => 'europe', 'send_at' => time() - 1], $extra);
}
try {
    $payload = wpam_notification_message($posts[1], 'europe');
    check($payload['android']['notification']['image'] === $image, 'Android image');
    check($payload['apns']['payload']['aps']['mutable-content'] === 1 && $payload['data']['image_url'] === $image, 'iOS extension image and mutable content');
    check($payload['topic'] === 'wood_panel_europe' && $payload['data']['article_id'] === '1', 'Edition and article navigation');
    check($payload['notification']['title'] === 'Wood & Panel', 'Headline entities');
    $attachment = 0;
    check(!isset(wpam_notification_message($posts[1], 'usa')['android']), 'Missing image keeps text only');
    $attachment = 1; $image = 'http://example.com/a.jpg';
    check(wpam_notification_image(1) === '', 'Require HTTPS');
    $image = 'https://example.com/a.svg';
    check(wpam_notification_image(1) === '', 'Reject unsupported image');
    $image = 'https://example.com/sample.jpg';
    file_put_contents($directory . '/sample.jpg', str_repeat('x', 1048577)); clearstatcache();
    check(wpam_notification_image(1) === '', 'Oversized image fallback');
    file_put_contents($directory . '/sample.jpg', 'test-image'); clearstatcache();
    $date = (new DateTimeImmutable('+2 days', wp_timezone()))->format('Y-m-d\TH:i');
    check(wpam_notification_timestamp($date) === (new DateTimeImmutable($date, wp_timezone()))->getTimestamp(), 'Convert site timezone to timestamp');
    check(is_wp_error(wpam_notification_timestamp('2020-01-01T10:00')), 'Reject past time');
    check(is_wp_error(wpam_notification_timestamp('2030-02-31T12:00')), 'Reject invalid date');
    $allowed = false;
    check(is_wp_error(wpam_send_notification(1)), 'Manual sender authorization');
    $allowed = true;
    job(10); wpam_notification_run(10);
    check($meta[10]['state'] === 'accepted' && count($sent) === 1, 'Cron works without logged-in user');
    wpam_notification_run(10);
    check(count($sent) === 1, 'Repeated cron does not resend');
    job(11); add_option('wpam_push_lock_11', time()); wpam_notification_run(11);
    check(count($sent) === 1, 'Concurrent worker lock');
    job(12, ['state' => 'cancelled']); wpam_notification_run(12);
    check(count($sent) === 1, 'Cancelled job does not send');
    job(13, ['send_at' => time() + 600]); wpam_notification_run(13);
    check(count($sent) === 1, 'Do not send early');
    job(14); $posts[1]->post_status = 'draft'; wpam_notification_run(14);
    check($meta[14]['state'] === 'failed' && count($sent) === 1, 'Revalidate published article at send time');
    $posts[1]->post_status = 'publish'; job(15); $edition = 'usa'; wpam_notification_run(15);
    check($meta[15]['state'] === 'failed' && count($sent) === 1, 'Do not send to changed edition');
    $edition = 'europe'; job(16); $allowed = false; wpam_notification_run(16);
    check($meta[16]['state'] === 'failed' && count($sent) === 1, 'Revoked author permission');
    $allowed = true; job(17); $http_code = 500; wpam_notification_run(17);
    check($meta[17]['state'] === 'failed', 'FCM failure recorded');
    wpam_notification_run(17); check(count($sent) === 2, 'No automatic retry of ambiguous failure');
    echo "$checks notification checks passed\n";
} finally {
    unlink(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE);
    unlink($directory . '/sample.jpg');
    rmdir($directory);
}

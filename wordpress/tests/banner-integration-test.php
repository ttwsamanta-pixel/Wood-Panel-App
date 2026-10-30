<?php
// Real WP + MariaDB, isolated fixture only. See banner-integration-setup.php.
require dirname(__DIR__, 2) . '/artifacts/wp-test/wordpress/wp-load.php';
if (DB_NAME !== 'wpam_banner_test' || DB_HOST !== '127.0.0.1:3317') throw new RuntimeException('Test database required');
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$checks = 0;
function verify($condition, $message) { global $checks; if (!$condition) throw new RuntimeException($message); $checks++; }
wp_set_current_user(get_user_by('login', 'banneradmin')->ID);
if (!is_plugin_active('wood-panel-app-manager/wood-panel-app-manager.php')) {
    // Seed old-format settings BEFORE activating to verify the upgrade.
    update_option('wpam_settings', ['edition' => 'europe', 'label' => 'Europe', 'banners' => [['image_url' => 'https://example.com/home.png', 'label' => 'Legacy home', 'link_url' => '']],
        'inline_ads' => [['image_url' => 'https://example.com/square.png', 'label' => 'Legacy inline', 'link_url' => '']],
        'footer_ads' => [['image_url' => 'https://example.com/footer.png', 'label' => 'Legacy footer', 'link_url' => 'https://example.com', 'size' => '350x100']]]);
    $result = activate_plugin('wood-panel-app-manager/wood-panel-app-manager.php');
    verify(!is_wp_error($result), 'Activation failed');
    wpam_register_banners(); wpam_banner_upgrade();
}
verify(get_option('wpam_ad_db_version') === '1', 'Tables not installed');
verify((bool) get_option('wpam_banners_migrated'), 'Migration missing');
$ids = get_posts(['post_type' => 'wpam_banner', 'post_status' => 'any', 'numberposts' => -1, 'meta_key' => '_wpam_legacy_key', 'fields' => 'ids']);
verify(count($ids) === 3, 'Legacy banners lost or duplicated');
wpam_banner_upgrade();
verify(count(get_posts(['post_type' => 'wpam_banner', 'numberposts' => -1, 'meta_key' => '_wpam_legacy_key'])) === 3, 'Repeated upgrade duplicates banners');
verify((bool) get_option('wpam_banner_legacy_backup'), 'Legacy backup missing');
$footer = wpam_live_banners('footer_ads');
verify(count($footer) >= 1 && $footer[0]['size'] === '350x100', 'Migration loses footer size');
$id = wp_insert_post(['post_type' => 'wpam_banner', 'post_status' => 'publish', 'post_title' => 'Integration banner ' . time(), 'meta_input' => [
    '_wpam_placement' => 'footer_ads', '_wpam_image' => 'https://example.com/ad.png', '_wpam_link' => 'https://example.com', '_wpam_active' => '1', '_wpam_size' => '350x50']]);
verify(wpam_banner_status($id) === 'Live', 'Published active banner should be live');
update_post_meta($id, '_wpam_end', '2001-01-01'); verify(wpam_banner_status($id) === 'Expired', 'Expiry ignored');
verify(!in_array((string) $id, array_column(wpam_live_banners('footer_ads'), 'id'), true), 'Expired ad is public');
update_post_meta($id, '_wpam_end', ''); update_post_meta($id, '_wpam_start', '2999-01-01'); verify(wpam_banner_status($id) === 'Scheduled', 'Start ignored');
update_post_meta($id, '_wpam_start', ''); update_post_meta($id, '_wpam_active', '0'); verify(wpam_banner_status($id) === 'Paused', 'Pause ignored');
update_post_meta($id, '_wpam_active', '1');
verify(wpam_banner_date('2026-02-31') === '' && wpam_banner_date('2024-02-29') === '2024-02-29', 'Date validation');
$event = ['banner_id' => $id, 'placement' => 'footer_ads', 'token' => wpam_banner_token($id, 'footer_ads'), 'view_id' => bin2hex(random_bytes(16)), 'type' => 'impression'];
function send_event($data) { $r = new WP_REST_Request('POST'); $r->set_header('Content-Type', 'application/json'); $r->set_body(wp_json_encode($data)); return wpam_ad_event($r); }
verify(send_event($event)->get_data()['recorded'] === true, 'First impression not recorded');
verify(send_event($event)->get_data()['recorded'] === false, 'Retry counted twice');
$event['type'] = 'click'; verify(send_event($event)->get_data()['recorded'] === true, 'Click not counted');
verify(send_event($event)->get_data()['recorded'] === false, 'Repeated click counted twice');
$stats = wpam_ad_totals($id); verify($stats === ['impressions' => 1, 'clicks' => 1], 'Totals incorrect');
verify(wpam_ad_ctr($stats) === '100.00' && wpam_ad_ctr(['impressions' => 0, 'clicks' => 1]) === '0.00', 'CTR formula/zero division');
$bad = $event; $bad['token'] = 'fake'; verify(is_wp_error(send_event($bad)), 'Bad token accepted');
$bad = $event; $bad['placement'] = 'inline_ads'; verify(is_wp_error(send_event($bad)), 'Wrong placement accepted');
$bad = $event; $bad['view_id'] = ['bad']; verify(is_wp_error(send_event($bad)), 'Malformed event accepted');
update_post_meta($id, '_wpam_active', '0'); verify(is_wp_error(send_event($event)), 'Paused banner accepts events'); update_post_meta($id, '_wpam_active', '1');
$rows = wpam_ad_days($id, current_time('Y-m-d'), current_time('Y-m-d')); verify(count($rows) === 1 && $rows[0]['impressions'] === 1, 'Daily report incorrect');
$_GET = ['banner_id' => $id]; ob_start(); wpam_banner_reports(); $html = ob_get_clean();
verify(str_contains($html, '100.00%') && str_contains($html, '<svg') && str_contains($html, 'Export options'), 'Detailed report incomplete');
$_GET = []; ob_start(); wpam_banner_reports(); $html = ob_get_clean(); verify(str_contains($html, 'App Banner Reports') && str_contains($html, 'Integration banner'), 'Report list missing');
wp_set_current_user(0); ob_start(); wpam_banner_reports(); verify(ob_get_clean() === '', 'Unauthenticated reporting allowed');
echo "Banner integration: $checks checks passed.\n";

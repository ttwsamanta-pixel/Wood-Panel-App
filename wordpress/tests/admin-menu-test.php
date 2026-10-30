<?php
// Standalone registration and page-render checks; no database or push is used.
define('ABSPATH', __DIR__);
$actions = [];
$menus = [];
$allowed = true;
function add_action($hook, $callback) { $GLOBALS['actions'][$hook][] = $callback; }
function add_filter(...$args) {}
function remove_submenu_page(...$args) {}
function plugin_dir_url($file) { return 'http://localhost/plugins/'; }
function wp_enqueue_script(...$args) {}
function wp_localize_script(...$args) {}
function admin_url($path) { return 'http://localhost/wp-admin/' . $path; }
function wp_create_nonce($action) { return 'test'; }
function get_current_user_id() { return 1; }
function get_transient($key) { return false; }
function wp_timezone_string() { return '+05:30'; }
function esc_url($url) { return htmlspecialchars($url); }
function esc_attr($text) { return htmlspecialchars($text); }
function wp_nonce_field($action) {}
function wp_generate_uuid4() { return 'test-request'; }
function submit_button(...$args) {}
function get_posts($args) { return []; }
function register_activation_hook($file, $callback) {}
function add_menu_page($title, $label, $capability, $slug, $callback, $icon) {
    $GLOBALS['menus'][$slug] = ['callback' => $callback, 'children' => []];
}
function add_submenu_page($parent, $title, $label, $capability, $slug, $callback = null) {
    if (!isset($GLOBALS['menus'][$parent])) throw new RuntimeException('Submenu registered before its parent');
    $GLOBALS['menus'][$parent]['children'][$slug] = ['label' => $label, 'callback' => $callback, 'capability' => $capability];
}
function current_user_can($capability) { return $GLOBALS['allowed']; }
function add_options_page($title, $label, $capability, $slug, $callback) {
    check($slug === 'wpam-configuration', 'Fallback must have an independent slug');
    check($capability === 'manage_options' && $callback === 'wpam_admin_page', 'Fallback must reuse protected Settings');
}
function home_url() { return 'https://www.woodandpanel.us'; }
function wp_parse_url($url, $component) { return parse_url($url, $component); }
function esc_html($text) { return htmlspecialchars($text, ENT_QUOTES, 'UTF-8'); }
function check($condition, $message) { if (!$condition) throw new RuntimeException($message); }
require __DIR__ . '/../wood-panel-app-manager/wood-panel-app-manager.php';
foreach ($actions['admin_menu'] as $callback) $callback();
$children = $menus['wood-panel-app-settings']['children'];
check(array_keys($children) === ['wood-panel-app-settings', 'wpam-notifications', 'wpam-profiles', 'wpam-submissions', 'post-new.php?post_type=wpam_banner', 'wpam-banner-reports'], 'Settings must be the first submenu');
check($children['wood-panel-app-settings']['callback'] === $menus['wood-panel-app-settings']['callback'], 'Parent and Settings must share a callback');
foreach ($children as $child) {
    check(is_callable($child['callback']) || $child['label'] === 'Add Banner', 'Page callback must exist');
    check($child['capability'] === 'manage_options', 'Admin access must be required');
}
$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
wpam_notifications_page();
$html = ob_get_clean();
check(str_contains($html, 'Usa'), 'Notification page must target this edition');
check(str_contains($html, 'WPAM_FIREBASE_SERVICE_ACCOUNT_FILE'), 'Missing Firebase credentials must show guidance, not crash');
$allowed = false;
ob_start();
wpam_notifications_page();
check(ob_get_clean() === '', 'Non-admin must not see the notification page');
echo "Admin menu and notification page: 11 checks passed.\n";

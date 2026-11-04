<?php
// Exercise null pagination with strict errors and a read-only database stub.
define('ABSPATH', __DIR__);
set_error_handler(static function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});
function current_user_can($capability) { return $GLOBALS['can_manage'] ?? true; }
function esc_html($value) { return htmlspecialchars((string)$value, ENT_QUOTES); }
function esc_attr($value) { return esc_html($value); }
function wp_nonce_field($action) { echo '<input name="_wpnonce" value="test">'; }
function absint($value) { return abs((int) $value); }
function admin_url($path) { return 'https://example.com/wp-admin/' . $path; }
function esc_url($value) { return htmlspecialchars($value, ENT_QUOTES); }
function add_query_arg($key, $value) { return admin_url('admin.php?page=wpam-submissions&' . $key . '=' . $value); }
function paginate_links($args) { return $args['total'] < 2 ? null : '<a>Next</a>'; }
function wp_kses_post($value) {
    if (!is_string($value)) throw new RuntimeException('Sanitizer must receive a string');
    return $value;
}
$wpdb = new class {
    public string $prefix = 'wp_';
    public int $count = 0;
    public array $queries = [];
    public function prepare($sql, ...$args) { $this->queries[] = [$sql, $args]; return $sql; }
    public function get_var($sql) { return $this->count; }
    public function get_results($sql) { return []; }
};
require __DIR__ . '/../wood-panel-app-manager/includes/profiles.php';
$_SERVER['REQUEST_METHOD'] = 'GET';
foreach (['newsletter', 'contact', 'profile'] as $kind) {
foreach ([0, 25, 26] as $count) {
    $_GET = ['kind' => $kind];
    $wpdb->queries = [];
    $wpdb->count = $count;
    ob_start();
    wpam_submissions_page();
    $output = ob_get_clean();
    if ($wpdb->queries[0][1][0] !== $kind || $wpdb->queries[1][1] !== [$kind, 0]) throw new RuntimeException('Wrong submission kind or offset');
    if (!str_contains($output, 'Download CSV') || !str_contains($output, 'Delete selected')) throw new RuntimeException('Missing submission controls');
    if (str_contains($output, '<a>Next</a>') !== ($count > 25)) {
        throw new RuntimeException('Incorrect pagination output');
    }
}
}
$_GET = ['kind'=>'contact', 'paged'=>2];
$wpdb->queries = [];
ob_start(); wpam_profiles_page(); ob_end_clean();
if ($wpdb->queries[1][1] !== ['profile', 25]) throw new RuntimeException('Profile route or second-page offset incorrect');
$GLOBALS['can_manage'] = false;
$wpdb->queries = [];
ob_start(); wpam_submissions_page(); $output = ob_get_clean();
if ($output !== '' || $wpdb->queries) throw new RuntimeException('Unauthorized submissions access');
echo "Submissions: 9 pagination cases, profile route and access restriction passed.\n";

<?php
// Exercise null pagination with strict errors and a read-only database stub.
define('ABSPATH', __DIR__);
set_error_handler(static function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});
function current_user_can($capability) { return true; }
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
    public function prepare($sql, ...$args) { return $sql; }
    public function get_var($sql) { return $this->count; }
    public function get_results($sql) { return []; }
};
require __DIR__ . '/../wood-panel-app-manager/includes/admin.php';
$_SERVER['REQUEST_METHOD'] = 'GET';
foreach ([0, 25, 26] as $count) {
    $wpdb->count = $count;
    ob_start();
    wpam_submissions_page();
    $output = ob_get_clean();
    if (str_contains($output, '<a>Next</a>') !== ($count > 25)) {
        throw new RuntimeException('Incorrect pagination output');
    }
}
echo "Submissions pagination: 3 cases passed.\n";

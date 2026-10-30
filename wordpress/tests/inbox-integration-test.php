<?php
// Local WordPress only; never sends FCM or changes either production website.
require dirname(__DIR__, 2) . '/artifacts/wp-test/wordpress/wp-load.php';
if (DB_NAME !== 'wpam_banner_test' || DB_HOST !== '127.0.0.1:3317') throw new RuntimeException('Test database required');
$ids = []; $checks = 0;
function inbox_check($ok, $message) { if (!$ok) throw new RuntimeException($message); $GLOBALS['checks']++; }
try {
    foreach (['publish', 'draft', 'private'] as $status) {
        $post = wp_insert_post(['post_title' => 'Inbox ' . $status, 'post_content' => 'Wood industry news.', 'post_status' => $status]); $ids[] = $post;
        foreach (['accepted', 'failed', 'scheduled'] as $state) {
            $ids[] = wp_insert_post(['post_type' => 'wpam_push_job', 'post_status' => 'private', 'post_title' => 'Test job', 'meta_input' => ['state' => $state, 'edition' => wpam_edition(), 'article_id' => $post, 'processed_at' => time()]]);
        }
    }
    wp_set_current_user(0);
    $request = new WP_REST_Request('GET', '/wood-panel-app/v1/notifications');
    $response = rest_do_request($request);
    inbox_check($response->get_status() === 200, 'Public inbox must be readable without login');
    $data = $response->get_data();
    $testItems = array_values(array_filter($data['items'], fn($item) => in_array($item['id'], $ids, true)));
    inbox_check(count($testItems) === 1, 'Only accepted notifications about public articles may be exposed');
    inbox_check(!isset($testItems[0]['result']) && !isset($testItems[0]['author']), 'No private job information');
    inbox_check($testItems[0]['title'] === 'Inbox publish', 'Article metadata returned');
    wp_update_post(['ID' => $testItems[0]['article_id'], 'post_password' => 'private']);
    $data = rest_do_request($request)->get_data();
    inbox_check(!array_filter($data['items'], fn($item) => in_array($item['id'], $ids, true)), 'Password-protected articles must disappear');
    $defaults = wpam_defaults();
    $defaults['contact_details']['usa_address'] = "New office\nSecond floor";
    $defaults['contact_details']['team_name'] = '<script>unsafe</script>Editor';
    $saved = wpam_sanitize_settings($defaults);
    inbox_check($saved['contact_details']['usa_address'] === "New office\nSecond floor", 'Multiline address saved');
    inbox_check(!str_contains($saved['contact_details']['team_name'], '<'), 'Contact fields sanitized');
    echo "$checks inbox and contact integration checks passed.\n";
} finally {
    foreach ($ids as $id) wp_delete_post($id, true);
}

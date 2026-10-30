<?php
defined('ABSPATH') || exit;

// Only successfully accepted sends enter the public inbox. Drafts, schedules,
// recipients, credentials and transport errors are never returned here.
add_action('rest_api_init', static function (): void {
    register_rest_route(WPAM_NAMESPACE, '/notifications', [
        'methods' => 'GET', 'permission_callback' => '__return_true',
        'callback' => 'wpam_notification_inbox',
        'args' => ['page' => ['default' => 1, 'sanitize_callback' => 'absint']],
    ]);
});

function wpam_notification_inbox($request) {
    $query = new WP_Query([
        'post_type' => 'wpam_push_job', 'post_status' => 'private',
        'posts_per_page' => 100, 'paged' => max(1, (int) $request['page']),
        'meta_key' => 'processed_at', 'orderby' => ['meta_value_num' => 'DESC', 'ID' => 'DESC'],
        'meta_query' => [
            ['key' => 'state', 'value' => 'accepted'],
            ['key' => 'edition', 'value' => wpam_edition()],
        ],
    ]);
    $items = [];
    foreach ($query->posts as $job) {
        $post = wpam_notification_post((int) get_post_meta($job->ID, 'article_id', true));
        if (is_wp_error($post)) continue;
        $categories = get_the_category($post->ID);
        $items[] = [
            'id' => (int) $job->ID, 'article_id' => (int) $post->ID,
            'title' => html_entity_decode(wp_strip_all_tags(get_the_title($post->ID)), ENT_QUOTES, 'UTF-8'),
            'body' => html_entity_decode(wp_trim_words(wp_strip_all_tags(get_the_excerpt($post)), 24), ENT_QUOTES, 'UTF-8'),
            'image' => get_the_post_thumbnail_url($post->ID, 'medium') ?: '',
            'category' => $categories ? html_entity_decode($categories[0]->name, ENT_QUOTES, 'UTF-8') : '',
            'sent_at' => gmdate('c', (int) get_post_meta($job->ID, 'processed_at', true)),
        ];
    }
    $response = new WP_REST_Response(['items' => $items, 'pages' => (int) $query->max_num_pages]);
    $response->header('Cache-Control', 'no-store');
    return $response;
}

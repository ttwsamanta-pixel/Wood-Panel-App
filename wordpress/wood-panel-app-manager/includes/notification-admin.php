<?php
defined('ABSPATH') || exit;

add_action('init', static function () {
    register_post_type('wpam_push_job', ['public' => false, 'show_ui' => false, 'supports' => ['title'], 'rewrite' => false]);
});
add_action('wp_ajax_wpam_news_search', 'wpam_news_search');
add_action('admin_post_wpam_notification', 'wpam_notification_action');
add_action('wpam_notification_due', 'wpam_notification_run');

function wpam_news_search(): void {
    if (!current_user_can('manage_options')) wp_send_json_error('Not permitted.', 403);
    check_ajax_referer('wpam_news_search');
    global $wpdb;
    $term = sanitize_text_field(wp_unslash($_GET['q'] ?? ''));
    // Match titles only; restrict results to public published articles on this site.
    $ids = $wpdb->get_col($wpdb->prepare(
        "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'post' AND post_status = 'publish' AND post_password = '' AND post_title LIKE %s ORDER BY post_date DESC LIMIT 20",
        '%' . $wpdb->esc_like($term) . '%'
    ));
    $items = [];
    foreach ($ids as $id) {
        $items[] = ['id' => (int) $id, 'title' => html_entity_decode(get_the_title($id), ENT_QUOTES, 'UTF-8'),
            'published' => get_the_date('j M Y', $id) . ' ' . get_the_time('H:i', $id),
            'image' => wpam_notification_image((int) $id)];
    }
    wp_send_json_success($items);
}

function wpam_notification_timestamp(string $value) {
    $date = DateTimeImmutable::createFromFormat('!Y-m-d\TH:i', $value, wp_timezone());
    if (!$date || $date->format('Y-m-d\TH:i') !== $value || $date->getTimestamp() <= time()) {
        return new WP_Error('invalid_time', 'Choose a future date and time in the website timezone.');
    }
    return $date->getTimestamp();
}

function wpam_notification_result(string $message, bool $error = false): void {
    set_transient('wpam_push_notice_' . get_current_user_id(), ['message' => $message, 'error' => $error], 120);
    wp_safe_redirect(admin_url('admin.php?page=wpam-notifications'));
    exit;
}

function wpam_notification_action(): void {
    if (!current_user_can('manage_options')) wp_die('Not permitted.', '', ['response' => 403]);
    check_admin_referer('wpam_notification');
    if (isset($_POST['cancel_job'])) {
        $id = absint($_POST['cancel_job']);
        if (get_post_type($id) !== 'wpam_push_job') wpam_notification_result('Notification not found.', true);
        $lock = 'wpam_push_lock_' . $id;
        if (!add_option($lock, time(), '', false)) wpam_notification_result('This notification is already being processed.', true);
        if (get_post_meta($id, 'state', true) === 'scheduled') {
            update_post_meta($id, 'state', 'cancelled');
            wp_clear_scheduled_hook('wpam_notification_due', [$id]);
        }
        delete_option($lock);
        wpam_notification_result('Schedule cancelled if it was still pending.');
    }
    $article = absint($_POST['article_id'] ?? 0);
    $post = wpam_notification_post($article);
    if (is_wp_error($post)) wpam_notification_result($post->get_error_message(), true);
    if (!defined('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE') || !is_readable(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE)) {
        wpam_notification_result('Firebase credentials are not configured or readable.', true);
    }
    $later = ($_POST['delivery'] ?? '') === 'schedule';
    $at = $later ? wpam_notification_timestamp(sanitize_text_field(wp_unslash($_POST['send_at'] ?? ''))) : time();
    if (is_wp_error($at)) wpam_notification_result($at->get_error_message(), true);
    // Prevent double clicks, browser retries and back/forward resubmissions.
    $request = sanitize_key($_POST['request_id'] ?? '');
    if (!preg_match('/^[a-f0-9-]{36}$/', $request)) wpam_notification_result('Reload the page and try again.', true);
    $request_key = 'wpam_push_request_' . get_current_user_id() . '_' . $request;
    if (!add_option($request_key, time(), '', false)) wpam_notification_result('This request has already been submitted.', true);
    $id = wp_insert_post(['post_type' => 'wpam_push_job', 'post_status' => 'private',
        'post_title' => $post->post_title, 'post_author' => get_current_user_id(),
        'meta_input' => ['article_id' => $article, 'edition' => wpam_edition(), 'send_at' => $at,
            'state' => 'scheduled', 'request_key' => $request_key]], true);
    if (is_wp_error($id)) {
        delete_option($request_key);
        wpam_notification_result('Could not save the notification.', true);
    }
    if ($later) {
        $scheduled = wp_schedule_single_event($at, 'wpam_notification_due', [(int) $id], true);
        if (is_wp_error($scheduled) || !$scheduled) {
            update_post_meta($id, 'state', 'failed');
            update_post_meta($id, 'result', 'WordPress could not schedule this notification.');
            wpam_notification_result('Scheduling failed. Please try a new request.', true);
        }
        wpam_notification_result('Notification scheduled in ' . wp_timezone_string() . '.');
    }
    wpam_notification_run((int) $id);
    $state = get_post_meta($id, 'state', true);
    wpam_notification_result((string) get_post_meta($id, 'result', true), $state !== 'accepted');
}

function wpam_notification_run(int $id): void {
    if (get_post_type($id) !== 'wpam_push_job' || get_post_meta($id, 'state', true) !== 'scheduled') return;
    if ((int) get_post_meta($id, 'send_at', true) > time()) return;
    // Atomic option insertion prevents two cron workers sending the same job.
    $lock = 'wpam_push_lock_' . $id;
    if (!add_option($lock, time(), '', false)) return;
    try {
        if (get_post_meta($id, 'state', true) !== 'scheduled') return;
        update_post_meta($id, 'state', 'sending');
        $job = get_post($id);
        if (!$job || !user_can((int) $job->post_author, 'manage_options')) {
            $result = new WP_Error('permission', 'The scheduling user no longer has permission to send notifications.');
        } else {
            $result = wpam_deliver_notification((int) get_post_meta($id, 'article_id', true), (string) get_post_meta($id, 'edition', true), $id);
        }
        update_post_meta($id, 'state', is_wp_error($result) ? 'failed' : 'accepted');
        update_post_meta($id, 'result', is_wp_error($result) ? $result->get_error_message() : 'Firebase accepted the notification. Delivery depends on device permissions and connectivity.');
        update_post_meta($id, 'processed_at', time());
    } catch (Throwable $error) {
        update_post_meta($id, 'state', 'failed');
        update_post_meta($id, 'result', 'Sending was interrupted. Check delivery before manually sending again.');
    } finally {
        delete_option($lock);
    }
}

function wpam_notifications_page(): void {
    if (!current_user_can('manage_options')) return;
    $base = plugin_dir_url(dirname(__DIR__) . '/wood-panel-app-manager.php');
    wp_enqueue_script('wpam-notifications', $base . 'assets/notifications.js', [], '0.6.0', true);
    wp_localize_script('wpam-notifications', 'wpamNotifications', ['url' => admin_url('admin-ajax.php'), 'nonce' => wp_create_nonce('wpam_news_search')]);
    echo '<div class="wrap"><h1>App Notifications</h1>';
    $notice = get_transient('wpam_push_notice_' . get_current_user_id());
    if ($notice) {
        delete_transient('wpam_push_notice_' . get_current_user_id());
        echo '<div class="notice ' . (!empty($notice['error']) ? 'notice-error' : 'notice-success') . '"><p>' . esc_html($notice['message']) . '</p></div>';
    }
    echo '<p>Send news to <strong>' . esc_html(ucfirst(wpam_edition())) . '</strong> subscribers only. Publication and schedule times use <strong>' . esc_html(wp_timezone_string()) . '</strong>.</p>';
    if (!defined('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE')) {
        echo '<div class="notice notice-warning"><p>Set WPAM_FIREBASE_SERVICE_ACCOUNT_FILE in wp-config.php to a private service-account JSON file outside public_html.</p></div>';
    }
    echo '<form id="wpam-notification-form" action="' . esc_url(admin_url('admin-post.php')) . '" method="post" style="background:#fff;padding:24px;max-width:850px;border:1px solid #ddd;border-radius:10px">';
    wp_nonce_field('wpam_notification');
    echo '<input type="hidden" name="action" value="wpam_notification"><input type="hidden" name="request_id" value="' . esc_attr(wp_generate_uuid4()) . '">';
    echo '<h2>Select news</h2><label for="wpam-news-search">Search by news title</label><p><input id="wpam-news-search" type="search" class="large-text" placeholder="Type a headline…" autocomplete="off"></p>';
    echo '<div id="wpam-news-results" aria-live="polite" style="max-height:300px;overflow:auto"></div><p id="wpam-news-selected" aria-live="polite"></p>';
    echo '<p><label for="wpam-article-id">Published article ID (selected automatically, or enter manually)</label><br><input id="wpam-article-id" type="number" name="article_id" min="1" required></p>';
    echo '<p>A small featured image is included when available. Otherwise, a text notification is sent.</p><h2>Delivery</h2>';
    echo '<label><input type="radio" name="delivery" value="now" checked> Send now</label> &nbsp; <label><input type="radio" name="delivery" value="schedule"> Schedule</label>';
    echo '<p id="wpam-schedule" hidden><label>Date and time (' . esc_html(wp_timezone_string()) . ')<br><input type="datetime-local" name="send_at"></label></p>';
    submit_button('Send notification', 'primary', 'submit', true, ['id' => 'wpam-notification-submit']);
    echo '</form><p>Schedules run through WordPress Cron. For reliable timing, configure your hosting cron to run WordPress Cron every minute. Failed sends are not automatically retried to avoid duplicate alerts.</p>';
    echo '<h2>Recent notifications and schedules</h2><table class="widefat striped"><thead><tr><th>News</th><th>Scheduled / sent time</th><th>Status</th><th>Result / action</th></tr></thead><tbody>';
    $jobs = get_posts(['post_type' => 'wpam_push_job', 'post_status' => 'private', 'numberposts' => 50, 'orderby' => 'ID', 'order' => 'DESC']);
    foreach ($jobs as $job) {
        $state = (string) get_post_meta($job->ID, 'state', true);
        echo '<tr><td>' . esc_html($job->post_title) . '<br>ID: ' . (int) get_post_meta($job->ID, 'article_id', true) . '</td><td>' . esc_html(wp_date('j M Y H:i', (int) get_post_meta($job->ID, 'send_at', true))) . '</td><td>' . esc_html(ucfirst($state)) . '</td><td>' . esc_html(get_post_meta($job->ID, 'result', true));
        if ($state === 'scheduled') {
            echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
            wp_nonce_field('wpam_notification');
            echo '<input type="hidden" name="action" value="wpam_notification"><button class="button" name="cancel_job" value="' . (int) $job->ID . '">Cancel schedule</button></form>';
        }
        echo '</td></tr>';
    }
    if (!$jobs) echo '<tr><td colspan="4">No notifications yet.</td></tr>';
    echo '</tbody></table></div>';
}

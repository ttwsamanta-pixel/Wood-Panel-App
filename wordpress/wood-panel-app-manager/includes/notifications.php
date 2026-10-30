<?php
defined('ABSPATH') || exit;

// UI, search and durable scheduled jobs are separate from the FCM transport.
require_once __DIR__ . '/notification-admin.php';

function wpam_notification_post(int $id) {
    $post = get_post($id);
    if (!$post || $post->post_type !== 'post' || $post->post_status !== 'publish' || $post->post_password !== '') {
        return new WP_Error('invalid_article', 'Choose a public, published news article from this site.');
    }
    return $post;
}

function wpam_notification_image(int $id): string {
    $attachment = get_post_thumbnail_id($id);
    if (!$attachment) return '';
    // Prefer a locally generated rendition; allow a small original as a last resort.
    $meta = wp_get_attachment_metadata($attachment);
    foreach (['medium_large', 'medium', 'thumbnail', 'full'] as $size) {
        if ($size !== 'full' && empty($meta['sizes'][$size])) continue;
        $image = wp_get_attachment_image_src($attachment, $size);
        if (!$image || ($size !== 'full' && empty($image[3])) || max((int) $image[1], (int) $image[2]) > 1024) continue;
        $url = esc_url_raw($image[0], ['https']);
        $extension = strtolower(pathinfo(wp_parse_url($url, PHP_URL_PATH) ?: '', PATHINFO_EXTENSION));
        if (!$url || wp_parse_url($url, PHP_URL_SCHEME) !== 'https' || !in_array($extension, ['jpg', 'jpeg', 'png'], true)) continue;
        $original = get_attached_file($attachment);
        $file = $size === 'full' ? $original : ($original ? dirname($original) . '/' . basename($meta['sizes'][$size]['file']) : '');
        if (!$file || !is_file($file)) continue;
        $bytes = filesize($file);
        if ($bytes > 0 && $bytes <= 1024 * 1024) return $url;
    }
    return '';
}

function wpam_notification_message($post, string $edition): array {
    $message = [
        'topic' => 'wood_panel_' . $edition,
        'notification' => [
            'title' => html_entity_decode(get_the_title($post->ID), ENT_QUOTES, 'UTF-8'),
            'body' => wp_trim_words(wp_strip_all_tags(get_the_excerpt($post)), 24),
        ],
        'data' => ['edition' => $edition, 'article_id' => (string) $post->ID],
    ];
    $image = wpam_notification_image($post->ID);
    if ($image !== '') {
        $message['android'] = ['notification' => ['image' => $image]];
        $message['apns'] = [
            'payload' => ['aps' => ['mutable-content' => 1]],
            'fcm_options' => ['image' => $image],
        ];
        // The native iOS extension reads this without an additional Firebase SDK.
        $message['data']['image_url'] = $image;
    }
    return $message;
}

function wpam_send_notification(int $id) {
    if (!current_user_can('manage_options')) return new WP_Error('forbidden', 'Not permitted.');
    return wpam_deliver_notification($id, wpam_edition());
}

// Internal transport: only the protected admin handler or an authorized queued job calls this.
function wpam_deliver_notification(int $id, string $edition) {
    if (!in_array($edition, ['europe', 'usa'], true) || $edition !== wpam_edition()) {
        return new WP_Error('wrong_edition', 'The website edition changed; create a new notification.');
    }
    $post = wpam_notification_post($id);
    if (is_wp_error($post)) return $post;
    if (!defined('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE') || !is_readable(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE)) {
        return new WP_Error('not_configured', 'Firebase credentials are not configured.');
    }
    $credentials = json_decode(file_get_contents(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE), true);
    if (!is_array($credentials) || empty($credentials['private_key']) || empty($credentials['client_email']) || !preg_match('/^[a-z0-9-]+$/', $credentials['project_id'] ?? '')) {
        return new WP_Error('invalid_credentials', 'Invalid Firebase service-account file.');
    }
    if (!function_exists('openssl_sign')) return new WP_Error('openssl_missing', 'The server needs the OpenSSL PHP extension.');
    $encode = static fn($value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    $now = time();
    $jwt = $encode(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT'])) . '.' . $encode(wp_json_encode([
        'iss' => $credentials['client_email'], 'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token', 'iat' => $now, 'exp' => $now + 3600,
    ]));
    $signature = '';
    if (!openssl_sign($jwt, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
        return new WP_Error('sign_failed', 'Unable to sign Firebase credentials.');
    }
    $token_response = wp_remote_post('https://oauth2.googleapis.com/token', ['timeout' => 20, 'body' => [
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => $jwt . '.' . $encode($signature),
    ]]);
    if (is_wp_error($token_response) || wp_remote_retrieve_response_code($token_response) !== 200) {
        return new WP_Error('auth_failed', 'Firebase authentication failed. Check the service account and its permissions.');
    }
    $token = json_decode(wp_remote_retrieve_body($token_response), true)['access_token'] ?? '';
    if (!$token) return new WP_Error('auth_failed', 'Firebase did not return an access token.');
    $response = wp_remote_post('https://fcm.googleapis.com/v1/projects/' . $credentials['project_id'] . '/messages:send', [
        'timeout' => 20, 'headers' => ['Authorization' => 'Bearer ' . $token, 'Content-Type' => 'application/json'],
        'body' => wp_json_encode(['message' => wpam_notification_message($post, $edition)]),
    ]);
    if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {
        return new WP_Error('send_failed', 'Firebase did not accept the notification. Check the project, messaging API and service-account role.');
    }
    return true;
}

<?php

defined('ABSPATH') || exit;



function wpam_register_routes(): void {

    register_rest_route(WPAM_NAMESPACE, '/profile', ['methods'=>'POST', 'permission_callback'=>'__return_true', 'callback'=>'wpam_profile_submit']);
    register_rest_route(WPAM_NAMESPACE, '/ad-event', ['methods' => 'POST', 'permission_callback' => '__return_true', 'callback' => 'wpam_ad_event']);

    register_rest_route(WPAM_NAMESPACE, '/config', [

        'methods' => 'GET', 'permission_callback' => '__return_true',

        'callback' => static function () {

            $response = rest_ensure_response(wpam_public_config());

            $response->header('Cache-Control', 'public, max-age=120');

            return $response;

        },

    ]);

    foreach (['newsletter', 'contact'] as $kind) {

        register_rest_route(WPAM_NAMESPACE, '/' . $kind, [

            'methods' => 'POST', 'permission_callback' => '__return_true',

            'callback' => static fn($request) => wpam_submit($request, $kind),

        ]);

    }

    foreach (['magazines', 'events'] as $kind) {

        register_rest_route(WPAM_NAMESPACE, '/' . $kind, [

            'methods' => 'GET', 'permission_callback' => '__return_true',

            'callback' => static fn($request) => wpam_content($request, $kind),

            'args' => [

                'page' => ['default' => 1, 'validate_callback' => static fn($v) => filter_var($v, FILTER_VALIDATE_INT) !== false && (int) $v >= 1 && (int) $v <= 10000],

                'per_page' => ['default' => 20, 'validate_callback' => static fn($v) => filter_var($v, FILTER_VALIDATE_INT) !== false && (int) $v >= 1 && (int) $v <= 50],

            ],

        ]);

    }

}



function wpam_submit(WP_REST_Request $request, string $kind) {

    global $wpdb;

    if (!wpam_settings()[$kind . '_enabled']) return new WP_Error('form_disabled', 'This form is currently unavailable.', ['status' => 503]);

    if (strlen($request->get_body()) > 20000) return new WP_Error('too_large', 'Submission is too large.', ['status' => 413]);

    $data = $request->get_json_params();

    if (!is_array($data)) return new WP_Error('invalid_json', 'A JSON object is required.', ['status' => 400]);

    foreach (['name', 'email', 'country', 'subject', 'message', 'website'] as $field) {

        if (isset($data[$field]) && !is_string($data[$field])) return new WP_Error('invalid_field', 'Invalid field value.', ['status' => 422]);

    }

    if (!empty($data['website'])) return new WP_Error('invalid_submission', 'Unable to accept this submission.', ['status' => 422]);

    // Never trust client-provided forwarded IP headers for throttling.

    $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown');

    $rate_key = 'wpam_rate_' . hash_hmac('sha256', $ip . ':' . $kind, wp_salt('nonce'));

    $rate = get_transient($rate_key);

    $rate = is_array($rate) ? $rate : ['count' => 0, 'until' => time() + 600];

    if ($rate['count'] >= 10) return new WP_Error('rate_limited', 'Please wait before submitting again.', ['status' => 429]);

    $rate['count']++;

    set_transient($rate_key, $rate, max(1, $rate['until'] - time()));



    $email = sanitize_email($data['email'] ?? '');

    $name = sanitize_text_field($data['name'] ?? '');

    $country = sanitize_text_field($data['country'] ?? '');

    $subject = sanitize_text_field($data['subject'] ?? '');

    $message = sanitize_textarea_field($data['message'] ?? '');

    if (!is_email($email) || strlen($email) > 254 || strlen($name) > 160 || strlen($country) > 100 || strlen($subject) > 200 || strlen($message) > 10000) {

        return new WP_Error('invalid_fields', 'Check your email and field lengths.', ['status' => 422]);

    }

    if ($kind === 'contact' && ($name === '' || $message === '')) return new WP_Error('required_fields', 'Name and message are required.', ['status' => 422]);

    $table = $wpdb->prefix . 'wpam_submissions';

    if ($kind === 'newsletter') {

        $key = hash('sha256', strtolower($email));

        $result = $wpdb->query($wpdb->prepare(

            "INSERT INTO $table (kind,email,name,country,subject,message,submission_key,created_at)

             VALUES (%s,%s,%s,%s,'','',%s,%s) ON DUPLICATE KEY UPDATE submission_key = VALUES(submission_key)",

            $kind, $email, $name, $country, $key, current_time('mysql', true)

        ));

    } else {

        $result = $wpdb->insert($table, [

            'kind' => $kind, 'email' => $email, 'name' => $name, 'country' => $country,

            'subject' => $subject, 'message' => $message, 'created_at' => current_time('mysql', true),

        ], ['%s', '%s', '%s', '%s', '%s', '%s', '%s']);

    }

    if ($result === false) return new WP_Error('storage_error', 'Unable to save your submission. Please try again.', ['status' => 500]);

    $response = new WP_REST_Response(['success' => true, 'message' => 'Thank you. Your submission has been received.'], 200);

    $response->header('Cache-Control', 'no-store');

    return $response;

}



function wpam_meta(int $id, string $key): string {

    $value = $key === '' ? '' : get_post_meta($id, $key, true);

    return is_scalar($value) ? (string) $value : '';

}



function wpam_content(WP_REST_Request $request, string $kind) {

    $s = wpam_settings();

    $type = $s[$kind === 'magazines' ? 'magazine_type' : 'event_type'];

    if ($kind === 'magazines' && ($type === '' || (wpam_edition() === 'usa' && !$s['magazine_cover_key'] && !$s['magazine_read_key']))) {

        return wpam_archive_magazines($request);

    }

    $object = get_post_type_object($type);

    if ($kind === 'events' && (!$object || !$object->public)) {

        $items = (int) $request['page'] === 1 ? wpam_home_events() : [];

        if (is_wp_error($items)) return $items;

        return new WP_REST_Response(['edition' => $s['edition'], 'items' => $items, 'page' => (int) $request['page'], 'total_pages' => 1]);

    }

    if (!$object || !$object->public) return new WP_Error('source_not_configured', 'This content source has not been configured.', ['status' => 503]);

    $query = new WP_Query([

        'post_type' => $type, 'post_status' => 'publish', 'has_password' => false,

        'posts_per_page' => (int) $request['per_page'], 'paged' => (int) $request['page'],

        'orderby' => 'date', 'order' => 'DESC',

    ]);

    $items = [];

    foreach ($query->posts as $post) {

        if (!is_post_publicly_viewable($post) || $post->post_password !== '') continue;

        $id = (int) $post->ID;

        $cover = get_the_post_thumbnail_url($id, 'large') ?: '';

        $title = html_entity_decode(get_the_title($id), ENT_QUOTES, 'UTF-8');

        if ($kind === 'magazines') {

            $custom_cover = wpam_meta($id, $s['magazine_cover_key']);

            if (ctype_digit($custom_cover)) $custom_cover = wp_get_attachment_image_url((int) $custom_cover, 'large') ?: '';

            $date = wpam_meta($id, $s['magazine_date_key']);

            $items[] = [

                'id' => $id, 'title' => $title, 'coverUrl' => wpam_https_url($custom_cover) ?: $cover,

                'date' => $date && strtotime($date) !== false ? gmdate('c', strtotime($date)) : get_post_time('c', true, $post),

                'description' => wp_strip_all_tags(get_the_excerpt($post)), 'fileSize' => '',

                'readUrl' => wpam_https_url(wpam_meta($id, $s['magazine_read_key'])) ?: get_permalink($id),

                'pdfUrl' => wpam_https_url(wpam_meta($id, $s['magazine_pdf_key'])),

                'volume' => '',

                'issueNumber' => '',

            ];

        } else {

            $location = wpam_meta($id, $s['event_location_key']);

            if (!$location && $type === 'tribe_events' && function_exists('tribe_get_venue')) $location = tribe_get_venue($id);

            $items[] = ['title' => $title, 'date' => wpam_meta($id, $s['event_date_key']),

                'location' => wp_strip_all_tags($location), 'imageUrl' => $cover, 'url' => get_permalink($id)];

        }

    }

    if ($kind === 'events' && !$items && (int) $request['page'] === 1) {

        $items = wpam_home_events();

        if (is_wp_error($items)) return $items;

    }

    if ($kind === 'magazines') $items = wpam_magazine_details($items);

    $response = new WP_REST_Response(['edition' => $s['edition'], 'items' => $items, 'page' => (int) $request['page'], 'total_pages' => max($items ? 1 : 0, (int) $query->max_num_pages)]);

    $response->header('Cache-Control', 'public, max-age=120');

    return $response;

}



// Europe's archive is rendered by the active theme, not a magazine post type.

function wpam_archive_magazines(WP_REST_Request $request) {

    $page = (int) $request['page'];

    $last_year = (int) gmdate('Y');

    $year = $last_year - $page + 1;

    $items = [];

    if ($year >= 2022) {

        $key = 'wpam_archive_v2_' . $year;

        $items = get_transient($key);

        if ($items === false) {

            $url = wpam_edition() === 'usa' ? home_url('/archive/?mag_year=' . $year) : home_url('/archive/archive-' . $year . '/');

            $response = wp_safe_remote_get($url, ['timeout' => 12, 'redirection' => 0, 'limit_response_size' => 2000000]);

            if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {

                if (!is_wp_error($response) && wp_remote_retrieve_response_code($response) === 404) {

                    $items = [];

                } else {

                    return new WP_Error('archive_unavailable', 'The magazine archive is temporarily unavailable.', ['status' => 503]);

                }

            } else {

                $items = wpam_parse_archive(wp_remote_retrieve_body($response), $year);

                if (is_wp_error($items)) return $items;

            }

            set_transient($key, $items, 300);

        }

    }

    return new WP_REST_Response(['edition' => wpam_edition(), 'items' => wpam_magazine_details($items), 'page' => $page, 'total_pages' => max(1, $last_year - 2022 + 1)]);

}



// Apply highlights after the archive cache so editorial changes are not cached out.

function wpam_magazine_details(array $items): array {

    $normalize = static fn($url) => rtrim(preg_replace('~/index\.html?$~i', '/', (string) $url), '/');

    $highlights = [];

    foreach (wpam_settings()['magazine_highlights'] as $row) $highlights[$normalize($row['readUrl'])] = $row['points'];

    foreach ($items as &$item) {

        $date = null;
        try { if (!empty($item['date'])) $date = new DateTimeImmutable($item['date']); } catch (Exception $e) {}

        $item['volume'] = $date ? (string) max(1, (int) $date->format('Y') - 2008) : '';

        $item['issueNumber'] = $date ? (string) ceil((int) $date->format('n') / 2) : '';

        $item['highlights'] = $highlights[$normalize($item['readUrl'] ?? '')] ?? [];

    }

    unset($item);

    return $items;

}



function wpam_parse_archive(string $html, int $year) {

    if (!class_exists('DOMDocument')) return new WP_Error('dom_missing', 'Enable the PHP DOM extension for archive magazines.', ['status' => 503]);

    $previous = libxml_use_internal_errors(true);

    $document = new DOMDocument();

    $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_NONET);

    libxml_clear_errors();

    libxml_use_internal_errors($previous);

    $xpath = new DOMXPath($document);

    $items = [];

    foreach ($xpath->query('//*[contains(concat(" ",normalize-space(@class)," ")," archive-card ") or contains(concat(" ",normalize-space(@class)," ")," wpusa-interview-item ")]') as $card) {

        $title = trim($xpath->evaluate('string(.//h2 | .//h3)', $card));

        $read = '';

        $pdf = '';

        foreach ($xpath->query('.//a[@href]', $card) as $anchor) {

            $href = wpam_https_url($anchor->getAttribute('href'));

            if ((str_contains($href, '/flipbooks/') || str_contains($href, '/flipbook/')) && wp_parse_url($href, PHP_URL_HOST) === wp_parse_url(home_url(), PHP_URL_HOST)) $read = $href;

            if (str_ends_with(strtolower((string) wp_parse_url($href, PHP_URL_PATH)), '.pdf')) $pdf = $href;

        }

        $image = $xpath->query('.//img', $card)->item(0);

        $cover = '';

        if ($image) foreach (['data-breeze', 'data-src', 'src'] as $attribute) {

            $cover = wpam_https_url($image->getAttribute($attribute));

            if ($cover) break;

        }

        if (!$read || !$title || !$cover) continue;

        $months = ['jan' => 1, 'feb' => 2, 'mar' => 3, 'apr' => 4, 'may' => 5, 'jun' => 6, 'jul' => 7, 'aug' => 8, 'sep' => 9, 'oct' => 10, 'nov' => 11, 'dec' => 12];

        $month = 1;

        foreach ($months as $name => $number) if (stripos($title, $name) !== false) $month = max($month, $number);

        $topics = [];

        foreach ($xpath->query('.//li', $card) as $topic) $topics[] = trim($topic->textContent);

        $items[] = ['id' => $year * 100 + $month, 'title' => $title, 'coverUrl' => $cover,

            'date' => sprintf('%04d-%02d-01T00:00:00Z', $year, $month), 'description' => implode(', ', $topics),

            'fileSize' => '', 'readUrl' => $read, 'pdfUrl' => $pdf];

    }

    usort($items, static fn($a, $b) => strcmp($b['date'], $a['date']));

    return $items;

}



function wpam_home_events() {

    $items = get_transient('wpam_home_events_v2');

    if ($items !== false) return $items;

    // The public homepage may be cached for days after event logos change.
    // Use one source URL per five-minute window, while retaining our transient.
    $source = add_query_arg('wpam_events_refresh', (string) floor(time() / 300), home_url('/'));
    $response = wp_safe_remote_get($source, [
        'timeout' => 12, 'redirection' => 0, 'limit_response_size' => 2000000,
        'headers' => ['Cache-Control' => 'no-cache, max-age=0'],
    ]);

    if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) return new WP_Error('events_unavailable', 'Website events are temporarily unavailable.', ['status' => 503]);

    $items = wpam_parse_home_events(wp_remote_retrieve_body($response));

    if (!is_wp_error($items)) set_transient('wpam_home_events_v2', $items, 300);

    return $items;

}



function wpam_parse_home_events(string $html) {

    if (!class_exists('DOMDocument')) return new WP_Error('dom_missing', 'Enable PHP DOM for website events.', ['status' => 503]);

    $previous = libxml_use_internal_errors(true);

    $document = new DOMDocument();

    $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_NONET);

    libxml_clear_errors();

    libxml_use_internal_errors($previous);

    $xpath = new DOMXPath($document);

    $items = [];

    foreach ($xpath->query('//*[contains(concat(" ",normalize-space(@class)," ")," upcoming-event ") or contains(concat(" ",normalize-space(@class)," ")," event-card ")]') as $card) {

        $title = trim($xpath->evaluate('string(.//h3 | .//strong)', $card));

        if (!$title) continue;

        $details = $xpath->query('.//p | .//span', $card);

        $date = ''; $location = '';

        foreach ($details as $detail) {

            $text = trim($detail->textContent);

            if (preg_match('/^Venue\s*:/i', $text)) $location = trim(preg_replace('/^Venue\s*:/i', '', $text));

            elseif (!$date) $date = $text;

        }

        $cover = '';

        $image = $xpath->query('.//img', $card)->item(0);

        if ($image) foreach (['data-src', 'data-breeze', 'src'] as $attribute) {

            $cover = wpam_https_url($image->getAttribute($attribute));

            if ($cover) break;

        }

        $url = wpam_https_url(trim($xpath->evaluate('string(.//a/@href)', $card)));

        $items[] = ['title' => $title, 'date' => $date, 'location' => $location, 'imageUrl' => $cover, 'url' => $url];

    }

    return $items;

}


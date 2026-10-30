<?php
defined('ABSPATH') || exit;

function wpam_ad_install(): void {
    if (get_option('wpam_ad_db_version') === '1') return;
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $daily = $wpdb->prefix . 'wpam_ad_daily'; $events = $wpdb->prefix . 'wpam_ad_events';
    $collation = $wpdb->get_charset_collate();
    dbDelta("CREATE TABLE $daily (
        banner_id bigint(20) unsigned NOT NULL,
        day date NOT NULL,
        impressions bigint(20) unsigned NOT NULL DEFAULT 0,
        clicks bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (banner_id,day),
        KEY day (day)
    ) ENGINE=InnoDB $collation;");
    dbDelta("CREATE TABLE $events (
        event_key varchar(64) NOT NULL,
        created_at datetime NOT NULL,
        PRIMARY KEY  (event_key),
        KEY created_at (created_at)
    ) ENGINE=InnoDB $collation;");
    if ($wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $daily)) === $daily && $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $events)) === $events) {
        update_option('wpam_ad_db_version', '1', false);
        if (!wp_next_scheduled('wpam_ad_cleanup')) wp_schedule_event(time() + DAY_IN_SECONDS, 'daily', 'wpam_ad_cleanup');
    }
}

function wpam_ad_cleanup(): void {
    global $wpdb;
    $wpdb->query($wpdb->prepare("DELETE FROM {$wpdb->prefix}wpam_ad_events WHERE created_at < %s", gmdate('Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS)));
}

function wpam_ad_event($request) {
    global $wpdb;
    if (strlen($request->get_body()) > 2048) return new WP_Error('too_large', 'Event too large.', ['status' => 413]);
    $data = $request->get_json_params();
    if (!is_array($data)) return new WP_Error('invalid_event', 'Invalid event.', ['status' => 400]);
    foreach (['banner_id', 'placement', 'token', 'view_id', 'type'] as $key) {
        if (!isset($data[$key]) || !is_scalar($data[$key])) return new WP_Error('invalid_event', 'Invalid event.', ['status' => 400]);
    }
    $id = absint($data['banner_id']); $placement = (string) $data['placement']; $type = (string) $data['type'];
    if (!isset(WPAM_AD_PLACEMENTS[$placement]) || !in_array($type, ['impression', 'click'], true) || !preg_match('/^[a-f0-9]{32}$/D', (string) $data['view_id'])) return new WP_Error('invalid_event', 'Invalid event.', ['status' => 400]);
    if (!hash_equals(wpam_banner_token($id, $placement), (string) $data['token']) || get_post_type($id) !== 'wpam_banner' || get_post_meta($id, '_wpam_placement', true) !== $placement || wpam_banner_status($id) !== 'Live') return new WP_Error('invalid_banner', 'Banner unavailable.', ['status' => 403]);
    if ($type === 'click' && !wpam_https_url(get_post_meta($id, '_wpam_link', true))) return new WP_Error('invalid_click', 'Banner has no link.', ['status' => 400]);
    $rate_key = 'wpam_ad_rate_' . hash_hmac('sha256', (string) ($_SERVER['REMOTE_ADDR'] ?? ''), wp_salt('nonce'));
    $rate = get_transient($rate_key);
    $rate = is_array($rate) ? $rate : ['count' => 0, 'until' => time() + 60];
    if ($rate['count'] >= 600) return new WP_Error('rate_limited', 'Try later.', ['status' => 429]);
    $rate['count']++; set_transient($rate_key, $rate, max(1, $rate['until'] - time()));
    if (get_option('wpam_ad_db_version') !== '1') return new WP_Error('not_ready', 'Reporting is not ready.', ['status' => 503]);
    $key = hash('sha256', $id . ':' . $data['view_id'] . ':' . $type);
    $wpdb->query('START TRANSACTION');
    $inserted = $wpdb->query($wpdb->prepare("INSERT IGNORE INTO {$wpdb->prefix}wpam_ad_events (event_key,created_at) VALUES (%s,%s)", $key, current_time('mysql', true)));
    if ($inserted === false) { $wpdb->query('ROLLBACK'); return new WP_Error('storage_error', 'Unable to record event.', ['status' => 503]); }
    if ($inserted) {
        $result = $wpdb->query($wpdb->prepare("INSERT INTO {$wpdb->prefix}wpam_ad_daily (banner_id,day,impressions,clicks) VALUES (%d,%s,%d,%d)
            ON DUPLICATE KEY UPDATE impressions=impressions+VALUES(impressions), clicks=clicks+VALUES(clicks)", $id, current_time('Y-m-d'), $type === 'impression' ? 1 : 0, $type === 'click' ? 1 : 0));
        if ($result === false) { $wpdb->query('ROLLBACK'); return new WP_Error('storage_error', 'Unable to record event.', ['status' => 503]); }
    }
    $wpdb->query('COMMIT');
    $response = new WP_REST_Response(['recorded' => (bool) $inserted], 200);
    $response->header('Cache-Control', 'no-store');
    return $response;
}

function wpam_ad_ctr(array $stats): string {
    return number_format($stats['impressions'] > 0 ? 100 * $stats['clicks'] / $stats['impressions'] : 0, 2, '.', '');
}

function wpam_ad_totals(int $id, string $from = '', string $to = ''): array {
    global $wpdb;
    $where = $wpdb->prepare('banner_id=%d', $id);
    if ($from) $where .= $wpdb->prepare(' AND day >= %s', $from);
    if ($to) $where .= $wpdb->prepare(' AND day <= %s', $to);
    $row = $wpdb->get_row("SELECT COALESCE(SUM(impressions),0) impressions,COALESCE(SUM(clicks),0) clicks FROM {$wpdb->prefix}wpam_ad_daily WHERE $where", ARRAY_A);
    return ['impressions' => (int) ($row['impressions'] ?? 0), 'clicks' => (int) ($row['clicks'] ?? 0)];
}

function wpam_ad_range(array $input): array {
    $today = new DateTimeImmutable('today', wp_timezone());
    $from = wpam_banner_date($input['from'] ?? '') ?: $today->modify('-29 days')->format('Y-m-d');
    $to = wpam_banner_date($input['to'] ?? '') ?: $today->format('Y-m-d');
    if ($from > $to) [$from, $to] = [$to, $from];
    $max = (new DateTimeImmutable($from, wp_timezone()))->modify('+92 days')->format('Y-m-d');
    if ($to > $max) $to = $max;
    return [$from, $to];
}

function wpam_ad_days(int $id, string $from, string $to): array {
    global $wpdb;
    $rows = $wpdb->get_results($wpdb->prepare("SELECT day,impressions,clicks FROM {$wpdb->prefix}wpam_ad_daily WHERE banner_id=%d AND day BETWEEN %s AND %s ORDER BY day", $id, $from, $to), ARRAY_A);
    $by_day = array_column($rows ?: [], null, 'day'); $result = [];
    $date = new DateTimeImmutable($from, wp_timezone());
    while ($date->format('Y-m-d') <= $to) {
        $day = $date->format('Y-m-d');
        $result[] = ['day' => $day, 'impressions' => (int) ($by_day[$day]['impressions'] ?? 0), 'clicks' => (int) ($by_day[$day]['clicks'] ?? 0)];
        $date = $date->modify('+1 day');
    }
    return $result;
}

function wpam_ad_metric_card(string $label, array $stats): void {
    echo '<section class="wpam-metric"><h3>' . esc_html($label) . '</h3><div>';
    foreach (['impressions' => 'Impressions', 'clicks' => 'Clicks', 'ctr' => 'CTR'] as $key => $title) echo '<span>' . esc_html($title) . '<strong>' . esc_html($key === 'ctr' ? wpam_ad_ctr($stats) . '%' : number_format_i18n($stats[$key])) . '</strong></span>';
    echo '</div></section>';
}

function wpam_banner_reports(): void {
    if (!current_user_can('manage_options')) return;
    $id = absint($_GET['banner_id'] ?? 0);
    echo '<div class="wrap"><h1>App Banner Reports</h1><p>Edition: <strong>' . esc_html(ucfirst(wpam_edition())) . '</strong>. Times use this site’s timezone. CTR = clicks ÷ impressions × 100. Statistics begin with the tracking-enabled app; historic views cannot be recovered.</p>';
    echo '<style>.wpam-metrics{display:grid;grid-template-columns:repeat(2,minmax(200px,1fr));max-width:1000px}.wpam-metric{background:white;border:1px solid #ddd;padding:20px;text-align:center}.wpam-metric div{display:flex;justify-content:space-around}.wpam-metric strong{display:block;font-size:24px;padding-top:8px}.wpam-chart{background:white;padding:16px;margin:20px 0;max-width:1100px}.wpam-chart svg{width:100%;height:auto} @media(max-width:600px){.wpam-metrics{grid-template-columns:1fr}}</style>';
    if (!$id) {
        $page = max(1, absint($_GET['paged'] ?? 1));
        $search = sanitize_text_field(wp_unslash($_GET['s'] ?? ''));
        $query = new WP_Query(['post_type' => 'wpam_banner', 'post_status' => ['publish', 'draft', 'pending', 'future', 'private', 'trash'], 'posts_per_page' => 25, 'paged' => $page, 's' => $search, 'orderby' => ['menu_order' => 'ASC', 'ID' => 'ASC']]);
        echo '<form method="get"><input type="hidden" name="page" value="wpam-banner-reports"><input aria-label="Search banners" name="s" value="' . esc_attr($search) . '"> <button class="button">Search Banners</button></form><p><a class="button" href="' . esc_url(admin_url('post-new.php?post_type=wpam_banner')) . '">Add Banner</a></p><table class="widefat striped"><thead><tr><th>Banner</th><th>Placement</th><th>Impressions</th><th>Today</th><th>Clicks</th><th>Today</th><th>CTR</th></tr></thead><tbody>';
        foreach ($query->posts as $post) {
            $all = wpam_ad_totals($post->ID); $today = wpam_ad_totals($post->ID, current_time('Y-m-d'), current_time('Y-m-d'));
            echo '<tr><td><img alt="" style="width:60px;max-height:60px;object-fit:contain;vertical-align:middle;margin-right:12px" src="' . esc_url(get_post_meta($post->ID, '_wpam_image', true)) . '"><a href="' . esc_url(wpam_banner_report_url($post->ID)) . '">' . esc_html($post->post_title ?: '(Untitled)') . '</a></td><td>' . esc_html(WPAM_AD_PLACEMENTS[get_post_meta($post->ID, '_wpam_placement', true)] ?? '') . '</td>';
            foreach ([$all['impressions'], $today['impressions'], $all['clicks'], $today['clicks']] as $count) echo '<td>' . esc_html(number_format_i18n($count)) . '</td>';
            echo '<td>' . esc_html(wpam_ad_ctr($all)) . '%</td></tr>';
        }
        if (!$query->posts) echo '<tr><td colspan="7">No banners yet. Add a banner to begin.</td></tr>';
        echo '</tbody></table><p>' . wp_kses_post((string) paginate_links(['base' => add_query_arg('paged', '%#%'), 'format' => '', 'current' => $page, 'total' => $query->max_num_pages])) . '</p></div>';
        return;
    }
    if (get_post_type($id) !== 'wpam_banner') { echo '<p>Banner not found.</p></div>'; return; }
    $today = new DateTimeImmutable('today', wp_timezone()); $month = $today->modify('first day of this month'); $last = $month->modify('-1 month');
    echo '<p><a href="' . esc_url(wpam_banner_report_url()) . '">← All Reports</a> | <a href="' . esc_url(get_edit_post_link($id)) . '">Edit Banner</a></p><img alt="Banner preview" style="max-width:350px;max-height:250px" src="' . esc_url(get_post_meta($id, '_wpam_image', true)) . '"><h2>Statistics for ' . esc_html(get_the_title($id)) . '</h2><div class="wpam-metrics">';
    wpam_ad_metric_card('Today', wpam_ad_totals($id, $today->format('Y-m-d'), $today->format('Y-m-d')));
    wpam_ad_metric_card('All time', wpam_ad_totals($id));
    wpam_ad_metric_card('Last month', wpam_ad_totals($id, $last->format('Y-m-d'), $month->modify('-1 day')->format('Y-m-d')));
    wpam_ad_metric_card('This month', wpam_ad_totals($id, $month->format('Y-m-d'), $today->format('Y-m-d')));
    echo '</div><h2>Overview of clicks and impressions</h2>';
    [$from, $to] = wpam_ad_range($_GET);
    echo '<form method="get"><input type="hidden" name="page" value="wpam-banner-reports"><input type="hidden" name="banner_id" value="' . $id . '"><label>From <input type="date" name="from" value="' . esc_attr($from) . '"></label> <label>Until <input type="date" name="to" value="' . esc_attr($to) . '"></label> <button class="button">Go</button><p>Maximum 93 days per chart/export.</p></form>';
    $rows = wpam_ad_days($id, $from, $to);
    echo '<div class="wpam-chart"><p><span style="color:#3156dc">● Impressions</span> &nbsp; <span style="color:#b44b0c">● Clicks</span> — hover points for daily counts</p><svg viewBox="0 0 1000 270" role="img" aria-label="Daily impressions and clicks">';
    $max = ceil(max(4, ...array_column($rows, 'impressions'), ...array_column($rows, 'clicks')) / 4) * 4;
    for ($i = 0; $i <= 4; $i++) { $y = 20 + $i * 50; echo '<path d="M50 ' . $y . ' H980" stroke="#e5e7eb"/><text x="0" y="' . ($y + 5) . '" font-size="12">' . esc_html((string) round($max * (4 - $i) / 4)) . '</text>'; }
    foreach (['impressions' => '#3156dc', 'clicks' => '#b44b0c'] as $metric => $color) {
        $points = [];
        foreach ($rows as $i => $row) { $x = 50 + 930 * $i / max(1, count($rows) - 1); $y = 220 - 200 * $row[$metric] / $max; $points[] = "$x,$y"; }
        echo '<polyline fill="none" stroke="' . $color . '" stroke-width="2" points="' . esc_attr(implode(' ', $points)) . '"/>';
        foreach ($rows as $i => $row) { [$x, $y] = explode(',', $points[$i]); echo '<circle cx="' . esc_attr($x) . '" cy="' . esc_attr($y) . '" r="4" fill="' . $color . '"><title>' . esc_html($row['day'] . ': ' . $row[$metric] . ' ' . $metric) . '</title></circle>'; }
    }
    echo '<text x="50" y="255" font-size="12">' . esc_html($from) . '</text><text x="895" y="255" font-size="12">' . esc_html($to) . '</text></svg></div>';
    wpam_ad_metric_card('Selected period', wpam_ad_totals($id, $from, $to));
    echo '<details><summary>Daily data</summary><table class="widefat striped"><tr><th>Date</th><th>Impressions</th><th>Clicks</th><th>CTR</th></tr>';
    foreach ($rows as $row) echo '<tr><td>' . esc_html($row['day']) . '</td><td>' . $row['impressions'] . '</td><td>' . $row['clicks'] . '</td><td>' . esc_html(wpam_ad_ctr($row)) . '%</td></tr>';
    echo '</table></details><h2>Export options</h2><form method="post" action="' . esc_url(admin_url('admin-post.php')) . '"><input type="hidden" name="action" value="wpam_ad_export"><input type="hidden" name="banner_id" value="' . $id . '">';
    wp_nonce_field('wpam_ad_export');
    echo '<label>From <input type="date" name="from" value="' . esc_attr($from) . '"></label> <label>Until <input type="date" name="to" value="' . esc_attr($to) . '"></label><p><label>Email options (optional)<br><input class="regular-text" name="emails" placeholder="name@example.com"></label></p><p>Up to 3 email addresses, comma-separated. Leave blank to download CSV.</p><button class="button button-primary">Export</button></form><p>Counts are indicative app events, not unique people or independently audited advertising metrics. Failed/offline deliveries may be missing; no device identity is stored.</p></div>';
}

function wpam_ad_export(): void {
    if (!current_user_can('manage_options')) wp_die('Not permitted.', '', ['response' => 403]);
    check_admin_referer('wpam_ad_export');
    $id = absint($_POST['banner_id'] ?? 0);
    if (get_post_type($id) !== 'wpam_banner') wp_die('Banner not found.');
    [$from, $to] = wpam_ad_range($_POST);
    $rows = wpam_ad_days($id, $from, $to);
    $stream = fopen('php://temp', 'w+');
    fputcsv($stream, ['Date', 'Impressions', 'Clicks', 'CTR (%)']);
    foreach ($rows as $row) fputcsv($stream, [$row['day'], $row['impressions'], $row['clicks'], wpam_ad_ctr($row)]);
    rewind($stream); $csv = stream_get_contents($stream); fclose($stream);
    $raw = trim((string) wp_unslash($_POST['emails'] ?? ''));
    if ($raw !== '') {
        $emails = array_unique(array_map('trim', explode(',', $raw)));
        if (count($emails) > 3 || array_filter($emails, static fn($email) => !is_email($email))) wp_die('Enter up to 3 valid email addresses.');
        $temporary = wp_tempnam('banner-report');
        $file = $temporary ? $temporary . '.csv' : '';
        if (!$temporary || !rename($temporary, $file)) wp_die('Unable to create export.');
        if (file_put_contents($file, $csv) === false) { wp_delete_file($file); wp_die('Unable to create export.'); }
        try { $sent = wp_mail($emails, 'App banner report: ' . get_the_title($id), "Banner #$id — $from to $to. CSV attached.", [], [$file]); }
        finally { wp_delete_file($file); }
        wp_die($sent ? 'Report handed to the site mail service. Delivery depends on its mail configuration.' : 'Mail service failed. Download the CSV instead.', 'Banner report', ['back_link' => true]);
    }
    nocache_headers(); header('Content-Type: text/csv; charset=UTF-8'); header('Content-Disposition: attachment; filename="banner-' . $id . '-' . $from . '.csv"');
    echo $csv; exit;
}

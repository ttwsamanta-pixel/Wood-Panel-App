<?php
defined('ABSPATH') || exit;

const WPAM_AD_PLACEMENTS = ['banners' => 'Home carousel', 'inline_ads' => 'Inline advertisements', 'footer_ads' => 'Footer advertisements'];

function wpam_banner_menu_order(): void {
    global $submenu;
    $parent = 'wood-panel-app-settings';
    if (!isset($submenu[$parent])) return;
    // WordPress inserts custom post types first; keep the parent pointing to Settings.
    $items = $submenu[$parent];
    usort($items, static fn($a, $b) => (($a[2] === $parent) ? -1 : 0) <=> (($b[2] === $parent) ? -1 : 0));
    $submenu[$parent] = $items;
}

function wpam_register_banners(): void {
    register_post_type('wpam_banner', [
        'labels' => ['name' => 'App Banners', 'singular_name' => 'App Banner', 'add_new_item' => 'Add App Banner', 'edit_item' => 'Edit App Banner', 'all_items' => 'All Banners', 'search_items' => 'Search Banners'],
        'public' => false, 'show_ui' => true, 'show_in_menu' => 'wood-panel-app-settings',
        'show_in_rest' => false, 'supports' => ['title'], 'map_meta_cap' => false,
        'capabilities' => array_fill_keys(['edit_post', 'read_post', 'delete_post', 'edit_posts', 'edit_others_posts', 'publish_posts', 'read_private_posts', 'delete_posts', 'delete_private_posts', 'delete_published_posts', 'delete_others_posts', 'edit_private_posts', 'edit_published_posts', 'create_posts'], 'manage_options'),
        'rewrite' => false, 'query_var' => false,
    ]);
}

function wpam_banner_date($value): string {
    if (!is_string($value) || !preg_match('/^\d{4}-\d{2}-\d{2}$/D', $value)) return '';
    $parts = array_map('intval', explode('-', $value));
    return checkdate($parts[1], $parts[2], $parts[0]) ? $value : '';
}

function wpam_banner_status(int $id): string {
    if (get_post_status($id) !== 'publish') return ucfirst((string) get_post_status($id));
    if (get_post_meta($id, '_wpam_active', true) !== '1') return 'Paused';
    $today = current_time('Y-m-d');
    $start = get_post_meta($id, '_wpam_start', true);
    $end = get_post_meta($id, '_wpam_end', true);
    if ($end && $end < $today) return 'Expired';
    if ($start && $start > $today) return 'Scheduled';
    if (!wpam_https_url(get_post_meta($id, '_wpam_image', true))) return 'Missing image';
    return 'Live';
}

function wpam_banner_meta_box(): void {
    add_meta_box('wpam-banner-details', 'App Banner Details', 'wpam_banner_editor', 'wpam_banner', 'normal', 'high');
}

function wpam_banner_editor($post): void {
    wp_nonce_field('wpam_save_banner', 'wpam_banner_nonce');
    $get = static fn($key, $default = '') => get_post_meta($post->ID, '_wpam_' . $key, true) ?: $default;
    echo '<table class="form-table wpam-banner-editor"><tbody><tr><th>Placement</th><td><select name="wpam_ad[placement]">';
    foreach (WPAM_AD_PLACEMENTS as $key => $label) echo '<option value="' . esc_attr($key) . '"' . selected($get('placement', 'banners'), $key, false) . '>' . esc_html($label) . '</option>';
    echo '</select></td></tr><tr><th>Footer size</th><td><select name="wpam_ad[size]">';
    foreach (['350x50', '350x100'] as $size) echo '<option' . selected($get('size', '350x50'), $size, false) . '>' . esc_html($size) . '</option>';
    echo '</select><p class="description">Footer only. Inline artwork: 350 x 350 px. Home carousel: use your existing banner proportions.</p></td></tr>';
    foreach (['image' => ['Banner image URL', 'url'], 'link' => ['Destination link (optional)', 'url'], 'label' => ['Accessible description', 'text'], 'start' => ['Start date', 'date'], 'end' => ['End date', 'date'], 'order' => ['Display order', 'number']] as $key => [$label, $type]) {
        $value = $key === 'order' ? $post->menu_order : $get($key);
        echo '<tr><th><label for="wpam-ad-' . esc_attr($key) . '">' . esc_html($label) . '</label></th><td><input id="wpam-ad-' . esc_attr($key) . '" class="regular-text" type="' . esc_attr($type) . '" name="wpam_ad[' . esc_attr($key) . ']" value="' . esc_attr($value) . '"' . ($type === 'url' ? ' placeholder="https://"' : '') . '>';
        if ($key === 'image') echo '<p><button type="button" class="button" id="wpam-ad-upload">Upload / Select Image</button></p><img id="wpam-ad-preview" alt="Banner preview" style="max-width:350px;max-height:160px" src="' . esc_url($value) . '">';
        if ($key === 'end') echo '<p class="description">Inclusive, in the WordPress site timezone. Leave dates empty to run without a schedule.</p>';
        if ($key === 'order') echo '<p class="description">Lower numbers appear first within each placement.</p>';
        echo '</td></tr>';
    }
    echo '<tr><th>Status</th><td><label><input type="checkbox" name="wpam_ad[active]" value="1"' . checked($get('active', $post->post_status === 'auto-draft' ? '1' : '0'), '1', false) . '> Active (show in app when published and within dates)</label></td></tr></tbody></table>';
    if ($post->post_status !== 'auto-draft') echo '<p><a class="button" href="' . esc_url(wpam_banner_report_url($post->ID)) . '">View report</a></p>';
}

function wpam_save_banner(int $id): void {
    if (!current_user_can('manage_options') || (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) || wp_is_post_revision($id)) return;
    if (!isset($_POST['wpam_banner_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['wpam_banner_nonce'])), 'wpam_save_banner')) return;
    $raw = wp_unslash($_POST['wpam_ad'] ?? []);
    if (!is_array($raw)) return;
    $value = static fn($key) => isset($raw[$key]) && is_scalar($raw[$key]) ? (string) $raw[$key] : '';
    $start = wpam_banner_date($value('start')); $end = wpam_banner_date($value('end'));
    if ($start && $end && $end < $start) {
        set_transient('wpam_banner_error_' . get_current_user_id(), 'Banner details were not saved: end date must be on or after start date.', 60);
        return;
    }
    $meta = ['placement' => isset(WPAM_AD_PLACEMENTS[$value('placement')]) ? $value('placement') : 'banners',
        'size' => $value('size') === '350x100' ? '350x100' : '350x50',
        'image' => wpam_https_url($value('image')), 'link' => wpam_https_url($value('link')),
        'label' => sanitize_text_field($value('label')), 'start' => $start, 'end' => $end, 'active' => $value('active') === '1' ? '1' : '0'];
    foreach ($meta as $key => $v) update_post_meta($id, '_wpam_' . $key, $v);
    // Update order directly to avoid recursive save_post callbacks.
    global $wpdb;
    $wpdb->update($wpdb->posts, ['menu_order' => max(0, min(999999, (int) $value('order')))], ['ID' => $id], ['%d'], ['%d']);
    clean_post_cache($id);
}

function wpam_banner_assets(): void {
    if (get_current_screen()?->post_type !== 'wpam_banner') return;
    wp_enqueue_media();
    wp_enqueue_script('wpam-banner-editor', plugin_dir_url(dirname(__DIR__) . '/wood-panel-app-manager.php') . 'assets/banner-editor.js', ['media-editor'], '0.4.0', true);
}

function wpam_banner_notices(): void {
    $key = 'wpam_banner_error_' . get_current_user_id();
    if ($message = get_transient($key)) { echo '<div class="notice notice-error"><p>' . esc_html($message) . '</p></div>'; delete_transient($key); }
}

function wpam_banner_report_url(int $id = 0): string {
    return admin_url('admin.php?page=wpam-banner-reports' . ($id ? '&banner_id=' . $id : ''));
}

function wpam_banner_columns(array $columns): array {
    return ['cb' => $columns['cb'], 'title' => 'Title', 'wpam_image' => 'Banner', 'wpam_placement' => 'Placement / Size', 'wpam_link' => 'Link', 'wpam_dates' => 'Start / End', 'wpam_status' => 'Status', 'wpam_order' => 'Order', 'wpam_stats' => 'Impressions / Clicks / CTR', 'date' => 'Date'];
}

function wpam_banner_column(string $column, int $id): void {
    switch ($column) {
        case 'wpam_image': echo '<img style="max-width:90px;max-height:60px" alt="" src="' . esc_url(get_post_meta($id, '_wpam_image', true)) . '">'; break;
        case 'wpam_placement': echo esc_html(WPAM_AD_PLACEMENTS[get_post_meta($id, '_wpam_placement', true)] ?? ''); if (get_post_meta($id, '_wpam_placement', true) === 'footer_ads') echo '<br>' . esc_html(get_post_meta($id, '_wpam_size', true)); break;
        case 'wpam_link': $url = get_post_meta($id, '_wpam_link', true); echo '<a style="overflow-wrap:anywhere" href="' . esc_url($url) . '">' . esc_html($url) . '</a>'; break;
        case 'wpam_dates': echo esc_html((get_post_meta($id, '_wpam_start', true) ?: 'Any time') . ' → ' . (get_post_meta($id, '_wpam_end', true) ?: 'No expiry')); break;
        case 'wpam_status': $status = wpam_banner_status($id); echo '<strong style="color:' . ($status === 'Live' ? '#137333' : '#9b3d13') . '">' . esc_html($status) . '</strong>'; break;
        case 'wpam_order': echo (int) get_post_field('menu_order', $id); break;
        case 'wpam_stats': $s = wpam_ad_totals($id); echo esc_html(number_format_i18n($s['impressions']) . ' / ' . number_format_i18n($s['clicks']) . ' / ' . wpam_ad_ctr($s) . '%') . '<br><a href="' . esc_url(wpam_banner_report_url($id)) . '">Report</a>'; break;
    }
}

function wpam_banner_actions(array $actions, $post): array {
    if ($post->post_type === 'wpam_banner') {
        unset($actions['inline hide-if-no-js']);
        $actions['report'] = '<a href="' . esc_url(wpam_banner_report_url($post->ID)) . '">Report</a>';
    }
    return $actions;
}

function wpam_banner_token(int $id, string $placement): string {
    return hash_hmac('sha256', $id . ':' . $placement . ':' . home_url('/'), wp_salt('auth'));
}

function wpam_live_banners(string $placement): array {
    $posts = get_posts(['post_type' => 'wpam_banner', 'post_status' => 'publish', 'numberposts' => -1, 'orderby' => ['menu_order' => 'ASC', 'ID' => 'ASC'],
        'meta_key' => '_wpam_placement', 'meta_value' => $placement]);
    $result = [];
    foreach ($posts as $post) {
        $id = (int) $post->ID;
        if (wpam_banner_status($id) !== 'Live') continue;
        $result[] = ['id' => (string) $id, 'placement' => $placement, 'image_url' => get_post_meta($id, '_wpam_image', true),
            'link_url' => get_post_meta($id, '_wpam_link', true), 'label' => get_post_meta($id, '_wpam_label', true) ?: $post->post_title,
            'size' => get_post_meta($id, '_wpam_size', true) ?: '350x50', 'start_date' => get_post_meta($id, '_wpam_start', true), 'end_date' => get_post_meta($id, '_wpam_end', true),
            'tracking_token' => wpam_banner_token($id, $placement), 'tracking_url' => rest_url(WPAM_NAMESPACE . '/ad-event')];
    }
    return $result;
}

// Runs on plugin upgrades as well as fresh activation; the old arrays remain a backup.
function wpam_banner_upgrade(): void {
    wpam_ad_install();
    if (get_option('wpam_banners_migrated')) return;
    $lock = (int) get_option('wpam_banner_migration_lock');
    if ($lock && $lock < time() - 300) delete_option('wpam_banner_migration_lock');
    if (!add_option('wpam_banner_migration_lock', time(), '', false)) return;
    try {
        $settings = wpam_settings();
        add_option('wpam_banner_legacy_backup', $settings, '', false);
        foreach (WPAM_AD_PLACEMENTS as $placement => $label) {
            foreach ($settings[$placement] as $index => $banner) {
                $image = wpam_https_url($banner['image_url'] ?? ''); if (!$image) continue;
                $key = $placement . ':' . $index;
                if (get_posts(['post_type' => 'wpam_banner', 'post_status' => 'any', 'fields' => 'ids', 'numberposts' => 1, 'meta_key' => '_wpam_legacy_key', 'meta_value' => $key])) continue;
                $id = wp_insert_post(['post_type' => 'wpam_banner', 'post_status' => 'publish', 'post_title' => ($banner['label'] ?? '') ?: $label . ' ' . ($index + 1), 'menu_order' => $index,
                    'meta_input' => ['_wpam_legacy_key' => $key, '_wpam_placement' => $placement, '_wpam_image' => $image, '_wpam_link' => $banner['link_url'] ?? '',
                        '_wpam_label' => $banner['label'] ?? '', '_wpam_active' => '1', '_wpam_size' => ($banner['size'] ?? '') === '350x100' ? '350x100' : '350x50']], true);
                if (is_wp_error($id) || !$id) return;
            }
        }
        update_option('wpam_banners_migrated', 1, false);
    } finally { delete_option('wpam_banner_migration_lock'); }
}

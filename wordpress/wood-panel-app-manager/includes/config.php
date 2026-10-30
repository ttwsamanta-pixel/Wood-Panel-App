<?php

defined('ABSPATH') || exit;



const WPAM_NAMESPACE = 'wood-panel-app/v1';

const WPAM_SECTIONS = ['banners', 'categories', 'latest', 'trending', 'videos', 'magazines', 'events', 'newsletter'];

const WPAM_CHANNEL = 'UChylAsyNbYR6yvGmPz59iCA';



function wpam_edition(): string {

    return strtolower((string) wp_parse_url(home_url(), PHP_URL_HOST)) === 'www.woodandpanel.us'

        || strtolower((string) wp_parse_url(home_url(), PHP_URL_HOST)) === 'woodandpanel.us' ? 'usa' : 'europe';

}



function wpam_social_defaults(): array {
 return ['facebook'=>'https://www.facebook.com/woodpanel', 'x'=>'https://twitter.com/WoodandPanel', 'linkedin'=>'https://www.linkedin.com/company/wood-and-panel', 'instagram'=>'https://www.instagram.com/woodandpanel/', 'youtube'=>'https://www.youtube.com/woodandpanel', 'whatsapp'=>'https://wa.me/4915222067848'];
}

function wpam_defaults(): array {

    $logo = wp_get_attachment_image_url((int) get_theme_mod('custom_logo'), 'full');

    return [

        'edition' => wpam_edition(), 'label' => wpam_edition() === 'usa' ? 'USA' : 'Europe',

        'logo_url' => $logo ?: '', 'primary' => wpam_edition() === 'usa' ? '#A41E22' : '#A54F17', 'secondary' => wpam_edition() === 'usa' ? '#223268' : '#034F29',

        'preloader_url' => '', 'preloader_color' => '#211F21',

        'branding_confirmed' => false, 'home_categories' => [], 'explore_categories' => [],

        'sections' => WPAM_SECTIONS, 'banners' => [], 'inline_ads' => [], 'footer_ads' => [], 'featured_ids' => [],

        'interview_categories' => [], 'magazine_type' => post_type_exists('magazine') ? 'magazine' : '',

        'magazine_cover_key' => '', 'magazine_read_key' => '', 'magazine_pdf_key' => '',

        'magazine_date_key' => '', 'event_type' => post_type_exists('tribe_events') ? 'tribe_events' : '',

        'magazine_highlights' => [],

        'event_date_key' => '_EventStartDate', 'event_location_key' => '',

        'newsletter_enabled' => true, 'contact_enabled' => true,

        'about_page_id' => 0, 'contact_page_id' => 0,

        'app_store_url' => '', 'ios_store_url' => '',
        'youtube_channel_id' => WPAM_CHANNEL,

        'social_links' => wpam_social_defaults(), 'wallpapers' => [], 'default_wallpapers_enabled' => true,

    ];

}



function wpam_settings(): array {

    return array_replace(wpam_defaults(), (array) get_option('wpam_settings', []));

}



function wpam_ids($value, string $type): array {

    $values = is_array($value) ? $value : explode(',', (string) $value);

    $result = [];

    foreach (array_slice($values, 0, 100) as $id) {

        $id = absint($id);

        if (!$id || in_array($id, $result, true)) continue;

        if ($type === 'category' && term_exists($id, 'category')) $result[] = $id;

        if ($type === 'post' && get_post_status($id) === 'publish' && get_post_type($id) === 'post') $result[] = $id;

    }

    return $result;

}



function wpam_https_url($value): string {

    if (!is_scalar($value)) return '';

    $url = esc_url_raw(trim((string) $value), ['https']);

    return wp_parse_url($url, PHP_URL_SCHEME) === 'https' ? $url : '';

}



function wpam_sanitize_settings($input): array {

    $input = is_array($input) ? $input : [];

    $out = wpam_defaults();

    $out['edition'] = in_array($input['edition'] ?? '', ['europe', 'usa'], true) ? $input['edition'] : $out['edition'];

    $out['label'] = sanitize_text_field($input['label'] ?? ucfirst($out['edition']));

    $out['logo_url'] = wpam_https_url($input['logo_url'] ?? '');

    $out['preloader_url'] = wpam_https_url($input['preloader_url'] ?? '');

    foreach (['primary', 'secondary', 'preloader_color'] as $key) $out[$key] = sanitize_hex_color($input[$key] ?? '') ?: $out[$key];

    foreach (['branding_confirmed', 'newsletter_enabled', 'contact_enabled'] as $key) $out[$key] = !empty($input[$key]);

    foreach (['home_categories', 'explore_categories', 'interview_categories'] as $key) {

        $out[$key] = wpam_ids($input[$key] ?? [], 'category');

    }

    $out['explore_categories'] = $out['home_categories'];

    $out['featured_ids'] = wpam_ids($input['featured_ids'] ?? [], 'post');

    $sections = is_array($input['sections'] ?? null) ? $input['sections'] : [];

    $out['sections'] = array_values(array_unique(array_intersect($sections, WPAM_SECTIONS)));

    foreach (['magazine_type', 'event_type'] as $key) {

        $type = sanitize_key($input[$key] ?? '');

        $object = get_post_type_object($type);

        $out[$key] = $object && $object->public && $type !== 'attachment' ? $type : '';

    }

    foreach (['magazine_cover_key', 'magazine_read_key', 'magazine_pdf_key', 'magazine_date_key', 'event_date_key', 'event_location_key'] as $key) {

        $out[$key] = sanitize_text_field($input[$key] ?? '');

    }

    foreach (array_slice((array) ($input['magazine_highlights'] ?? []), 0, 200) as $row) {

        if (!is_array($row)) continue;

        $url = wpam_https_url($row['readUrl'] ?? '');

        $points = array_values(array_filter(array_map('sanitize_textarea_field', preg_split('/\r?\n/', (string) ($row['points'] ?? '')))));

        if ($url && $points) $out['magazine_highlights'][] = ['readUrl' => $url, 'points' => array_slice($points, 0, 30)];

    }

    $out['default_wallpapers_enabled'] = !empty($input['default_wallpapers_enabled']);

    foreach (['about_page_id', 'contact_page_id'] as $key) {

        $id = absint($input[$key] ?? 0);

        $out[$key] = get_post_type($id) === 'page' && get_post_status($id) === 'publish' ? $id : 0;

    }

    foreach (['banners', 'inline_ads', 'footer_ads'] as $placement) {

    foreach (array_slice((array) ($input[$placement] ?? []), 0, 20) as $banner) {

        if (!is_array($banner)) continue;

        $image = wpam_https_url($banner['image_url'] ?? '');

        if (!$image) continue;

        $out[$placement][] = ['image_url' => $image, 'link_url' => wpam_https_url($banner['link_url'] ?? ''), 'label' => sanitize_text_field($banner['label'] ?? '')];

        if ($placement === 'footer_ads') {

            $last = count($out[$placement]) - 1;

            $out[$placement][$last]['size'] = ($banner['size'] ?? '') === '350x100' ? '350x100' : '350x50';

        }

    }

    }

    // One shared channel is intentional; installations cannot silently diverge.

    $wallpapers = $input['wallpapers'] ?? [];

    if (!is_array($wallpapers)) $wallpapers = [];

    if (!is_array($wallpapers)) {

        add_settings_error('wpam', 'invalid_wallpapers', 'Wallpaper JSON is invalid; previous wallpapers were retained.');

        $out['wallpapers'] = wpam_settings()['wallpapers'];

    } else foreach (array_slice($wallpapers, 0, 100) as $item) {

        if (!is_array($item)) continue;

        $image = wpam_https_url($item['image_url'] ?? '');

        $id = sanitize_key($item['id'] ?? '') ?: substr(md5($image), 0, 16);

        if (!$image || !$id) continue;

        $out['wallpapers'][] = ['id' => $id, 'title' => sanitize_text_field($item['title'] ?? ''),

            'category' => sanitize_text_field($item['category'] ?? ''), 'image_url' => $image];

    }

    foreach (wpam_social_defaults() as $key => $default) {
        $out['social_links'][$key] = wpam_https_url($input['social_links'][$key] ?? $default);
    }
    $store = wpam_https_url($input['app_store_url'] ?? '');
    $query = [];
    parse_str((string) wp_parse_url($store, PHP_URL_QUERY), $query);
    if ($store && (strtolower((string) wp_parse_url($store, PHP_URL_HOST)) !== 'play.google.com'
        || wp_parse_url($store, PHP_URL_PATH) !== '/store/apps/details' || empty($query['id']))) {
        add_settings_error('wpam_settings', 'app_store_url', 'Enter a Google Play app link containing /store/apps/details?id=your.package.');
        $store = wpam_settings()['app_store_url'];
    }
    $out['app_store_url'] = $store;
    $ios = wpam_https_url($input['ios_store_url'] ?? '');
    if ($ios && (strtolower((string) wp_parse_url($ios, PHP_URL_HOST)) !== 'apps.apple.com'
        || !preg_match('~/id[0-9]+/?$~', (string) wp_parse_url($ios, PHP_URL_PATH)))) {
        add_settings_error('wpam_settings', 'ios_store_url', 'Enter an Apple App Store app link ending in /id followed by its numeric app ID.');
        $ios = wpam_settings()['ios_store_url'];
    }
    $out['ios_store_url'] = $ios;
    $out['youtube_channel_id'] = WPAM_CHANNEL;

    return $out;

}



function wpam_categories(array $ids): array {

    $items = [];

    foreach ($ids as $id) {

        $term = get_term($id, 'category');

        if (!$term || is_wp_error($term)) continue;

        $items[] = ['id' => (int) $term->term_id, 'name' => html_entity_decode($term->name, ENT_QUOTES, 'UTF-8'), 'slug' => $term->slug];

    }

    return $items;

}



function wpam_public_config(): array {

    $s = wpam_settings();

    if (function_exists('wpam_live_banners') && get_option('wpam_banners_migrated')) {

        foreach (array_keys(WPAM_AD_PLACEMENTS) as $placement) $s[$placement] = wpam_live_banners($placement);

    }

    return [

        'schema_version' => 1, 'edition' => $s['edition'], 'label' => $s['label'],

        'site_url' => home_url('/'), 'wordpress_api' => rest_url('wp/v2/'),

        'branding' => ['logo_url' => $s['logo_url'], 'preloader_url' => $s['preloader_url'], 'preloader_color' => $s['preloader_color'], 'primary' => $s['primary'], 'secondary' => $s['secondary'], 'confirmed' => (bool) $s['branding_confirmed']],

        'home_categories' => wpam_categories($s['home_categories']),

        'explore_categories' => wpam_categories($s['explore_categories']),

        'home_sections' => $s['sections'], 'banners' => $s['banners'],

        'inline_ads' => $s['inline_ads'], 'footer_ads' => $s['footer_ads'],

        'app_store_url' => $s['app_store_url'], 'ios_store_url' => $s['ios_store_url'],
        'social_links' => $s['social_links'], 'wallpapers' => $s['wallpapers'],

        'default_wallpapers_enabled' => $s['default_wallpapers_enabled'],

        'featured_ids' => $s['featured_ids'], 'interview_categories' => wpam_interview_categories(),

        'youtube_channel_id' => WPAM_CHANNEL,

        'magazines_url' => rest_url(WPAM_NAMESPACE . '/magazines'),

        'events_url' => rest_url(WPAM_NAMESPACE . '/events'),

        'newsletter' => ['enabled' => (bool) $s['newsletter_enabled'], 'url' => rest_url(WPAM_NAMESPACE . '/newsletter')],

        'contact' => ['enabled' => (bool) $s['contact_enabled'], 'url' => rest_url(WPAM_NAMESPACE . '/contact')],

        'about_page_id' => (int) $s['about_page_id'], 'contact_page_id' => (int) $s['contact_page_id'],

        'notification_topic' => 'wood_panel_' . $s['edition'],

    ];

}



function wpam_interview_categories(): array {

    $terms = get_terms(['taxonomy' => 'category', 'hide_empty' => false, 'slug' => ['interview', 'interviews']]);

    return is_wp_error($terms) ? [] : array_map(static fn($term) => (int) $term->term_id, $terms);

}


<?php

defined('ABSPATH') || exit;



function wpam_admin_menu(): void {

    $settings_slug = 'wood-panel-app-settings';

    add_menu_page('Wood & Panel App Manager', 'Wood & Panel App', 'manage_options', $settings_slug, 'wpam_admin_page', 'dashicons-smartphone');

    add_submenu_page($settings_slug, 'App Settings', 'Settings', 'manage_options', $settings_slug, 'wpam_admin_page');

    add_submenu_page($settings_slug, 'App Notifications', 'Notifications', 'manage_options', 'wpam-notifications', 'wpam_notifications_page');

    add_submenu_page($settings_slug, 'App Profiles', 'Profiles', 'manage_options', 'wpam-profiles', 'wpam_profiles_page');
    add_submenu_page($settings_slug, 'App Submissions', 'Submissions', 'manage_options', 'wpam-submissions', 'wpam_submissions_page');

    add_submenu_page($settings_slug, 'Add Banner', 'Add Banner', 'manage_options', 'post-new.php?post_type=wpam_banner');

    add_submenu_page($settings_slug, 'Banner Reports', 'Banner Reports', 'manage_options', 'wpam-banner-reports', 'wpam_banner_reports');

    // Independent entry point for sites that redirect the top-level plugin route.

    add_options_page('Wood & Panel App Settings', 'Wood & Panel App', 'manage_options', 'wpam-configuration', 'wpam_admin_page');

}



function wpam_register_settings(): void {

    register_setting('wpam', 'wpam_settings', ['type' => 'array', 'sanitize_callback' => 'wpam_sanitize_settings', 'show_in_rest' => false]);

}



function wpam_admin_assets($hook): void {

    if (!in_array($hook, ['toplevel_page_wood-panel-app-settings', 'settings_page_wpam-configuration'], true)) return;

    wp_enqueue_media();

    $base = plugin_dir_url(dirname(__DIR__) . '/wood-panel-app-manager.php');

    wp_enqueue_style('wpam-admin', $base . 'assets/admin.css', [], '0.8.0');

    wp_enqueue_script('wpam-admin', $base . 'assets/admin.js', ['media-editor'], '0.8.0', true);

}



function wpam_input(string $key, string $label, string $type = 'text'): void {

    $s = wpam_settings();

    echo '<tr><th scope="row"><label for="wpam-' . esc_attr($key) . '">' . esc_html($label) . '</label></th><td>';

    if ($type === 'checkbox') {

        echo '<input type="checkbox" id="wpam-' . esc_attr($key) . '" name="wpam_settings[' . esc_attr($key) . ']" value="1" ' . checked(!empty($s[$key]), true, false) . '>';

    } else {

        $value = is_array($s[$key]) ? implode(',', $s[$key]) : $s[$key];

        echo '<input class="regular-text" type="' . esc_attr($type) . '" id="wpam-' . esc_attr($key) . '" name="wpam_settings[' . esc_attr($key) . ']" value="' . esc_attr($value) . '">';

    }

    echo '</td></tr>';

}



function wpam_ordered_choices(string $key, array $choices): void {

    $selected = wpam_settings()[$key];

    $ordered = array_unique(array_merge($selected, array_keys($choices)));

    echo '<ul class="wpam-order" data-field="' . esc_attr($key) . '">';

    foreach ($ordered as $id) {

        if (!isset($choices[$id])) continue;

        echo '<li><label><input type="checkbox" name="wpam_settings[' . esc_attr($key) . '][]" value="' . esc_attr($id) . '" ' . checked(in_array($id, $selected, true), true, false) . '> ' . esc_html($choices[$id]) . '</label> ';

        echo '<button type="button" class="button wpam-up" aria-label="Move up">&#8593;</button> <button type="button" class="button wpam-down" aria-label="Move down">&#8595;</button></li>';

    }

    echo '</ul>';

}



function wpam_admin_page(): void {

    if (!current_user_can('manage_options')) return;

    $s = wpam_settings();

    $terms = get_terms(['taxonomy' => 'category', 'hide_empty' => false]);

    $categories = [];

    if (!is_wp_error($terms)) foreach ($terms as $term) $categories[(int) $term->term_id] = $term->name . ' (#' . $term->term_id . ')';

    ?>

    <div class="wrap wpam-settings">

      <h1>Wood &amp; Panel App Manager</h1>

      <?php settings_errors(); ?>

      <p>Settings apply only to this website's edition. Publishing these settings does not change the website theme.</p>

      <p><a target="_blank" rel="noopener" href="<?php echo esc_url(rest_url(WPAM_NAMESPACE . '/config')); ?>">View public app configuration</a></p>

      <?php if (!$s['branding_confirmed']): ?><div class="notice notice-warning inline"><p>Review the logo and colours, then confirm branding before enabling this edition in the app.</p></div><?php endif; ?>

      <form method="post" action="options.php">

        <?php settings_fields('wpam'); ?>

        <h2>Edition and branding</h2>

        <table class="form-table"><tbody>

          <tr><th><label for="wpam-edition">Edition</label></th><td><select id="wpam-edition" name="wpam_settings[edition]">

            <option value="europe" <?php selected($s['edition'], 'europe'); ?>>Europe</option>

            <option value="usa" <?php selected($s['edition'], 'usa'); ?>>USA</option>

          </select></td></tr>

          <?php

          wpam_input('label', 'Edition label');

          wpam_input('logo_url', 'Approved logo URL (HTTPS)', 'url');

          wpam_input('preloader_url', 'Loading image (PNG, JPG or WebP)', 'url');

          wpam_input('preloader_color', 'Loading screen background', 'color');

          wpam_input('primary', 'Primary colour', 'color');

          wpam_input('secondary', 'Secondary colour', 'color');

          wpam_input('branding_confirmed', 'Branding reviewed and approved', 'checkbox');

          ?>

        </tbody></table>

        <h2>Categories</h2>

        <p>One selection for Home and Explore. Search, select and arrange the categories to display. An empty selection hides categories.</p>

        <?php wpam_ordered_choices('home_categories', $categories); ?>

        <p>Interviews are automatic: the app combines posts in the Interview/Interviews categories with the existing legacy interview archive. They are not restricted by this category selection.</p>

        <h2>Home sections</h2>

        <?php wpam_ordered_choices('sections', array_combine(WPAM_SECTIONS, array_map('ucfirst', WPAM_SECTIONS))); ?>

        <details><summary>Optional: choose specific Trending articles</summary>

        <p>Normally Trending uses the app's automatic selection. Enter published news IDs only to override it; leave empty for automatic selection. This does not change Latest News.</p>

        <table class="form-table"><tbody><?php wpam_input('featured_ids', 'Trending article IDs (optional, comma-separated)'); ?></tbody></table></details>

        <h2>Promotional banners</h2>

        <p>Use approved HTTPS images. Rows are displayed in this order. Leave the link empty for a non-clickable banner.</p>

        <?php wpam_banner_fields('banners', $s['banners']); ?>

        <h2>Inline advertisements</h2>

        <p>Upload square 350 x 350 px images (320 x 320 also works). One ad appears after every three news stories, interviews, videos or feed stories. Ads follow this order and repeat from the beginning. Leave empty to disable.</p>

        <?php wpam_banner_fields('inline_ads', $s['inline_ads']); ?>

        <h2>Footer advertisements</h2>

        <p>Select 350 x 50 px or 350 x 100 px for each banner, then upload matching artwork and an optional link. Banners appear above navigation, in order: first banner on opening, next banner on navigation or manual refresh, repeating from the beginning. Minimize and close apply to the current page. Leave empty to disable.</p>

        <?php wpam_banner_fields('footer_ads', $s['footer_ads']); ?>

        <h2>Website content sources</h2>

        <p>Advanced setup, normally done once by your website developer. These mappings tell the app where this site stores magazine covers, reader/PDF links and event dates. They do not create or edit website content. Leave optional fields empty when not used. Europe can use its existing archive when Magazine post type is not configured.</p>

        <table class="form-table"><tbody>

        <?php foreach (['magazine_type' => 'Magazine post type', 'event_type' => 'Event post type'] as $key => $label): ?>

          <tr><th><label for="wpam-<?php echo esc_attr($key); ?>"><?php echo esc_html($label); ?></label></th><td>

          <select id="wpam-<?php echo esc_attr($key); ?>" name="wpam_settings[<?php echo esc_attr($key); ?>]">

            <option value="">Not configured</option>

            <?php foreach (get_post_types(['public' => true], 'objects') as $type): if ($type->name === 'attachment') continue; ?>

              <option value="<?php echo esc_attr($type->name); ?>" <?php selected($s[$key], $type->name); ?>><?php echo esc_html($type->label . ' (' . $type->name . ')'); ?></option>

            <?php endforeach; ?>

          </select></td></tr>

        <?php endforeach;

          wpam_input('magazine_cover_key', 'Magazine cover metadata key (URL or attachment ID; optional)');

          wpam_input('magazine_read_key', 'Magazine read-online URL metadata key');

          wpam_input('magazine_pdf_key', 'Magazine PDF URL metadata key');

          wpam_input('magazine_date_key', 'Magazine issue date metadata key (optional)');

          wpam_input('event_date_key', 'Event date metadata key');

          wpam_input('event_location_key', 'Event venue text metadata key (optional for The Events Calendar)');

        ?></tbody></table>

        <p>Volume is calculated by year (2026 = Volume 18). Issues run from 1 (Jan?Feb) to 6 (Nov?Dec).</p>

        <h2>In This Issue</h2>

        <p>Add a magazine Read Online URL and one highlight per line. Empty entries are hidden in the app. Up to 30 points per magazine.</p>

        <?php wpam_content_rows('magazine_highlights', $s['magazine_highlights']); ?>

        <h2>Wallpapers</h2>

        <table class="form-table"><tbody><?php wpam_input('default_wallpapers_enabled', 'Show bundled wood wallpapers', 'checkbox'); ?></tbody></table>

        <p>Your uploaded wallpapers appear alongside the defaults. Disable the option above to show only your uploads.</p>

        <?php wpam_content_rows('wallpapers', $s['wallpapers']); ?>

        <h2>Forms and regional pages</h2>

        <p>Enable newsletter/contact submissions for this site. About and Contact page IDs select published website pages to show inside the app; 0 leaves them unconfigured.</p>

        <table class="form-table"><tbody><?php

          wpam_input('newsletter_enabled', 'Accept newsletter subscriptions', 'checkbox');

          wpam_input('contact_enabled', 'Accept contact submissions', 'checkbox');

          wpam_input('about_page_id', 'Published About page ID', 'number');

          wpam_input('contact_page_id', 'Published Contact page ID', 'number');

        ?></tbody></table>

        <p>Submissions are stored privately on this site. Newsletter registration does not send campaigns.</p>

        <h2>Contact details</h2><p>Contact page details for this edition. Both editions start with the same details; changes apply only to this website.</p>
        <table class="form-table"><?php foreach (wpam_contact_defaults() as $key => $default): ?>
        <tr><th><label for="contact-<?php echo esc_attr($key); ?>"><?php echo esc_html(ucwords(str_replace('_', ' ', $key))); ?></label></th><td><textarea rows="2" class="large-text" id="contact-<?php echo esc_attr($key); ?>" name="wpam_settings[contact_details][<?php echo esc_attr($key); ?>]"><?php echo esc_textarea($s['contact_details'][$key] ?? $default); ?></textarea></td></tr>
        <?php endforeach; ?></table>
        <h2>Privacy Policy</h2>
        <p>Published in the app Preferences for this edition. Review and adapt this default policy to your actual data practices before publication. Use plain text with blank lines between sections.</p>
        <label for="wpam-privacy-policy">Privacy Policy content</label>
        <textarea id="wpam-privacy-policy" class="large-text" rows="22" name="wpam_settings[privacy_policy]"><?php echo esc_textarea($s['privacy_policy']); ?></textarea>
        <h2>Terms &amp; Conditions</h2>
        <p>Published in the app Preferences for this edition. Review and adapt the default terms before publication.</p>
        <label for="wpam-terms">Terms &amp; Conditions content</label>
        <textarea id="wpam-terms" class="large-text" rows="22" name="wpam_settings[terms_conditions]"><?php echo esc_textarea($s['terms_conditions']); ?></textarea>
        <h2>Social media</h2><p>These links appear on Contact, Profile and the app menu for this edition. Leave a link empty to hide its icon.</p>
        <table class="form-table"><tbody>
        <?php foreach (wpam_social_defaults() as $key => $default): ?>
        <tr><th><?php echo esc_html(ucfirst($key)); ?></th><td><input class="large-text" type="url" name="wpam_settings[social_links][<?php echo esc_attr($key); ?>]" value="<?php echo esc_attr($s['social_links'][$key] ?? $default); ?>"></td></tr>
        <?php endforeach; ?></tbody></table>
        <h2>App store links</h2>
        <p>Used by Rate Our App and Share App in both editions. Android uses Google Play; iOS uses Apple App Store. Set either link on either website. Europe takes priority separately for each platform when both websites have links. Leave blank until your listing is available.</p>
        <table class="form-table"><tr><th>Google Play app URL</th><td><input class="large-text" type="url" name="wpam_settings[app_store_url]" value="<?php echo esc_attr($s['app_store_url']); ?>" placeholder="https://play.google.com/store/apps/details?id=your.package"><p class="description">Save app settings after entering the link.</p></td></tr></table>
        <table class="form-table"><tr><th>iOS App Store URL</th><td><input class="large-text" type="url" name="wpam_settings[ios_store_url]" value="<?php echo esc_attr($s['ios_store_url']); ?>" placeholder="https://apps.apple.com/app/your-app/id123456789"><p class="description">Used on iPhones and iPads. Save app settings after entering the link.</p></td></tr></table>
        <h2>Shared videos</h2><p>YouTube channel: <code><?php echo esc_html(WPAM_CHANNEL); ?></code></p>

        <h2>Push configuration</h2>
        <p>Edition topic: <code>wood_panel_<?php echo esc_html($s['edition']); ?></code></p>
        <?php if (defined('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE') && is_readable(WPAM_FIREBASE_SERVICE_ACCOUNT_FILE)): ?>
            <p>Firebase credential file is available. Delivery status is shown after sending a notification.</p>
        <?php else: ?>
            <p>Firebase credential file is missing or unreadable. Check WPAM_FIREBASE_SERVICE_ACCOUNT_FILE in this website's wp-config.php.</p>
        <?php endif; ?>
        <p>Search published news, view publication dates, send image notifications, or schedule a notification on the dedicated Notifications page.</p>
        <p><a class="button button-primary" href="<?php echo esc_url(admin_url('admin.php?page=wpam-notifications')); ?>">Open news search and notification scheduling</a></p>

        <?php submit_button('Save app settings'); ?>

      </form>

      <h2>Configuration checks</h2>

      <ul>

        <li>Site: <?php echo esc_html(home_url('/')); ?></li>

        <li>Logo: <?php echo $s['logo_url'] ? 'Configured' : 'Missing'; ?></li>

        <li>Magazine source: <?php echo esc_html($s['magazine_type'] ?: 'Not configured'); ?></li>

        <li>PDF mapping: <?php echo esc_html($s['magazine_pdf_key'] ?: 'Not configured; PDF actions must remain unavailable'); ?></li>

        <li>Event source: <?php echo esc_html($s['event_type'] ?: 'Not configured'); ?></li>

        <li><a target="_blank" rel="noopener" href="<?php echo esc_url(rest_url(WPAM_NAMESPACE . '/magazines')); ?>">Check magazine API</a></li>

        <li><a target="_blank" rel="noopener" href="<?php echo esc_url(rest_url(WPAM_NAMESPACE . '/events')); ?>">Check event API</a></li>

      </ul>

    </div>

    <style>

      .wpam-order {max-width:800px;max-height:280px;overflow:auto;border:1px solid #ddd;padding:8px;background:#fff}

      .wpam-order li {display:flex;gap:8px;align-items:center;padding:5px;margin:0;border-bottom:1px solid #eee}

      .wpam-order label {flex:1}.wpam-banner {display:flex;flex-wrap:wrap;gap:8px;padding:12px 0;border-bottom:1px solid #ddd}

      .wpam-banner label {display:flex;flex-direction:column}.wpam-banner .regular-text {max-width:100%}

    </style>



    <?php

}



function wpam_banner_fields(string $placement, array $banners): void {

    if (get_option('wpam_banners_migrated')) {

        echo '<p><a class="button" href="' . esc_url(admin_url('edit.php?post_type=wpam_banner')) . '">Manage banners</a> <a class="button" href="' . esc_url(admin_url('post-new.php?post_type=wpam_banner')) . '">Add Banner</a> <a class="button" href="' . esc_url(wpam_banner_report_url()) . '">Reports</a></p><p>Banners are now managed individually with publishing, dates, order and reports. Select this placement in the banner editor.</p>';

        return;

    }

    echo '<div id="wpam-' . esc_attr($placement === 'banners' ? 'banners' : $placement) . '" class="wpam-banner-list" data-placement="' . esc_attr($placement) . '">';

    foreach ($banners as $index => $banner) {

        echo '<div class="wpam-banner">';

        if ($placement === 'footer_ads') {

            echo '<label>Banner size<select name="wpam_settings[footer_ads][' . (int) $index . '][size]">';

            foreach (['350x50' => '350 x 50 px', '350x100' => '350 x 100 px'] as $size => $text) {

                echo '<option value="' . esc_attr($size) . '"' . selected($banner['size'] ?? '350x50', $size, false) . '>' . esc_html($text) . '</option>';

            }

            echo '</select></label>';

        }

        foreach (['image_url' => 'Image URL', 'link_url' => 'Link URL (optional)', 'label' => 'Accessible label'] as $key => $label) {

            echo '<label>' . esc_html($label) . '<input class="regular-text" type="' . ($key === 'label' ? 'text' : 'url') . '" name="wpam_settings[' . esc_attr($placement) . '][' . (int) $index . '][' . esc_attr($key) . ']" value="' . esc_attr($banner[$key] ?? '') . '"></label>';

        }

        echo '<button type="button" class="button wpam-up" aria-label="Move up">&#8593;</button><button type="button" class="button wpam-down" aria-label="Move down">&#8595;</button><button type="button" class="button wpam-remove">Remove</button></div>';

    }

    echo '</div><button type="button" class="button wpam-add-banner" data-placement="' . esc_attr($placement) . '">Add banner</button>';

}





function wpam_content_rows(string $kind, array $rows): void {

    $fields = $kind === 'wallpapers' ? ['id' => 'ID (optional)', 'title' => 'Title', 'category' => 'Category', 'image_url' => 'Image URL'] : ['readUrl' => 'Magazine Read Online URL', 'points' => 'Highlights (one per line)'];

    echo '<div class="wpam-content-list" data-kind="' . esc_attr($kind) . '">';

    foreach (array_merge($rows, [array_fill_keys(array_keys($fields), '')]) as $i => $row) {

        echo '<div class="wpam-content-row" style="padding:16px;margin:12px 0;border:1px solid #ddd;border-radius:8px">';

        foreach ($fields as $key => $label) {

            $value = $row[$key] ?? '';

            if (is_array($value)) $value = implode("\n", $value);

            $name = 'wpam_settings[' . $kind . '][' . $i . '][' . $key . ']';

            echo '<label style="display:block;margin-bottom:12px">' . esc_html($label);

            if ($key === 'points') echo '<textarea class="large-text" rows="5" name="' . esc_attr($name) . '">' . esc_textarea($value) . '</textarea>';

            else echo '<input class="large-text" type="' . (in_array($key, ['image_url', 'readUrl'], true) ? 'url' : 'text') . '" name="' . esc_attr($name) . '" value="' . esc_attr($value) . '">';

            echo '</label>';

        }

        echo '<button type="button" class="button wpam-content-remove">Remove</button></div>';

    }

    echo '</div><button type="button" class="button wpam-content-add" data-kind="' . esc_attr($kind) . '">Add another</button>';

}


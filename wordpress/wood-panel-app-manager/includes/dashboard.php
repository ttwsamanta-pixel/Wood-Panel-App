<?php
defined('ABSPATH') || exit;

// Keep registered routes for compatibility and capabilities; show their links
// inside the application dashboard instead of the WordPress flyout menu.
add_action('admin_head', static function (): void {
    echo '<style>#toplevel_page_wood-panel-app-settings .wp-submenu{display:none!important}</style>';
});
add_action('admin_menu', static function (): void {
    // The fallback URL remains registered, but does not duplicate the main menu.
    remove_submenu_page('options-general.php', 'wpam-configuration');
}, 100);
add_action('admin_enqueue_scripts', static function (): void {
    $screen = get_current_screen();
    $page = sanitize_key($_GET['page'] ?? '');
    if (!$screen || ($screen->post_type !== 'wpam_banner' && !in_array($page, ['wood-panel-app-settings', 'wpam-configuration', 'wpam-notifications', 'wpam-profiles', 'wpam-submissions', 'wpam-banner-reports'], true))) return;
    $base = plugin_dir_url(dirname(__DIR__) . '/wood-panel-app-manager.php');
    wp_enqueue_style('wpam-dashboard', $base . 'assets/dashboard.css', [], '0.7.1');
    wp_enqueue_script('wpam-dashboard', $base . 'assets/dashboard.js', [], '0.7.1', true);
    wp_localize_script('wpam-dashboard', 'wpamDashboard', [
        'edition' => wpam_edition() === 'usa' ? 'USA' : 'Europe',
        'sections' => ['Edition and branding', 'Categories', 'Home sections', 'Promotional banners', 'Inline advertisements', 'Footer advertisements', 'Website content sources', 'In This Issue', 'Wallpapers', 'Forms and regional pages', 'Contact details', 'Social media', 'App store links', 'Shared videos', 'Push configuration'],
        'links' => [
            ['label' => 'Application settings', 'url' => admin_url('admin.php?page=wood-panel-app-settings')],
            ['label' => 'All banners', 'url' => admin_url('edit.php?post_type=wpam_banner')],
            ['label' => 'Add banner', 'url' => admin_url('post-new.php?post_type=wpam_banner')],
            ['label' => 'Banner reports', 'url' => admin_url('admin.php?page=wpam-banner-reports')],
            ['label' => 'Notifications', 'url' => admin_url('admin.php?page=wpam-notifications')],
            ['label' => 'Submissions', 'url' => admin_url('admin.php?page=wpam-submissions'), 'children' => [
                ['label' => 'Newsletter', 'kind' => 'newsletter', 'url' => admin_url('admin.php?page=wpam-submissions&kind=newsletter')],
                ['label' => 'Contact', 'kind' => 'contact', 'url' => admin_url('admin.php?page=wpam-submissions&kind=contact')],
                ['label' => 'Profile', 'kind' => 'profile', 'url' => admin_url('admin.php?page=wpam-submissions&kind=profile')],
            ]],
        ],
    ]);
});

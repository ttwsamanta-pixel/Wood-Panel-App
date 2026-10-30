<?php
/**
 * Plugin Name: Wood & Panel App Manager
 * Description: Edition-specific configuration and submissions for the Wood & Panel app.
 * Version: 0.6.1
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * Author: Wood & Panel
 * License: GPL-2.0-or-later
 */
defined('ABSPATH') || exit;

require_once __DIR__ . '/includes/config.php';
require_once __DIR__ . '/includes/profiles.php';
require_once __DIR__ . '/includes/rest.php';
require_once __DIR__ . '/includes/admin.php';
require_once __DIR__ . '/includes/notifications.php';
require_once __DIR__ . '/includes/banner-manager.php';
require_once __DIR__ . '/includes/banner-reports.php';

add_action('init', 'wpam_register_banners');
add_action('init', 'wpam_banner_upgrade', 20);
add_action('add_meta_boxes_wpam_banner', 'wpam_banner_meta_box');
add_action('save_post_wpam_banner', 'wpam_save_banner');
add_action('admin_enqueue_scripts', 'wpam_banner_assets');
add_action('admin_notices', 'wpam_banner_notices');
add_action('admin_menu', 'wpam_banner_menu_order', 99);
add_filter('manage_wpam_banner_posts_columns', 'wpam_banner_columns');
add_action('manage_wpam_banner_posts_custom_column', 'wpam_banner_column', 10, 2);
add_filter('post_row_actions', 'wpam_banner_actions', 10, 2);
add_action('admin_post_wpam_ad_export', 'wpam_ad_export');
add_action('wpam_ad_cleanup', 'wpam_ad_cleanup');

register_activation_hook(__FILE__, 'wpam_activate');
add_action('admin_menu', 'wpam_admin_menu');
add_action('admin_init', 'wpam_register_settings');
add_action('admin_enqueue_scripts', 'wpam_admin_assets');
add_action('rest_api_init', 'wpam_register_routes');

function wpam_activate(): void {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $table = $wpdb->prefix . 'wpam_submissions';
    $collation = $wpdb->get_charset_collate();
    dbDelta("CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        kind varchar(20) NOT NULL,
        email varchar(254) NOT NULL,
        name varchar(160) NOT NULL DEFAULT '',
        country varchar(100) NOT NULL DEFAULT '',
        subject varchar(200) NOT NULL DEFAULT '',
        message text NOT NULL,
        photo mediumtext NULL,
        submission_key varchar(64) DEFAULT NULL,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY kind_created (kind,created_at),
        UNIQUE KEY submission_key (submission_key)
    ) $collation;");
    add_option('wpam_settings', wpam_defaults(), '', false);
}

add_action('init', 'wpam_profile_upgrade', 5);
add_action('admin_post_wpam_submission_action', 'wpam_submission_action');

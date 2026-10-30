<?php
// Isolated local WordPress fixture. Never run against either live website.
$root = dirname(__DIR__, 2) . '/artifacts/wp-test/wordpress';
if (!is_dir($root)) throw new RuntimeException('Extract WordPress into artifacts/wp-test/wordpress first.');
$config = <<<'PHP'
<?php
define('DB_NAME', 'wpam_banner_test');
define('DB_USER', 'root');
define('DB_PASSWORD', '');
define('DB_HOST', '127.0.0.1:3317');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
define('WP_HOME', 'http://127.0.0.1:8097');
define('WP_SITEURL', 'http://127.0.0.1:8097');
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
define('DISABLE_WP_CRON', true);
define('WP_HTTP_BLOCK_EXTERNAL', true);
define('AUTH_KEY', 'local-banner-test-only');
define('SECURE_AUTH_KEY', 'local-banner-test-only-secure');
define('LOGGED_IN_KEY', 'local-banner-test-only-login');
define('NONCE_KEY', 'local-banner-test-only-nonce');
$table_prefix = 'wpamtest_';
if (!defined('ABSPATH')) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
PHP;
file_put_contents($root . '/wp-config.php', $config);
define('WP_INSTALLING', true);
require $root . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
if (!is_blog_installed()) wp_install('Banner test fixture', 'banneradmin', 'test@example.invalid', false, '', 'LocalBannerTest-927!');
echo "Local WordPress installed.\n";

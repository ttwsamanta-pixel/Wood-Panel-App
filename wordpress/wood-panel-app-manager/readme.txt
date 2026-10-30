=== Wood & Panel App Manager ===
Contributors: woodandpanel
Requires at least: 6.0
Requires PHP: 8.0
Stable tag: 0.4.2
License: GPLv2 or later

Regional configuration, content adapters, newsletter/contact storage and edition-specific Firebase notification sending for the Wood & Panel Flutter app.

== Installation ==
Install separately on Europe and USA WordPress sites. Configure categories, branding, sections, banners, magazine/event sources and regional pages under Wood & Panel App. Verify the public configuration and content endpoints before releasing the app.

Europe's archive pages are supported when no magazine post type is selected. USA magazine metadata must be mapped to the existing site's fields. No PDF URL is guessed by the plugin.

Newsletter/contact submissions are stored in the current site's database and visible only to administrators. Newsletter campaigns are not sent automatically. Deactivation does not erase submissions or settings.

Notifications require WPAM_FIREBASE_SERVICE_ACCOUNT_FILE in wp-config.php pointing to a private JSON file outside the web root, and a configured Firebase app. Never put private credentials in the public media library. See the app repository's docs/dual-edition-deployment.md for deployment and verification instructions.

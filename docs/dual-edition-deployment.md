# Dual-edition deployment

## Status and boundaries

This updates the existing Flutter app, not a replacement app. The old `backend/` remains untouched. Both sites use their own installation of `Wood & Panel App Manager` and their own WordPress database.

As of 27 October 2026, plugin 0.4.0 and the tracking-enabled Android debug app are packaged locally. Replace the plugin on each site to enable the individual banner workflow and reports. Phone installation/testing is deferred until the user reconnects and explicitly requests it. Live category/banner selections are managed independently by each site administrator. Firebase delivery, real form database submissions, source-field mappings and iOS signing/device tests still require deployment verification.

## Backup

Pre-update source/assets/Git state and previous debug APK:

`D:\sourav samanta\Wood & Panel\Backups\Wood-Panel-Before-Dual-Edition-2026-10-24-160553.zip`

SHA-256: `E36EC27B026EA23AE2131E492772F4EF1576CBF73A00FEB46F230E33D80990EB`

Restore into a separate directory first; do not overwrite newer user work. No website database was changed by this local update.

## WordPress installation

### Banner management and reports (0.4.0)

- Open **Wood & Panel App â†’ All Banners**, **Add Banner**, or **Banner Reports**. The parent menu still opens Settings. Home, inline and footer banners are managed in one list with a placement field, rather than duplicated settings editors.
- Existing banner arrays migrate once to published banner records, preserving placement, image, link, label, order and footer size. Original settings are retained in `wpam_banner_legacy_backup`. Migration is retryable and checks imported keys to prevent duplicates. Draft, paused, future-start and expired banners are excluded from the public configuration. Dates use the WordPress site's timezone, and the end date is inclusive. The app must refresh configuration to receive scheduling changes (the public configuration may be cached for two minutes).
- Add/edit: title, placement, footer size (350Ã—50 or 350Ã—100), WordPress media picker/image URL, destination link, accessible description, optional start/end dates, Active checkbox and numeric display order. Publish to show it; use Draft or uncheck Active to pause. Lower order numbers appear first; equal orders use creation ID. Settings pages link to the manager after migration.
- List: search, native WordPress publication/date filters, trash/bulk actions, preview, destination, placement/size, dates, status, order, totals and per-banner Report link. Quick Edit is intentionally hidden so the full banner form remains the source of banner details.
- Reports: total and today's impressions/clicks/CTR, plus individual Today, All time, Last month and This month cards; date-range chart, daily table and selected-period totals. Chart/CSV ranges are bounded to 93 inclusive days. CTR is clicks Ã· impressions Ã— 100, or 0% when impressions are zero. Counters start with the new app and cannot reconstruct historical views from old versions.
- CSV download is available without email. Optional email export accepts up to three recipients and uses the website's mail configuration; successful handoff is not a delivery guarantee. No report email was sent during verification.
- The app records a view after the downloaded image is at least 50% visible for one continuous second while the app/route is active, or when it is tapped before that second. Off-screen preload, failed images, minimized ads and inactive routes do not count. A new continuous exposure can count again; these are not unique-person metrics. Visibility is geometric and cannot fully detect arbitrary overlays/opacity. Clicks count one tap per exposure. Closing/minimizing does not count as clicking.
- Events use `/wp-json/wood-panel-app/v1/ad-event` on the selected edition only. Signed banner/placement tokens, active-banner validation, a short rate limit and an atomic event receipt prevent routine duplicates. The retry uses the same view identity. Daily totals use separate per-site tables; transient deduplication receipts expire after seven days. No persistent device ID or raw IP is written to reports. Public app events can be spoofed and offline deliveries can be missed, so these statistics are indicative, not independently audited billing metrics.
- Local verification: separate WordPress 7.0.4 + MariaDB fixture; real upgrade/migration, schedule, event deduplication, malformed requests, totals, permissions and report rendering; browser create/publish/edit/media-picker/report/CSV flow; HTTP event-to-report checks. Flutter analysis/tests and Android build also pass. Live mail delivery and physical-phone verification remain pending.

### Advertisement placements (plugin 0.3.1)

- Promotional banners remain the Home carousel, independent of the two new placements.
- Inline advertisements: upload 350 x 350 px square artwork (320 x 320 is also supported). News, category news, interviews, videos and Feed insert one ad after each three content items. Four configured banners produce A, B, C, D, A after items 3, 6, 9, 12, 15. Ordering restarts for each list/search result. An empty placement inserts no ad slots.
- Footer advertisements: select 350 x 50 px or 350 x 100 px separately for each image before uploading. The app preserves that ratio and scales down on narrow screens. Existing banners default to 350 x 50. The strip sits above bottom navigation, never over the content. Minimize preserves an expand control; close hides the strip for that page. Navigation, Explore tab changes and manual refresh restore it and advance to the next banner in order, looping at the end. Each edition has its own session counter starting at the first banner. Feed cards fit their image, text and action into the remaining space above the footer without a separate text scroller.
- Each placement supports image uploads/library selection, HTTPS links, labels, ordering and removal independently on Europe and USA. Save settings on each site, then refresh the app's Home page.
- Banner preloading starts from the saved edition configuration while fresh settings are requested. The first Home/footer/inline images are prioritized, then remaining rotation images are fetched with at most two preload requests at once. Disk and decoded-image caches are shared with the visible banners; no spinner or fade animation is shown. First-ever image downloads still require a working connection. Use appropriately sized, compressed artwork; the app does not promise instant downloads.
- Local tests cover slot arithmetic, rotation, footer controls, small-screen feed layout, settings sanitization and admin UI repeaters. Real ad delivery remains pending until the new plugin is uploaded and advertisements are configured on the live sites.

1. Back up each site's database and test on staging first.
2. Upload `artifacts/dual-edition/wood-panel-app-manager.zip` through Plugins > Add New > Upload Plugin on EACH site. Activate it.
3. Open Wood & Panel App. Verify Europe on `.com`, USA on `.us`. Do not select another edition for a production domain.
4. Review logo, label, primary/secondary colours and confirm branding. USA defaults come from its official SVG: red `#A41E22`, navy `#223268`. Europe retains existing copper/green. An HTTPS logo can override the bundled asset.
5. In plugin 0.2.0, use Categories to search, select and order one list shared by Home and Explore. Save once to synchronize any older separate selections. Interviews are automatic: Interview/Interviews post categories plus the regional legacy archive. Empty category selections intentionally hide categories.
6. Select/order Home sections, add HTTPS banners, and optionally enter published featured news IDs. These populate Trending, up to 12 items. Videos remain the existing shared channel `UChylAsyNbYR6yvGmPz59iCA`.
7. Configure magazine/event sources as described below. Set published About/Contact page IDs. Configure regional wallpaper JSON if wanted; IDs should be unique and stable.
8. Enable newsletter/contact forms. Submissions are stored privately in this site's `wpam_submissions` table; view/delete them under Submissions. Newsletter registration stores submitted details only; it does not send a campaign or confirmation email.
9. Open the configuration and content API check links. Confirm `schema_version: 1`, correct `edition`, real covers, correct dates and working reader/PDF URLs.
10. Pull-to-refresh Home or switch editions after saving. The app requests fresh configuration on these actions and uses saved configuration only on network failure. Server/CDN caching may still delay configuration changes by up to two minutes. The remotely configured loading image applies to Flutter loading screens after configuration is available, not the native OS launch splash.

Required PHP: 8.0+, DOM extension for Europe archive adapter; OpenSSL for notification sending. WordPress: 6.0+. Admin changes use `manage_options` and WordPress nonces. Public form endpoints validate lengths/types/email, use a honeypot and IP rate limiting. Add edge/WAF protection for production abuse. Behind a proxy, configure trusted client IP handling at the server; the plugin does not trust arbitrary forwarded headers.

## Content source audit

Audit on 24 October 2026:

- Europe exposes WordPress posts, pages and The Events Calendar types. Its public REST types do not include `magazine`; current issues are rendered at `/archive/archive-2026/`.
- With Europe magazine type left empty, the plugin reads each same-site yearly archive (2022 through the current year), parses its cards with DOM, caches each year for five minutes, and returns paginated issues. Reader URLs must belong to the site. PDF actions are supplied only when an explicit PDF link is present; PDFs are not guessed by this adapter.
- USA exposes `magazine`, `upcoming_event` and `tribe_events`. Its Europe-style `/archive/archive-2026/` returned HTTP 500. Select its real magazine post type and map the existing cover, reader, PDF and issue-date metadata keys. Private custom-field names cannot be determined reliably from the public REST output: the site administrator must verify them in WordPress. Without those mappings, reader falls back to the post permalink, a missing cover remains missing, and no PDF URL is invented.
- A USA public magazine record had a `jul-aug-2026` slug but a `MAY - JUN 2026` title. Correct source data in WordPress; the app should not silently guess which is authoritative.
- Optional volume/issue-number metadata can also be mapped. Missing values display `-`, rather than incorrectly labelling USA issues with Europe's old hard-coded volume 18.
- Events default to `tribe_events` and `_EventStartDate`, with the venue from The Events Calendar when available. If USA's intended events instead use `upcoming_event`, select it and map date/location keys.
- Before plugin activation, ordinary news remains available from each site's public REST API. Europe retains its existing archive adapter and starter banners; USA never reuses Europe banners/categories/magazines. USA magazines may be unavailable until its plugin mapping is configured.

## Notifications

The app uses distinct FCM topics `wood_panel_europe` and `wood_panel_usa`. Users opt in with the bell or Preferences. Topic changes are serialized and unsubscribe the previous edition. A closed app remains subscribed to its last successfully registered topic until it next runs. Topic delivery is not a private access-control mechanism.

Add the real Android `google-services.json` to `android/app/` (the Gradle plugin activates only when this file exists). For iOS, add the matching `GoogleService-Info.plist` to the Runner target and Copy Bundle Resources in Xcode. Native configuration is required for reliable notification handling when the application process is not running. Then build with the matching Firebase public app configuration using `--dart-define-from-file=<local-config.json>`:

```json
{
  "FIREBASE_APP_ID": "your-platform-specific-app-id",
  "FIREBASE_API_KEY": "your-public-firebase-api-key",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_SENDER_ID": "your-messaging-sender-id",
  "FIREBASE_IOS_BUNDLE_ID": "your-ios-bundle-id"
}
```

Use a different platform app ID for iOS. The current package IDs are Android `com.example.wood_panel_app`, iOS `com.example.woodPanelApp`; finalize production identifiers before store publication. Never include service-account private keys in Flutter assets or defines. Without these Firebase values the UI reports notifications as not configured.

On EACH WordPress server, put a Firebase service-account JSON file outside the public web root, restrict its filesystem permissions, and define its absolute path in `wp-config.php`:

```php
define('WPAM_FIREBASE_SERVICE_ACCOUNT_FILE', '/private/path/firebase-service-account.json');
```

Enable the Firebase Cloud Messaging API and grant the service account the required messaging role. The plugin's Notifications page sends a chosen public article only to that site's topic. No push was sent during implementation. Payload data contains string fields `edition` and `article_id`. Tapping it selects that edition for the session and opens the article. In-app messages from another edition are filtered out.

Firebase setup reference: https://firebase.google.com/docs/cloud-messaging/flutter/get-started

## Verified links and iOS

Android intent filters and iOS associated-domain entitlements cover both canonical and bare site domains. HTTPS article URLs resolve via the selected site's REST API; `?p=ID` is supported. Unknown hosts are rejected.

- Publish `/.well-known/assetlinks.json` on all claimed Android hosts with the actual application ID and release signing certificate SHA-256. Until verified, Android may open a browser instead. ADB explicit-intent testing does not prove domain verification.
- Publish the Apple association file with the real Team ID and bundle ID. Enable Associated Domains and Push Notifications on the app identifier/provisioning profile. Upload the APNs key to Firebase. Entitlements use development APNs for Debug and production for Release/Profile.
- Build and test on a Mac and physical iPhone. No iOS build/device verification was possible from this Windows workstation.

App-links reference: https://pub.dev/packages/app_links

## State and data behavior

- Fresh process: Europe. Background/resume in the same process: retain selection. Active edition is never written to storage.
- Explicit USA notification/link: selects USA for that session, including a cold start.
- Configuration/content cache namespaces include the edition. Simultaneous identical API reads share a request. Stale repositories do not emit UI refreshes after switching.
- Existing bookmarks migrate once into Europe. Identical USA post IDs remain separate. Downloads keep edition identity and display it; existing files are retained.
- Saved wallpaper IDs from configured catalogues include the edition. Shared YouTube cache and existing user preferences remain shared.

## Release checks still required

After staging installation, test plugin saving, both form records in the correct databases, disabled forms, category/section reorder, configured palette changes, banners, USA magazine metadata, Europe PDF availability, events, About/Contact pages and wallpapers. Test slow/offline switching and deleted content. Then test FCM delivery and notification taps in foreground/background/terminated states, verified links, Android permissions and iOS lifecycle behavior. Do not describe these deployment-dependent checks as already passed.

## Local verification results

- Dart analysis of `lib` and `test`: no issues.
- Flutter tests: 15 passed, including edition initialization, trusted hosts, schema validation, category ordering, legacy bookmark migration, cache separation, BOM JSON, concurrent request coalescing, preloader configuration, background refresh coalescing, both interview archive formats, download identity, wallpaper persistence and app startup.
- All five plugin PHP source files pass syntax checks. Standalone archive adapter tests pass eight checks. These are not a substitute for WordPress staging/database tests.
- Android debug APK build succeeds. Build tooling warns about future Kotlin Gradle plugin compatibility; no framework/toolchain upgrade was attempted.
- Connected Android phone: installed an updated build, checked the edition menu and USA news, background/resume retaining USA, and force-stop/relaunch selecting Europe. Screenshots are included under `artifacts/dual-edition`.
- Device testing found and prompted a fix for Future-returning `setState` callbacks during content refresh. After reconnecting on 24 October 2026, the final packaged APK was installed successfully on device `c2a40481`. Visual checks confirmed Europe startup, USA news/logo/theme, USA retained after background/resume, and Europe restored after force-stop/relaunch. Recent Flutter/AndroidRuntime error logs were empty. The `final-*.png` screenshots record these checks; live Firebase and plugin-dependent features still require deployment verification.
- Verified-domain routing, live push and iOS remain untested. The attempted ADB deep-link launch was blocked by the tool environment; no successful device link-routing test is claimed.

Regenerate the plugin ZIP, debug APK copy and SHA-256 manifest after a successful build with `powershell -File tool/package_dual_edition.ps1`. The plugin ZIP uses forward-slash paths for Linux WordPress hosts. Debug APKs are for testing, not Play Store release.

### Settings fallback (plugin 0.4.1)
If the main App Settings route redirects on the host, use WordPress Settings > Wood & Panel App, or /wp-admin/options-general.php?page=wpam-configuration. This uses the same settings and permissions; no data migration is needed. Opening and saving this route was verified in local WordPress. The live redirect cause is not confirmed. A create_function() fatal in smart-404/smart404.php:57 belongs to Smart 404 after the redirect; this update does not patch that third-party plugin.


### Regional content repair (plugin 0.4.2)
USA magazines use the published /archive/?mag_year=YYYY cards when cover/reader mappings are blank. This recovers actual lazy-loaded cover images, reader links, issue dates and topics. No PDF URL is fabricated. If the configured events source is empty/unavailable, events fall back to the same site's homepage cards, preserving published dates (including past dates). The current site homepages each publish four past events. Install the plugin update on both sites, then refresh the app. The app header now lists the selected edition first without a tick, and loader rings use the configured edition colours.
USA legacy interviews remain blocked by the live theme's deprecated Pod API at template-interview-details.php:296. The theme source around that line is needed before modifying the data lookup. This release does not claim to repair that website fatal error.


### App usability update — 28 October 2026
Centered edition menu with consistent logo boxes; selecting an edition clears that edition's content cache and fetches updated configuration before showing its home content. Newsletter success replaces the form. Partner and Contact are native branded pages; Contact uses the same built-in addresses/team data for both editions, does not fetch a Contact page ID, and includes subject and optional phone (stored with the submitted message).
Magazine download buttons verify the publisher's offline/download.pdf export when the API leaves pdfUrl empty. Nine current 2026 exports returned application/pdf in live checks. Downloads validate the PDF signature before saving. Reader navigation blocks app-store/deep-link redirects and offers retry/PDF recovery on main-frame errors. This app update does not require a new WordPress plugin version.

### Edition refresh and magazine numbers — 28 October 2026
Edition changes now open Feed. Home, Explore, Feed and Magazine discard page-local futures/lists when the edition or its loaded configuration changes; inactive repositories cannot repopulate cleared caches. Downloaded PDF screens retain bottom navigation.
Plugin 0.4.3 adds Website content sources > Magazine volume and issue numbers. Enter each magazine's exact Read Online URL, printed Volume and Issue number, then save. Overrides apply to both post-based and archive-based magazines, including cached archive results. No volume or issue numbers are inferred from publication dates. Install this ZIP on both sites to use the new fields, then refresh/switch the app. Existing metadata-key mappings remain supported.
In This Issue carousel and additional wallpapers are proposals only and have not been implemented in this update.
Validation: 37 Flutter tests passed, Flutter analyzer clean, PHP lint and magazine-number URL matching test passed.

### Magazine highlights and wallpapers (plugin 0.4.4)
This replaces the 0.4.3 manual magazine-number fields. Both editions use 2026 = Volume 18 (year minus 2008), and Jan-Feb = Issue 1 through Nov-Dec = Issue 6. The app also calculates these values when reading an older API response or cached issue.
Settings > In This Issue: add the exact Read Online URL for each magazine, with one highlight per line. Add another creates another magazine entry. Empty entries produce no section in the magazine detail page.
Settings > Wallpapers: upload/select an image, enter title and category, and save. Use Show bundled wood wallpapers to enable/disable the three included wallpapers independently per site. Custom uploads remain visible when defaults are disabled. Defaults work offline and support gallery download and sharing. Install the updated plugin on both sites for the new controls; the APK alone provides automatic numbering and default wallpapers.


## Profiles and social links (plugin 0.5.0)

Install the updated plugin ZIP on both websites. Activation or the first request adds the private profile-photo column without replacing existing settings.

- App Settings > Social media: each site can independently edit the six default links. Empty links hide their icons in Contact, Profile and the drawer.
- Wood & Panel App > Profiles: submitted name, email and optional resized photo. This is a reader profile, not a login account. Photos are stored privately in the submissions table, not in public media.
- Submissions and Profiles: select rows to delete or export CSV. Export with no selection includes all records of the current type. Delete requires a selection, confirmation, administrator capability and nonce. CSV includes text details and whether a photo was supplied; no private tokens or photo data.
- The welcome form appears once after splash. Skip is remembered and displays User. Edit Profile allows later changes. Local details are saved after server success and shared between editions on the phone. Saving submits to the currently selected website; switching does not silently send personal details to the other website.
- Repeated edits update the same website record using a private installation token. Avatars are resized and re-encoded to strip metadata. Public profile retrieval is not provided.
- Profile statistics use real local bookmarks/downloads and unique articles opened since this update. Rate Our App remains a placeholder until the Play Store URL is supplied.

Validation: profile persistence, failed-save preservation, Skip and both-edition layouts at 320/390 logical pixels; Contact form regression tests; PHP syntax and isolated profile-input/CSV validation. Connected Android phone inspected. iOS runtime and live admin CSV/delete operations still need deployment verification. No live test submissions were created or deleted.


## Compact profile/menu follow-up

The menu now has 13 larger rows: Newsletter and Subscribe rows were removed because the newsletter banner remains available. Its header is shorter and the social footer has a plain background. Profile uses a shorter hero card and a plain Follow Us panel. Photo picking and camera controls were removed at the user's request; all profile views show a person icon and the editor accepts name/email only. The existing server photo column is retained for compatibility, but this app no longer uploads photos.

First-launch behavior is unchanged: splash precedes the one-time welcome form, and Save/Skip marks that form as seen. Replaying it for device review resets only profile_prompt_seen_v1; no saved profile or content is cleared.


## Shared Google Play link
Install plugin 0.5.2 on both sites. In App Settings > App store link, save the Google Play app URL on either site. Both app editions use this URL for Rate Our App and Share App. Europe takes priority if both sites specify different URLs. No database synchronization or cross-site credentials are required; the app reads both public edition configurations, with their existing offline-cache fallback. Leave the field blank until the listing is available. Restart the app after changing the setting to fetch both configurations again.

## Platform-specific store links
Plugin 0.5.3 adds iOS App Store URL under App store links. Both fields can be configured on either site. Europe takes priority per platform; iOS uses only the Apple URL, while Android uses only the Google Play URL. A missing iOS link never opens the Android listing. Rate and Share use the current device platform. Restart the app after saving to refresh both site configurations. iOS physical-device verification requires an iOS build/device.


### Image notifications and scheduling - 30 October 2026
See [notification-deployment.md](notification-deployment.md) for plugin 0.6.0, Android verification and the explicitly deferred Mac/iPhone notification-extension checklist.

### Startup branding update — 30 October 2026
Android now uses a dedicated transparent splash logo and an adaptive launcher icon with green/brown backing, avoiding the white legacy-icon surround. The Flutter opening splash adds scalable wood-grain corner ribbons on black and retains the animated brand loader. Android's system splash remains logo-only; corners appear after Flutter starts. Cold-launch screenshots on c2a40481 confirmed the borderless native logo and corner decoration. Flutter analysis and Android build passed. No onboarding or profile data was reset.

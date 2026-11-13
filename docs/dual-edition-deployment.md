# Dual-edition deployment

Current guide reviewed against repository source on 4 November 2026. App version: `0.1.0+1`; App Manager plugin: `0.9.1`. This guide describes the current implementation, replacing earlier phase-by-phase deployment notes. Android has been built and tested on the connected phone; this document update does not deploy to either website.

## Architecture and backup

Europe (`https://www.woodandpanel.com`) and USA (`https://www.woodandpanel.us`) have independent WordPress plugin installations, configuration and submission/report tables. The old `backend/` scaffold remains for reference and is not required for current app management. Videos use the shared YouTube channel.

Pre-dual-edition backup recorded on 24 October 2026:
`D:\sourav samanta\Wood & Panel\Backups\Wood-Panel-Before-Dual-Edition-2026-10-24-160553.zip`

Recorded SHA-256: `E36EC27B026EA23AE2131E492772F4EF1576CBF73A00FEB46F230E33D80990EB`.
Restore into a separate directory and verify the archive before using it; do not overwrite newer work. Back up each site's database and plugin before upgrading.

## Install and configure WordPress

1. Build the normal Android target and run `tool/package_dual_edition.ps1` as described in the README. The ZIP is `artifacts/dual-edition/wood-panel-app-manager.zip`.
2. Upload/replace and activate the plugin on **both** sites. Requirements declared by the plugin: WordPress 6.0+, PHP 8.0+. Enable DOM for archive parsing and OpenSSL for Firebase sending.
3. Open **Wood & Panel App**. Its internal sidebar contains settings, banner management/reports, notifications and Submissions with Newsletter, Contact and Profile submenus. Normal settings route: `/wp-admin/admin.php?page=wood-panel-app-settings`.
4. Check the edition, branding approval, logo, primary/secondary colours and loader settings. USA uses red/navy; Europe uses copper/green. Remote loader settings apply after configuration loads, not to the native OS launch screen.
5. Search/select/order categories; Home and Explore share the selected list. Select and order Home sections. Optional featured published news IDs control Trending. Interviews are automatically sourced, not selected through an interview-category setting.
6. Configure content sources, About Us page ID, contact fields, social links, legal documents and form availability. Contact details are plugin fields, not the content of a Contact page ID.
7. Use the public configuration/content check links and verify the selected edition and real data. APIs are under `/wp-json/wood-panel-app/v1/`.
8. Refresh or switch edition in the app to obtain saved configuration. Server/CDN caches may delay changes; the public config advertises a two-minute cache period.

Settings changes require `manage_options` and WordPress nonces. Keep credentials outside source control and ZIPs. No live-site writes are part of the isolated test scripts.

## Content sources

- News comes from the selected website. Interviews combine current post-based interviews with legacy regional archive/Pods content; verify both generations on each site.
- Magazine/event adapters and optional source metadata mappings live in `includes/rest.php`. Check the actual site's configured post type/metadata and homepage/archive markup when covers, reader URLs or events are missing; do not invent metadata keys or PDF URLs.
- Magazines calculate Volume as year minus 2008 (2026 = 18), and Issue as the two-month period (Jan-Feb = 1 through Nov-Dec = 6). The archive counts actual returned issues; a partially published year need not contain six records.
- Verify reader and PDF destinations individually. A downloadable PDF must resolve successfully before Download can become View PDF. Downloaded files are local, support sharing/deletion, and retain reading position/page bookmarks through the PDF reader.
- **In This Issue** uses a magazine Read Online URL and one highlight per line (up to 30). Empty entries are hidden. This is distinct from Recent Issues.
- About Us uses the published page ID from the selected site's settings. The user confirmed Europe's page ID has been configured; this guide does not re-audit live content.
- Wallpapers include bundled defaults and plugin-uploaded custom entries, with a switch to disable defaults. Users preview/save/share/download; setting a downloaded image as the phone wallpaper is done through the phone.

## Banners and reports

Manage advertisements under All Banners/Add Banner/Banner Reports. Set title, placement, image, optional HTTPS destination, accessible description, display order, active status and optional start/end dates. Publish the record to show it. Dates use the site's timezone; end dates are inclusive. Draft, inactive, future and expired records are excluded.

- Home promotional carousel: recommended artwork 1000 x 500 px (approximately 2:1); check current rendering before producing a campaign.
- Inline: 350 x 350 px (320 x 320 also supported), square. One banner follows each three news/interview/video/Feed items; ordered banners repeat after the last.
- Footer: select 350 x 50 or 350 x 100 per banner. The app preserves the ratio, supports minimize/close, and advances on navigation/refresh. The control strip displays minimize and close icons. Feed must fit above the visible footer.
- Image prefetch and disk/decoded caching reduce loading delays; a first-ever download still depends on connectivity.

Legacy banner arrays migrate once to records, with the original arrays retained in `wpam_banner_legacy_backup`. Reports include impressions, clicks, CTR, date ranges and CSV export; optional report email depends on site mail configuration. CTR is clicks / impressions x 100, or zero when impressions are zero.

A downloaded banner counts after at least 50% visibility for one continuous second on an active route, or an earlier tap. Failed/off-screen/minimized images do not count. These are exposure metrics, not unique visitors. Events use signed placement tokens and deduplication receipts, but public events can be spoofed and offline events missed. Verify live rotation and report increments separately on each site.

## Forms, profile and first launch

Newsletter/contact requests are stored in the selected site's `wpam_submissions` table. Newsletter registration stores details; it does not send a campaign. Contact stores name, email, country, subject and message. Profile submissions store name/email and a hashed installation token; the app's chosen bundled avatar stays local. Legacy photo storage remains for compatibility; the current editor does not upload an image.

Submissions supports CSV export (selected rows, or all of the selected kind if none selected) and bulk deletion of selected records. Profile updates use the installation token rather than a user login. An avatar-only change is saved locally without another profile submission.

First launch: native/Flutter splash -> optional welcome profile form (Save or Skip) -> onboarding slides -> Feed. Subsequent launches skip completed steps. Editing Profile later does not replay onboarding. The compact editor keeps Save visible on the tested phone at its normal text size; scrolling remains available for the keyboard/accessibility.

## Preferences and optional pages

Appearance, global text size, narration speed/voice and independent Europe/USA push preferences persist locally. Text size respects phone accessibility scaling. Narration uses the device TTS engine; voices may require a device download. No paid narration API is configured. Language translation is deferred.

Privacy Policy and Terms & Conditions are editable per edition in the plugin. Review the published wording against actual data handling. Contact fields and social links are also edition-specific.

Group Media and Clients have enable switches and image/name/optional-link entries; Media also has descriptions. Inactive or empty directories are hidden in Profile. Premium Subscribe is optional and currently routes Subscribe Now to a contact enquiry. Payments and entitlement enforcement are deferred.

Store links have separate Android and iOS fields. They may be entered on either site; Europe takes priority per platform if both supply different values. Rate/Share use the device platform's link, with no Android fallback for a missing iOS URL.

## Edition state and caching

A new process starts with Europe; background/resume retains the session edition. Switching editions requests fresh regional configuration/content and navigates to Feed. Explicit notification/website article links select the article's edition. Notification subscriptions are independent of browsing.

News/interview/magazine/event cache records use SQLite (`content_cache.db`) on Android/iOS with edition-isolated keys. Existing SharedPreferences content cache entries migrate transactionally. Settings, bookmarks, profiles, notification read state, PDFs and PDF progress retain their own persistence. Stale content can display while refreshing; only previously fetched data is available offline. Images and shared YouTube data have separate caches. This is not full offline search.

## Firebase, Analytics and Crashlytics

See [notification-deployment.md](notification-deployment.md) for server credentials, image payloads, schedules and the iOS extension checklist.

Android reads `android/app/google-services.json`; iOS requires its matching `GoogleService-Info.plist` in Runner. With native configuration, ordinary builds need no Firebase Dart defines. Optional explicit overrides are `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, and `FIREBASE_IOS_BUNDLE_ID`.

Analytics records screen names and edition; it does not intentionally record form contents or email. Crashlytics captures framework/platform errors with screen/edition context. Android Firebase dashboard receipt was confirmed by screenshots on 2 November 2026: a controlled test crash plus `screen_view` and `notification_receive` events. This is not iOS verification.

For Android DebugView:
```sh
adb shell setprop debug.firebase.analytics.app com.woodandpanel.app
```
Disable after checking:
```sh
adb shell setprop debug.firebase.analytics.app .none.
```
A debug-only build with `--dart-define=FIREBASE_TEST_CRASH=true` triggers a controlled crash after 15 seconds once per saved test flag. Reopen to upload; restore a normal build afterward. Never distribute that test build. Review privacy text and store data disclosures for analytics/crash diagnostics before publication.

## Maintenance and updates

Controls default off and are configured per edition. Maintenance shows its custom message, Retry and the other-edition option. Checks run at startup, switching, resume and Retry. Failed configuration fetches do not enforce cached blocks, avoiding offline lockout. This is a client UI gate, not server access control.

Android/iOS have separate minimum/latest integer build values. For `1.2.0+12`, enter `12`, not `1.2.0`. Below minimum requires Update; below latest offers Update/Later. Configure both sites for app-wide enforcement. A valid platform store URL on the same site is required before enabling update controls. Publish the working store build before increasing the minimum.

## Release and verified links

The approved Android application ID and namespace are `com.woodandpanel.app`, with version `1.0.0+5`. The visible app name is unchanged. iOS remains `com.example.woodPanelApp` pending its separate Mac release setup. Android release builds use a dedicated release signing configuration and fail if `android/key.properties` is missing; they no longer fall back to the debug key. A dedicated upload keystore was provisioned on 11 November 2026 at android/upload-keystore/wood-panel-upload.jks. Back it up securely together with android/key.properties. The ignored key.properties requires storeFile (relative to android/ or absolute), storePassword, keyAlias and keyPassword. Never commit credentials or keystores.

Release verification (11 November 2026): signed AAB and APK built successfully; signatures and APK package/version verified; APK installed on the connected Android phone and opened its welcome form. This is a launch smoke test only. New-registration push/Analytics/Crashlytics receipt and Play internal testing remain to be confirmed. Native debug symbols and R8 mapping are embedded in the AAB.

### Firebase migration for the final Android ID

In the existing Firebase project `wood-and-panel-ecc55`, add another Android application with package `com.woodandpanel.app`. Download its generated `google-services.json` to `android/app/google-services.json`; do not edit the package name inside the old JSON. The replacement configuration was verified on 11 November 2026 and includes the new Android client. Keep the old Firebase registration while testing. No replacement server service-account key or WordPress topic configuration is needed when staying in this Firebase project. Recheck both edition notifications, Analytics and Crashlytics on the new installed application.

The new package installs separately from the old test app. Existing local preferences, avatars, downloaded PDFs, bookmarks and notification permissions do not automatically migrate. Keep the old installation until the new one is verified. Firebase configuration replacement and upload-key provisioning are complete. Signed release artifacts are generated under artifacts/android-release-1.0.0/ (ignored by Git); see its READ-ME.txt for handoff and verification limits. The new Play listing URLs must only replace temporary plugin store links when the listings are available.

Publish `/.well-known/assetlinks.json` on every claimed Android host using the final application ID and actual signing certificate fingerprints, including Play App Signing where applicable. Publish `/.well-known/apple-app-site-association` using the Apple Team ID and final bundle ID. Confirm valid public responses and test real shared article links. Explicit ADB intents and working notification taps do not prove website association verification. This release step remains pending confirmation.

On Mac: add iOS Firebase configuration, configure Runner and ImageNotification signing/capabilities, APNs authentication and associated domains; run package resolution and an Xcode archive. Configure Crashlytics symbol upload. Test on physical iPhone and TestFlight, including images, text fallback, edition/article navigation, SQLite, PDFs and normal lifecycle. Windows builds cannot verify Swift compilation, Apple signing or iOS runtime behavior.

## Validation and handoff

Run `flutter analyze` and `flutter test` for app changes. Isolated PHP checks are listed in the README; integration checks need their dedicated local WordPress/database fixture. `submissions-test.php` now loads `profiles.php` and tests all three kinds, pagination, profile routing and unauthorized access. `tool/test_profiles.php` checks profile validation/CSV handling plus newsletter/contact validation, disabled forms and storage errors using stubs.

Before release, verify real per-site submissions and exports, banner metrics/rotation, current/legacy content, scheduled push cancellation/delivery, store URLs and signing. Keep iOS marked pending until tested on Mac/iPhone. Tests/documentation maintenance does not require reinstalling the app or uploading a new plugin.

# Wood & Panel App

Flutter news and magazine app with Europe and USA editions. Each website runs its own **Wood & Panel App Manager** WordPress plugin and stores its own configuration and submissions. The original `backend/` PHP scaffold is retained for reference; it is not the current app administration service.

## Current implementation

- Europe is the default edition on a fresh process. Switching editions refreshes regional data and opens Feed; explicit article links and notification taps select the source edition.
- Live news, post-based and legacy interviews, magazines, PDFs and events; one shared YouTube channel.
- SQLite content cache on Android/iOS, separate image caching, local bookmarks and downloaded PDFs with saved page position/page bookmarks, sharing and deletion.
- Home, inline and footer advertisements with rotation, scheduling and per-site impression/click reports.
- Independent Europe/USA push preferences, persistent notification inboxes, image notifications and scheduled sending from WordPress.
- Name/email profile submissions with locally selected bundled avatars; first-launch welcome form and onboarding.
- Appearance, text size, device narration controls, plugin-managed legal/contact/social content, optional Group Media/Clients/Premium pages and maintenance/update controls.
- Firebase Analytics and Crashlytics integrated. Android dashboard receipt was confirmed; iOS build and device verification remain pending on Mac/iPhone.

Premium Subscribe currently opens a contact enquiry. Payments and premium access enforcement are not implemented. Language translation remains deferred.

## Local setup

Use a Flutter SDK compatible with `pubspec.lock`, Android SDK and JDK 17. Check `flutter doctor` before building. PHP 8.0+ is required for isolated plugin checks. The plugin declares WordPress 6.0+; its archive adapters require PHP DOM and its notification sender requires OpenSSL.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --target lib/main.dart
```

For Android Firebase features, place the matching `google-services.json` in `android/app/`. The Google Services and Crashlytics Gradle plugins activate when that file exists. Mobile Firebase initialization reads native configuration; Dart defines are optional overrides, not required for an ordinary configured Android build. Never put a Firebase service-account private key in the app, repository or plugin ZIP.

On this Windows workstation, `C:\wood_panel_app` is a junction to the project and avoids spaces in build-tool paths. It is a local convenience, not a required install location.

## Build and package

```sh
flutter build apk --debug --target lib/main.dart
```

Then, in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/package_dual_edition.ps1
```

The packaging script copies the existing debug APK, creates the WordPress plugin ZIP, copies the deployment guide and writes checksums under `artifacts/dual-edition/`. It does not build the app. Always build the normal `lib/main.dart` target first; never package a temporary preview or forced-crash build.

The current Android release configuration still uses debug signing, and application identifiers are examples. A debug APK or an unreviewed release build is not a store-ready release.

## Project map

- `lib/app`, `lib/routing`, `lib/core`: app bootstrap, navigation, edition/configuration, notifications and telemetry.
- `lib/data`: models, repositories and local persistence.
- `lib/features`, `lib/widgets`: screens and shared UI.
- `wordpress/wood-panel-app-manager`: production WordPress plugin source (currently 0.9.1).
- `wordpress/tests`, `tool/test_profiles.php`: plugin regression checks.
- `test/`: Flutter unit/widget tests.
- `docs/dual-edition-deployment.md`: current installation, configuration and release checklist.
- `docs/notification-deployment.md`: push delivery, scheduling, inbox and iOS handoff.
- `backend/`: legacy scaffold; no setup required for the current WordPress-backed app.

## Submission checks

These checks use local stubs and do not create/delete live submissions:

```sh
php wordpress/tests/submissions-test.php
php tool/test_profiles.php
php wordpress/tests/settings-test.php
php wordpress/tests/notifications-test.php
php wordpress/tests/admin-menu-test.php
```

The submissions renderer lives in `includes/profiles.php`; form REST handlers live in `includes/rest.php`. Integration files such as `banner-integration-test.php` and `inbox-integration-test.php` require the isolated WordPress fixture under `artifacts/wp-test/wordpress` and database `wpam_banner_test` on `127.0.0.1:3317`. Do not run those against a production database.

## Remaining release verification

Finalize store identifiers/signing and Android/iOS association files; configure store URLs; review published legal text and store data declarations; archive and test iOS on a Mac and physical iPhone, including notification extension and Crashlytics symbols. Live configuration, scheduled pushes, submissions/exports and advertisements should be verified per edition before release. See the deployment guides for exact boundaries.

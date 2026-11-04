# Notifications deployment and verification

Reviewed against the current implementation on 4 November 2026. See [dual-edition deployment](dual-edition-deployment.md) for the complete installation and release checklist.

## Configuration

Install App Manager on both websites. Each site sends to its own topic: `wood_panel_europe` or `wood_panel_usa`. Both use the same Firebase project as the app.

Set `WPAM_FIREBASE_SERVICE_ACCOUNT_FILE` in each server's `wp-config.php` to the absolute path of its service-account JSON. Keep that file outside the public web directory and readable by PHP. Never bundle it in the app, plugin ZIP or Git repository. Android uses its matching `android/app/google-services.json`; this client configuration is different from the server private key.

The app's Preferences has independent Europe and USA switches. Browsing or switching editions does not disable the other edition's subscription. Both switches can be enabled. Device notification permission is also required. These controls are separate from the header bell, which opens notification history.

## Sending and scheduling

Open the plugin's Notifications page. Search a published news title and select a result with its publication date/time, or enter the published article ID. Choose Send now or Schedule. Times use that site's WordPress timezone.

Recent jobs show scheduled, sending, accepted, failed or cancelled status. **Accepted means Firebase accepted the request, not confirmed device delivery.** Pending schedules can be cancelled. Execution rechecks the article's publication/password status, edition and the scheduling administrator's permissions.

Atomic job locks and request IDs protect against duplicate submissions/workers. Failed or interrupted sends are not automatically retried: a network failure can occur after Firebase has accepted a message.

Scheduling uses WP-Cron. Configure hosting cron to invoke WordPress Cron every minute for each site if reliable near-minute execution is needed. Keep the plugin active. Cron and push delivery do not guarantee exact timing. Verify a scheduled send and cancellation on each live site before relying on scheduling.

## Images and fallback

The sender includes an eligible featured image: HTTPS JPEG/PNG, preferably a medium rendition, no more than 1024 pixels on the longest edge and 1 MB. A small original can be used when a rendition is unavailable. Missing or unsuitable images produce text-only notifications; download failures must preserve the title/body.

Images and the inbox do not require a different Firebase project, server key or topic setup. iOS additionally requires the extension and Apple configuration below.

## Inbox and read state

- The header bell opens the current edition's inbox with All/Unread filters, category, timestamp, image and article preview.
- `/wp-json/wood-panel-app/v1/notifications?page=1` returns accepted jobs about currently public articles, with 100 jobs per page and pagination metadata. Failed, cancelled and scheduled jobs, private articles and password-protected articles are excluded.
- History begins with jobs recorded by the scheduling-enabled plugin; earlier unrecorded sends cannot be reconstructed.
- Cached history and read IDs persist separately per edition on the device. Read state is not synchronized across phones.
- Clearing a system notification does not mark it read in the app. Tapping a push carrying `notification_id` marks that item read and opens its article in the source edition.
- History refreshes on relevant app/inbox lifecycle events and periodic foreground polling. Inbox visibility is independent of whether OS push permission is granted.

## Android verification

Android image delivery, text-only delivery, edition routing and populated Europe/USA inboxes were checked during development. Both-edition topic subscriptions were also checked. This is historical verification, not a claim that every subsequent deployment has been tested.

After a release/configuration change:

1. Enable both edition switches and allow Android notifications.
2. Test one Europe and one USA message while browsing either edition, including background delivery.
3. Expand the notification to inspect the image; test a news item without an eligible image too.
4. Tap a notification and confirm the correct article/edition opens and its unread count changes.
5. Dismiss another system notification, reopen the app and verify it remains unread in the source inbox.
6. Disable only one edition and verify that preference does not disable the other.
7. Verify scheduled delivery and cancellation separately on each website.

`tool/test_notification_device.py` supports an explicit single-device smoke test using a private credentials path, adb and PHP. It targets the device token, not a subscriber topic, and does not print private keys or tokens. Use isolated PHP tests for payload, fallback, timezone, authorization, duplicate-worker and failure cases before live testing.

## iOS handoff: pending Mac and iPhone testing

The user requested Android testing on Windows first. **iOS notifications are not yet device-verified.**

- `ios/ImageNotification/NotificationService.swift` and its Info.plist are included in the ImageNotification target with a Runner dependency and Embed App Extensions phase. The extension uses Foundation/UserNotifications; it does not need its own Firebase SDK dependency.
- The sender includes APNs mutable-content, `fcm_options.image` and custom `image_url`. The extension attaches the downloaded image and returns the original title/body on failure or expiry.
- Register the final iOS bundle ID in the same Firebase project. Add the matching `GoogleService-Info.plist` to Runner and Copy Bundle Resources.
- Configure the APNs authentication key in Firebase, Push Notifications capability and signing/provisioning. Runner and ImageNotification must use the same development team. The extension identifier must match the final Runner identifier plus `.ImageNotification`.
- On Mac, resolve Flutter packages and build/archive in Xcode. Check extension embedding and matching versions/build numbers. Windows structural checks do not compile Swift or validate Apple signing.
- Test image/text delivery, failed-image fallback, foreground/background/terminated states, independent edition preferences and article routing on an iPhone. Verify production APNs through TestFlight before release.

## Troubleshooting

If Firebase accepts a send but the phone receives nothing, check the app's source-edition preference, OS permission, topic subscription and matching Firebase project. Check foreground handling separately from background system notifications. A visible inbox item proves accepted history was fetched; it does not prove OS delivery.

If the REST history route is missing, check the deployed plugin version and activation on that site. If scheduling is late, inspect WP-Cron/hosting cron and the site's timezone. Do not repeatedly broadcast test messages to diagnose a single phone.

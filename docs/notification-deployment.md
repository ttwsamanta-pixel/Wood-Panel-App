# News image notifications and scheduling — 30 October 2026

Plugin version 0.6.0 adds:
- Notifications → search a published news headline, select a result showing publication date/time, or enter its post ID manually.
- Send now or schedule in the site's WordPress timezone. Recent jobs show scheduled, sending, accepted, failed or cancelled status. Accepted means FCM accepted the request, not confirmed device delivery.
- Cancel pending schedules. The sender rechecks publication status, password protection, edition and the scheduling administrator's permissions at execution time.
- Atomic job locks and request IDs prevent duplicate submissions/workers. Failed or interrupted sends are deliberately not automatically retried, because a network failure can occur after Firebase accepted a message.
- Featured image notifications: HTTPS JPEG/PNG, preferably a generated medium rendition, at most 1024 pixels on the longest edge and 1 MB. Small originals are allowed if no rendition is available. Missing or unsuitable images produce text-only notifications. Android handles remote image download failure with its text notification.

Upload the updated `artifacts/dual-edition/wood-panel-app-manager.zip` on BOTH websites. No change to the existing Android Firebase project, google-services.json, service-account key, or edition topics is needed. No private credentials belong inside the app or ZIP.

Scheduling uses WP-Cron, which runs due jobs when WordPress is visited. For near-minute timing, configure the host's cron to invoke WordPress Cron every minute for each website (use the correct application path or hosting panel). Keep this plugin active while jobs are pending. Cron and push delivery are not exact-time guarantees. After deployment, verify one scheduled article on each edition and verify cancellation; live website scheduling has not been tested from this Windows workspace.

## iOS handoff — deferred until Mac and physical iPhone are available

User requested Android testing now and iOS testing later when building on a Mac. **Do not mark iOS notifications or the extension as device-tested.**

- `ios/ImageNotification/NotificationService.swift` and its Info.plist are included as an ImageNotification target in Runner.xcodeproj, with a Runner dependency and Embed App Extensions phase. The native extension uses Foundation/UserNotifications, so there is no extra Firebase SDK dependency for this target.
- The sender includes APNs mutable-content, fcm_options.image, and custom image_url. The extension downloads the image, attaches it, and completes with the original title/body on failure or expiry.
- Register the final iOS bundle ID in the same Firebase project. Add the matching GoogleService-Info.plist to Runner and Copy Bundle Resources; this file is not currently supplied.
- Configure the APNs authentication key in Firebase Cloud Messaging, Apple Push Notifications capability, and correct signing/provisioning. Use the same development team for Runner and ImageNotification. The extension's identifier must be the Runner identifier plus `.ImageNotification`; update both if replacing the current example identifiers.
- On Mac run Flutter package resolution and archive in Xcode. Confirm the extension is embedded and its build number/version match Runner. Windows checks only validate the project structure/plist; they do not compile Swift or validate Apple signing.
- Test on a physical iPhone: background and terminated-state image delivery, text-only delivery, missing/slow image fallback, tapping opens the correct article/edition, and production APNs via TestFlight before App Store submission.

## Verification

- Isolated PHP notification checks cover payload, fallback, timezone, authorization, cancellation state, future jobs, duplicate workers and failed delivery; no real recipients are used in these tests.
- Android single-device image delivery verified on the connected phone, including visible expanded featured image. Test sends target only that device token, not edition subscriber topics. The existing installed Android build already supports this system notification image format.
- `tool/test_notification_device.py` is an explicit single-device smoke-test utility; supply a private credentials path, adb path and PHP path. It never prints tokens/private keys and never sends to a topic.
- USA text-only notification also received on Android; tapping opened its USA article.
- iOS project/embedding/plist structure checked; Mac build, signing and iPhone testing remain pending.

References: [Firebase image payloads](https://firebase.google.com/docs/cloud-messaging/customize-messages/cross-platform), [Apple notification service extensions](https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications), [WordPress scheduling](https://developer.wordpress.org/reference/functions/wp_schedule_single_event/).

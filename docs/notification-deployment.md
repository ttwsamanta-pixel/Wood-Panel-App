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

### Notification inbox update (plugin 0.7.0)

- Install the updated plugin ZIP on **both** websites before installing the updated app. No Firebase console changes are needed for the inbox.
- The header bell and Profile Notifications entry now open the edition's inbox. Notification permission/subscription controls stay in Preferences.
- `/wp-json/wood-panel-app/v1/notifications?page=1` exposes accepted notification jobs about currently public news only. It returns 100 jobs per page and a page count. Failed, cancelled and scheduled jobs are excluded; private or password-protected articles are excluded even after a send.
- History includes accepted jobs already recorded by the scheduling-enabled plugin. Older sends made before job history existed cannot be reconstructed.
- Read IDs and cached history persist on the device separately for Europe and USA. Dismissing an Android/iOS system notification does not mark an inbox item read. New push payloads include `notification_id`; tapping them marks that item read and still opens its article directly.
- The app refreshes history on launch/edition access, resume, foreground push, opening the inbox, pull-to-refresh, and once per minute while active. Read status is local to the installation, not synchronized between different phones.
- The plugin's internal sidebar provides settings, banners, reports, notifications, profiles and submissions. Registered legacy admin URLs remain available. Contact details are independently editable under **Contact details**, with identical initial defaults for both editions. The existing URL/highlights method for **In This Issue** is unchanged.
- Verification for this update: PHP payload/job tests, real local WordPress REST privacy tests, browser checks for sidebar navigation/contact saving/mobile layout, and Flutter tests for pagination, offline read-state retention, edition separation, inbox navigation and back-to-top scrolling. Live inbox delivery needs the new plugin deployed on both sites. Android APK installed successfully on device c2a40481 on 30 October 2026. Verified that the bell opens the Europe and USA inbox screens and that the article back-to-top button returns to the cover. Both live notification-history endpoints still return rest_no_route (404); inbox history/unread delivery verification requires plugin 0.7.0 installed on both sites.

- Isolated PHP notification checks cover payload, fallback, timezone, authorization, cancellation state, future jobs, duplicate workers and failed delivery; no real recipients are used in these tests.
- Android single-device image delivery verified on the connected phone, including visible expanded featured image. Test sends target only that device token, not edition subscriber topics. The existing installed Android build already supports this system notification image format.
- `tool/test_notification_device.py` is an explicit single-device smoke-test utility; supply a private credentials path, adb path and PHP path. It never prints tokens/private keys and never sends to a topic.
- USA text-only notification also received on Android; tapping opened its USA article.
- iOS project/embedding/plist structure checked; Mac build, signing and iPhone testing remain pending.

References: [Firebase image payloads](https://firebase.google.com/docs/cloud-messaging/customize-messages/cross-platform), [Apple notification service extensions](https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications), [WordPress scheduling](https://developer.wordpress.org/reference/functions/wp_schedule_single_event/).


## Compact inbox and submission navigation ? 30 October 2026

Plugin 0.7.1 groups Newsletter, Contact and Profile beneath Submissions in the application sidebar, preserving existing routes and CSV/bulk-delete controls. Duplicate content-area tabs are hidden after the dashboard loads.

Notification cards use a shared category/time row, two-line headline and preview, thumbnail, unread dot and chevron. All/Unread buttons use edition colours. Flutter widget checks at 320 and 390 logical pixels and local WordPress browser checks passed; Flutter analysis reported no issues. Install the updated plugin ZIP on both websites.

Installed the updated Android APK on device c2a40481 and visually checked populated Europe (1 notification) and USA (8 notifications, 7 unread) inboxes. Category/time alignment, compact cards, thumbnails, chevrons and unread dots displayed without overflow. Screenshots saved in artifacts/dual-edition/inbox-compact-europe.png and inbox-compact-usa.png.

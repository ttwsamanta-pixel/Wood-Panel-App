# Wood & Panel iOS release

## Release status

Checked in App Store Connect on 24 November 2026. [Wood & Panel iOS 1.0.0](https://appstoreconnect.apple.com/apps/6837897820/distribution/ios/version/inflight)

| Item | State |
|---|---|
| App Store review | `Prepare for Submission`. Build `1.0.0 (8)` is attached. `Add for Review` is visible. |
| Product page | Description, promotional text, keywords, support URL and copyright are entered. Media Manager shows zero screenshots in the required iPhone Dynamic Island (medium display) slot and two in the iPad 13-inch slot. Upload iPhone screenshots at 1179 × 2556 or 1206 × 2622 for portrait. |
| App Review information | Contact fields and reviewer notes are entered. Sign-in is unchecked because reviewers can tap Skip on the optional profile screen. |
| Privacy and availability | Privacy answers are published. Price is $0.00. The app uses public distribution across 173 storefronts, with France and China mainland excluded. Mac and Vision Pro availability and the School Manager volume discount are off. |
| Release timing | `Manually release this version` is selected. Set `Automatically release this version` on the version page and save if the owner confirms the earlier plan to launch automatically after approval. |
| EU trader status | App Compliance currently shows **non-trader**. Confirm that declaration with the account owner before releasing to the selected EU storefronts. |
| WordPress | The Europe and USA public configuration endpoints both return `ios_store_actions_enabled: false` and an empty iOS store URL. After the listing is publicly reachable, enter the Apple URL and enable iOS store actions in App Manager. Test Rate and Share in both editions. |

Upload the required iPhone screenshots and confirm release timing and the EU trader declaration before adding the version for review. If App Store Connect shows additional blockers, resolve them on the version or App Compliance page. Use **Add for Review** and then **Submit for Review** when the team is ready. [Apple’s submission guide](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)

### Build and test history

- [x] Audited the Mac and the iOS project. macOS `27.2.1`, Xcode `27.2` and the iOS `27.2` simulator runtime are available. The Mac now selects full Xcode for command-line development.
- [x] Resolved the Flutter lockfile with Flutter `3.47.5` and Dart `3.13.4`, ran analysis and passed all 91 Flutter tests. The notification extension also passed a Swift type check.
- [x] Built the debug simulator app at `build/ios/iphonesimulator/Runner.app` using a workspace-local `xcrun` override. The embedded ImageNotification extension and Runner both report `1.0.0+6` and iOS 15. The simulator app contains SDK privacy manifests. Review the signed release archive separately.
- [x] Installed and launched the build on the iPhone 18 Pro and iPad (A16) simulators. Both reached the welcome profile screen with the skip control, avatar picker and empty form visible. Screenshots are in `artifacts/ios-smoke/`.
- [x] Registered the separate iOS app ID `com.woodandpanel.mobile` and its extension ID `com.woodandpanel.mobile.ImageNotification` under Keshan Infotech Private Limited. The Xcode project uses those IDs and automatic signing for team `EF2P3LYG94`.
- [x] Bundled the matching Firebase configuration in Runner. The development and production APNs key uploads were reported complete. Verify push delivery on a physical iPhone.
- [x] Confirmed the separate App Store Connect record uses `com.woodandpanel.mobile`. Created `build/ios/archive/Runner.xcarchive` and exported `build/ios/ipa/Wood & Panel.ipa` as `1.0.0`, build `6`. Verified the exported signatures, embedded extension, Firebase configuration and production APNs entitlement locally.
- [x] Exported iOS build `1.0.0 (8)`, uploaded it to App Store Connect and tested it via internal TestFlight. The signed archive includes the code for the WordPress-controlled iOS Rate and Share actions.
- [ ] Publish the Universal Links association on the approved hosts. On 24 November 2026 the Europe apex redirected to `www`. Both `www` sites and the USA apex returned HTTP 500 for the association path.
- [ ] Record full device coverage, Crashlytics symbol receipt and Analytics verification using the checklist below.

## Continue from another computer

```sh
git clone https://github.com/ttwsamanta-pixel/Wood-Panel-App.git
cd Wood-Panel-App
git status --short --branch
flutter pub get --enforce-lockfile
flutter analyze lib test
flutter test
```

For an existing checkout on `main`, use `git pull --ff-only origin main`. Install the Flutter SDK described below. To finish the existing submission, sign in to the Keshan Infotech Private Limited App Store Connect team and open the version link above. Build 8 is already attached. Use a Mac with Xcode and access to that Apple developer team if you need a new signed build. Restore `ios/Runner/GoogleService-Info.plist` from Firebase for the exact bundle ID and use the iOS build variables below. For another upload, choose a build number above the latest upload while matching the App Store marketing version. Retrieve the original signed archive and dSYMs separately from the original Mac or a private backup if needed.

For Android, see the [deployment guide](dual-edition-deployment.md) and retrieve the existing release keystore and Firebase configuration privately. Keep signing credentials, APNs keys, Firebase service account keys and local configuration outside Git. Production WordPress settings and store form changes live in their respective consoles.

Paste this into a fresh Codex chat opened in the cloned repository:

> Continue Wood & Panel from the latest `origin/main`. Read `README.md`, `docs/ios-release.md` and `docs/dual-edition-deployment.md`. The new iOS listing is App Store Connect app 6837897820, version 1.0.0, build 8. Check the live store state against the handoff before assuming anything is finished. Help me complete the remaining release tasks and preserve the existing Apple and WordPress production settings unless I ask for changes.

## Local build

The repository was generated with Flutter `3.47.5`. The lockfile requires Flutter `3.47.0` and Dart `3.13.0` or newer. Runner and ImageNotification target iOS 15 and support iPhone and iPad. Install CocoaPods for the locked `flutter_secure_storage` and `flutter_tts` plugins. CocoaPods `1.17.0` was installed on the audit Mac. Flutter uses Swift Package Manager for the other native plugins. [Flutter Swift Package Manager guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)

Select full Xcode for command-line development in **Xcode → Settings → Locations → Command Line Tools**. The pinned `objective_c` build hook looks up the SDK with `xcrun` in a filtered environment, so it can miss a shell-only `DEVELOPER_DIR` override. [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)

```sh
export FIREBASE_ANALYTICS_WITHOUT_ADID=true
export AUDIO_SESSION_MICROPHONE=0
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build ios --simulator --debug
open --env FIREBASE_ANALYTICS_WITHOUT_ADID=true --env AUDIO_SESSION_MICROPHONE=0 ios/Runner.xcworkspace
```

Set `AUDIO_SESSION_MICROPHONE=0` for iOS builds. Wood & Panel plays audio but does not record it. This SwiftPM setting compiles out `audio_session`'s microphone permission APIs, which triggered App Store Connect error `ITMS-90683` on build 6. Run `flutter clean` before building if the setting changed. [audio_session iOS setup](https://pub.dev/packages/audio_session/versions/0.1.25#ios-setup)

A simulator build can omit Firebase configuration. Use it to check local app flows and layouts. An iPhone build with the final signing and Firebase configuration is needed for APNs and release verification.

The locked Firebase Analytics plugin selects `FirebaseAnalyticsCore` when `FIREBASE_ANALYTICS_WITHOUT_ADID` is set during Swift package resolution. Use that setting for iOS builds. Quit Xcode before using the `open --env` command so the new process gets the setting. Verify the resolved package product and archive privacy report before setting App Privacy answers. [Firebase Analytics data collection options](https://firebase.google.com/docs/analytics/ios/configure-data-collection)

## Apple account and Firebase

1. In Xcode, open **Settings → Apple Accounts** and sign in privately. Confirm the account lists **Keshan Infotech Private Limited**.
2. Open `ios/Runner.xcworkspace`. In **Signing & Capabilities**, verify automatic signing and the company team on Runner and ImageNotification. Verify Runner has Push Notifications, Background Modes → Remote notifications, and Associated Domains.
3. In Firebase **Project settings → General → Your apps**, register or select the exact final Runner bundle ID in `wood-and-panel-ecc55`. Save the generated file as `ios/Runner/GoogleService-Info.plist`. The Runner build phase copies it into the bundle and fails an archive when it is absent. The file is ignored by Git. Use the native iOS configuration for the release build.
4. In Firebase **Project settings → Cloud Messaging**, verify the APNs authentication key and Key ID for the iOS app and the Apple Team ID. Complete credential handling in the private Apple/Firebase consoles. Test development delivery on a signed phone and production delivery through TestFlight.

## Websites and Universal Links

Runner claims the `www` and apex hosts in both editions. Publish `/.well-known/apple-app-site-association` directly on each claimed host over HTTPS with HTTP 200, JSON content and no redirect. Use the signed app’s application identifier and confirmed article permalink patterns. Include the `/?p=<article ID>` route and the verified article paths for each edition. Keep unrelated website routes in the browser. If only the `www` hosts can serve association files directly, confirm canonical URLs on each site before narrowing the entitlement. Test real links from Notes or Messages on an iPhone for both regions. [Apple associated domains guide](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

Add the official iOS App Store URL to the WordPress plugin when the listing is publicly available, then turn on **Enable Rate Our App and Share App on iOS**. One enabled link serves both editions. If both sites enable the link, Europe takes precedence. Verify Rate, Share and optional update routing on iOS. Keep live maintenance and minimum versions as configured until the corresponding update is available.

## Archive, symbols and TestFlight

1. Set the first iOS marketing version in App Store Connect to match the built version. The first archive is `1.0.0+6`. Pass `--build-name` and `--build-number` to Flutter for an iOS-only override when needed.
2. With the iOS build environment variables above set, build a signed archive with `flutter build ipa --release --build-name <version> --build-number <number>`, or select a generic iOS device in Xcode and choose **Product → Archive**. Flutter puts archives under `build/ios/archive/` and exported IPAs under `build/ios/ipa/`. For Xcode archives, use **Window → Organizer → Archives** to locate the archive. Inspect the signed app for the expected entitlements and `PlugIns/ImageNotification.appex`. Confirm Runner and the extension share the version and build number.
3. Runner Release uses `DWARF with dSYM File`. Upload archive symbols with the Firebase SDK’s `Crashlytics/upload-symbols` script from the Xcode Swift package checkout. Flutter places the checkout under `build/ios/SourcePackages/checkouts/firebase-ios-sdk`. Confirm receipt in the iOS app’s Crashlytics dashboard and retain the archive with its dSYMs. [Firebase Crashlytics symbol upload](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports)

   ```sh
   "$FIREBASE_IOS_SDK_CHECKOUT/Crashlytics/upload-symbols" \
     -gsp "$PWD/ios/Runner/GoogleService-Info.plist" -p ios "$IOS_ARCHIVE/dSYMs"
   ```

4. In Xcode Organizer, use **Validate App**, then **Distribute App → App Store Connect → Upload** for the TestFlight build. In App Store Connect, complete export compliance based on the archived app’s implementation and add internal testers once the build finishes processing. App Store distribution goes through App Review. [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) · [Export compliance for beta builds](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds)

## Verification checklist

- [ ] On iPhone and iPad, check first launch, optional profile and bundled avatars, onboarding, permission denial, layout and keyboard behavior. Check Europe on cold launch, edition retention on resume, and Feed refresh after an edition switch.
- [ ] Check main tabs, article and interview reading, text-to-speech, back-to-top, video, external links, forms, ads, appearance and text size. Verify offline cache and PDF download, view, sharing, deletion, reading position and bookmarks. Check wallpaper preview, share and save with Photos add permission.
- [ ] On an isolated device, check both notification preferences and foreground, background and terminated delivery. Verify one alert per message, image and text-only fallback, edition/article routing, and independent unread counts after tapping or dismissing a system alert. Use direct device delivery or isolated topics for test sends.
- [ ] Verify existing Analytics events and a controlled development Crashlytics test with symbols. Restore a normal build afterward. Review the archive for SDK privacy manifests and tracking or advertising-identifier behavior before completing App Privacy disclosures. Include actual first-party collections for optional profile, newsletter, contact, ads reporting and diagnostics as applicable.
- [ ] Review the bundled in-app privacy fallback before release. The public policy already describes Analytics and Crashlytics. The bundled fallback currently describes Firebase Cloud Messaging and banner reporting. Review both sites’ configured in-app privacy content as well. [Public privacy policy](https://www.woodandpanel.com/app-privacy-policy/)
- [ ] Collect current screenshots from the running app and confirm the support and privacy URLs. In App Review notes, explain that profile entry is optional and users can browse without creating an account or signing in. The technical support address is `technical@woodandpanel.com` and the privacy contact is `pr@woodandpanel.com`. [Wood & Panel privacy policy](https://www.woodandpanel.com/app-privacy-policy/)

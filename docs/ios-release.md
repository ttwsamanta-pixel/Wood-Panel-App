# Wood & Panel iOS release

## Release status

- [x] Audited the Mac and the iOS project. macOS `27.2.1`, Xcode `27.2` and the iOS `27.2` simulator runtime are available. The Mac now selects full Xcode for command-line development.
- [x] Resolved the Flutter lockfile with Flutter `3.47.5` and Dart `3.13.4`, ran analysis and passed all 91 Flutter tests. The notification extension also passed a Swift type check.
- [x] Built the debug simulator app at `build/ios/iphonesimulator/Runner.app` using a workspace-local `xcrun` override. The embedded ImageNotification extension and Runner both report `1.0.0+6` and iOS 15. The simulator app contains SDK privacy manifests. Review the signed release archive separately.
- [x] Installed and launched the build on the iPhone 18 Pro and iPad (A16) simulators. Both reached the welcome profile screen with the skip control, avatar picker and empty form visible. Screenshots are in `artifacts/ios-smoke/`.
- [x] Registered the separate iOS app ID `com.woodandpanel.mobile` and its extension ID `com.woodandpanel.mobile.ImageNotification` under Keshan Infotech Private Limited. The Xcode project uses those IDs and automatic signing for team `EF2P3LYG94`.
- [ ] Configure matching Firebase and APNs registration, then verify signing on a physical iPhone.
- [ ] Publish the Universal Links association on the approved hosts. During the audit the Europe apex redirected to `www`. Both `www` sites and the USA apex returned HTTP 500 for the association path.
- [ ] Verify device workflows, Crashlytics symbols and analytics, then archive and validate for TestFlight. The full device checklist is below.

## Local build

The repository was generated with Flutter `3.47.5`. The lockfile requires Flutter `3.47.0` and Dart `3.13.0` or newer. Runner and ImageNotification target iOS 15 and support iPhone and iPad. Install CocoaPods for the locked `flutter_secure_storage` and `flutter_tts` plugins. CocoaPods `1.17.0` was installed on the audit Mac. Flutter uses Swift Package Manager for the other native plugins. [Flutter Swift Package Manager guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)

Select full Xcode for command-line development in **Xcode → Settings → Locations → Command Line Tools**. The pinned `objective_c` build hook looks up the SDK with `xcrun` in a filtered environment, so it can miss a shell-only `DEVELOPER_DIR` override. [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)

```sh
export FIREBASE_ANALYTICS_WITHOUT_ADID=true
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build ios --simulator --debug
open --env FIREBASE_ANALYTICS_WITHOUT_ADID=true ios/Runner.xcworkspace
```

A simulator build can omit Firebase configuration. Use it to check local app flows and layouts. An iPhone build with the final signing and Firebase configuration is needed for APNs and release verification.

The locked Firebase Analytics plugin selects `FirebaseAnalyticsCore` when `FIREBASE_ANALYTICS_WITHOUT_ADID` is set during Swift package resolution. Use that setting for iOS builds. Quit Xcode before using the `open --env` command so the new process gets the setting. Verify the resolved package product and archive privacy report before setting App Privacy answers. [Firebase Analytics data collection options](https://firebase.google.com/docs/analytics/ios/configure-data-collection)

## Apple account and Firebase

1. In Xcode, open **Settings → Apple Accounts** and sign in privately. Confirm the account lists **Keshan Infotech Private Limited**.
2. Open `ios/Runner.xcworkspace`. In **Signing & Capabilities**, verify automatic signing and the company team on Runner and ImageNotification. Verify Runner has Push Notifications, Background Modes → Remote notifications, and Associated Domains.
3. In Firebase **Project settings → General → Your apps**, register or select the exact final Runner bundle ID in `wood-and-panel-ecc55`. Save the generated file as `ios/Runner/GoogleService-Info.plist`. The Runner build phase copies it into the bundle and fails an archive when it is absent. The file is ignored by Git. Use the native iOS configuration for the release build.
4. In Firebase **Project settings → Cloud Messaging**, verify the APNs authentication key and Key ID for the iOS app and the Apple Team ID. Complete credential handling in the private Apple/Firebase consoles. Test development delivery on a signed phone and production delivery through TestFlight.

## Websites and Universal Links

Runner claims the `www` and apex hosts in both editions. Publish `/.well-known/apple-app-site-association` directly on each claimed host over HTTPS with HTTP 200, JSON content and no redirect. Use the signed app’s application identifier and confirmed article permalink patterns. Include the `/?p=<article ID>` route and the verified article paths for each edition. Keep unrelated website routes in the browser. If only the `www` hosts can serve association files directly, confirm canonical URLs on each site before narrowing the entitlement. Test real links from Notes or Messages on an iPhone for both regions. [Apple associated domains guide](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

Add the official iOS App Store URL to the WordPress plugin when the listing URL is available. Verify Rate, Share and optional update routing on iOS. Keep live maintenance and minimum versions as configured until the corresponding update is available.

## Archive, symbols and TestFlight

1. Confirm the first iOS marketing version and a unique iOS build number in App Store Connect. The repository currently defaults to `1.0.0+6`. Pass `--build-name` and `--build-number` to Flutter for an iOS-only override when needed.
2. Build a signed archive with `flutter build ipa --release --build-name <version> --build-number <number>`, or select a generic iOS device in Xcode and choose **Product → Archive**. Flutter puts archives under `build/ios/archive/` and exported IPAs under `build/ios/ipa/`. For Xcode archives, use **Window → Organizer → Archives** to locate the archive. Inspect the signed app for the expected entitlements and `PlugIns/ImageNotification.appex`. Confirm Runner and the extension share the version and build number.
3. Runner Release uses `DWARF with dSYM File`. Upload archive symbols with the Firebase SDK’s `Crashlytics/upload-symbols` script from the Xcode Swift package checkout. Flutter places the checkout under `build/ios/SourcePackages/checkouts/firebase-ios-sdk`. Confirm receipt in the iOS app’s Crashlytics dashboard and retain the archive with its dSYMs. [Firebase Crashlytics symbol upload](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports)

   ```sh
   "$FIREBASE_IOS_SDK_CHECKOUT/Crashlytics/upload-symbols" \
     -gsp "$PWD/ios/Runner/GoogleService-Info.plist" -p ios "$IOS_ARCHIVE/dSYMs"
   ```

4. In Xcode Organizer, use **Validate App**, then **Distribute App → App Store Connect → Upload** for the authorized TestFlight build. In App Store Connect, complete export compliance based on the archived app’s implementation and add internal testers once the build finishes processing. Public App Store submission requires separate approval. [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) and [export compliance for beta builds](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds)

## Verification checklist

- [ ] On iPhone and iPad, check first launch, optional profile and bundled avatars, onboarding, permission denial, layout and keyboard behavior. Check Europe on cold launch, edition retention on resume, and Feed refresh after an edition switch.
- [ ] Check main tabs, article and interview reading, text-to-speech, back-to-top, video, external links, forms, ads, appearance and text size. Verify offline cache and PDF download, view, sharing, deletion, reading position and bookmarks. Check wallpaper preview, share and save with Photos add permission.
- [ ] On an isolated device, check both notification preferences and foreground, background and terminated delivery. Verify one alert per message, image and text-only fallback, edition/article routing, and independent unread counts after tapping or dismissing a system alert. Use direct device delivery or isolated topics for test sends.
- [ ] Verify existing Analytics events and a controlled development Crashlytics test with symbols. Restore a normal build afterward. Review the archive for SDK privacy manifests and tracking or advertising-identifier behavior before completing App Privacy disclosures. Include actual first-party collections for optional profile, newsletter, contact, ads reporting and diagnostics as applicable.
- [ ] Review the bundled in-app privacy fallback before release. The public policy already describes Analytics and Crashlytics. The bundled fallback currently describes Firebase Cloud Messaging and banner reporting. Review both sites’ configured in-app privacy content as well. [Public privacy policy](https://www.woodandpanel.com/app-privacy-policy/)
- [ ] Collect current screenshots from the running app and confirm the support and privacy URLs. In App Review notes, explain that profile entry is optional and users can browse without creating an account or signing in. The technical support address is `technical@woodandpanel.com` and the privacy contact is `pr@woodandpanel.com`. [Wood & Panel privacy policy](https://www.woodandpanel.com/app-privacy-policy/)

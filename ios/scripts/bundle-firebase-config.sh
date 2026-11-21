#!/bin/sh
set -eu

config="$SRCROOT/Runner/GoogleService-Info.plist"
destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"

if [ ! -f "$config" ]; then
  # An incremental build must not keep a previously bundled configuration.
  rm -f "$destination"
  if [ "$ACTION" = install ] && [ "$PLATFORM_NAME" = iphoneos ]; then
    echo 'error: Add the matching GoogleService-Info.plist to ios/Runner before archiving.' >&2
    exit 1
  fi
  exit 0
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$config")" != "$PRODUCT_BUNDLE_IDENTIFIER" ] ||
   [ "$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$config")" != wood-and-panel-ecc55 ]; then
  echo 'error: GoogleService-Info.plist must match the Runner bundle ID and the wood-and-panel-ecc55 Firebase project.' >&2
  exit 1
fi

/usr/bin/install -m 0644 "$config" "$destination"

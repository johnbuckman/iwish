#!/bin/bash
# Sign an iWish .app and install it on a connected iOS device.
#
# PREREQS (need an Apple Developer account):
#   1. A device connected & paired (`xcrun devicectl list devices`).
#   2. A provisioning profile (.mobileprovision) for an App ID matching the app's
#      Info.plist CFBundleIdentifier, including this device's UDID (+ any
#      capability your app uses, e.g. Bluetooth). Easiest: make a throwaway Xcode
#      iOS App project with that bundle id, "Automatically manage signing" with
#      your team, then grab the generated .mobileprovision.
#
# Usage:
#   sign-and-install-device.sh <app.app> <identity> <profile.mobileprovision> <udid> [entitlements.plist]
#     <identity>  e.g. "Apple Development: You (TEAMID)"
set -uo pipefail
APP="${1:?path to .app}"
IDENTITY="${2:?signing identity}"
PROFILE="${3:?profile.mobileprovision}"
UDID="${4:?device udid}"
ENT="${5:-}"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"

cp "$PROFILE" "$APP/embedded.mobileprovision"
echo "=== sign every nested dylib/.so inside-out ==="
find "$APP" \( -name "*.dylib" -o -name "*.so" \) -print0 | while IFS= read -r -d '' f; do
  codesign -f -s "$IDENTITY" --timestamp=none "$f" || echo "FAILED: $f"
done
echo "=== sign the executable + app$( [ -n "$ENT" ] && echo " (with entitlements)" ) ==="
codesign -f -s "$IDENTITY" --timestamp=none "$APP/$EXE"
if [ -n "$ENT" ]; then
  codesign -f -s "$IDENTITY" --timestamp=none --entitlements "$ENT" "$APP"
else
  codesign -f -s "$IDENTITY" --timestamp=none "$APP"
fi
echo "=== verify ==="
codesign -dv "$APP" 2>&1 | head -5
echo "=== install on device $UDID ==="
xcrun devicectl device install app --device "$UDID" "$APP" && echo "INSTALLED" || echo "install failed"
echo "Launch:  xcrun devicectl device process launch --device $UDID $BUNDLE_ID"

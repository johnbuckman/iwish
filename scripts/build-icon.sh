#!/bin/bash
# Build an iOS app icon and (optionally) install it into a .app bundle.
#
# Usage:  build-icon.sh <source-image> [<app-bundle-dir>]
#   <source-image>   PNG/JPG/PSD, or an .ico frame e.g. "foo.ico[4]"
#   <app-bundle-dir> if given, copies the compiled icon into it
#
# iOS icons must be a single opaque 1024x1024 image; iOS applies its own
# rounded-corner mask. This flattens any alpha onto white and fills/crops to a
# centered square, then compiles an `AppIcon` asset catalog with actool.
# Reference CFBundleIconName=AppIcon in your Info.plist.
#
# Requires ImageMagick (`magick`) and Xcode (`actool`).
set -euo pipefail
SRC="${1:?source image}"
APP="${2:-}"
TMP="$(mktemp -d)"

magick "$SRC" -background white -alpha remove -alpha off \
    -filter Lanczos -resize 1024x1024^ -gravity center -extent 1024x1024 \
    "$TMP/icon1024.png"

mkdir -p "$TMP/Assets.xcassets/AppIcon.appiconset" "$TMP/out"
cp "$TMP/icon1024.png" "$TMP/Assets.xcassets/AppIcon.appiconset/icon1024.png"
cat > "$TMP/Assets.xcassets/AppIcon.appiconset/Contents.json" <<'JSON'
{ "images":[{"filename":"icon1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],
  "info":{"author":"xcode","version":1} }
JSON

xcrun actool "$TMP/Assets.xcassets" --compile "$TMP/out" \
    --platform iphoneos --minimum-deployment-target 15.0 --app-icon AppIcon \
    --output-partial-info-plist "$TMP/partial.plist" \
    --target-device iphone --target-device ipad >/dev/null
echo "built: $(ls "$TMP/out" | tr '\n' ' ')"

if [ -n "$APP" ]; then
    cp "$TMP/out/Assets.car" "$TMP/out/AppIcon60x60@2x.png" "$TMP/out/AppIcon76x76@2x~ipad.png" "$APP/"
    echo "installed icon -> $APP  (re-sign + reinstall to see it on device)"
fi
echo "(work dir: $TMP)"

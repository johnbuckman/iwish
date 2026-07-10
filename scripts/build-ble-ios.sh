#!/bin/bash
# Build the iWish ble shim (libble1.0.dylib) for an arm64 iOS device.
# tclble_androwish.m = the AndroWish/de1app-compatible CoreBluetooth backend
# (address-first `ble connect <addr> <cb>`, AllowDuplicates:NO so scan-response
# names coalesce, advertised services + manufacturer in the scan event). ARC.
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
TARGET=arm64-apple-ios15.0
TCLINC=/Users/john/iwish/src/androwish/jni/tcl/generic
TCLSTUB=/Users/john/iwish/build/awtcl-dev/libtclstub8.6.a
COMMON="-arch arm64 -target $TARGET -miphoneos-version-min=15.0 -isysroot $SDK -I$TCLINC -fPIC -DUSE_TCL_STUBS=1 -DTCL_UTF_MAX=6 -fobjc-arc"

echo "clang: tclble_androwish.m -> libble1.0.dylib"
xcrun -sdk iphoneos clang -dynamiclib tclble_androwish.m "$TCLSTUB" \
    -o libble1.0.dylib $COMMON \
    -install_name ble-ios/libble1.0.dylib \
    -framework Foundation -framework CoreBluetooth -framework UIKit

echo "done: $(vtool -show-build libble1.0.dylib 2>/dev/null | awk '/platform/{print $2}')  $(lipo -info libble1.0.dylib | sed 's/.*: //')"

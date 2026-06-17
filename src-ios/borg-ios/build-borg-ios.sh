#!/bin/bash
# Build the iWish borg shim (libborg1.0.dylib) for an arm64 iOS device.
# Pure ObjC: tclBorgios.m (manual-retain) + scalessec/Toast UIView+Toast.m (ARC)
# for the native `borg toast`. No Swift -> no Swift-runtime dependency.
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
TARGET=arm64-apple-ios15.0
TCLINC=/Users/john/iwish/src/androwish/jni/tcl/generic
TCLSTUB=/Users/john/iwish/build/awtcl-dev/libtclstub8.6.a
COMMON="-arch arm64 -target $TARGET -miphoneos-version-min=15.0 -isysroot $SDK -I$TCLINC -I. -fPIC -DUSE_TCL_STUBS=1 -DTCL_UTF_MAX=6"

echo "1/3 clang: UIView+Toast.m (ARC)"
xcrun -sdk iphoneos clang -c UIView+Toast.m -o toast.o -fobjc-arc $COMMON

echo "2/3 clang: tclBorgios.m (manual-retain)"
xcrun -sdk iphoneos clang -c tclBorgios.m -o tclBorgios.o $COMMON

echo "3/3 link libborg1.0.dylib"
xcrun -sdk iphoneos clang -dynamiclib toast.o tclBorgios.o "$TCLSTUB" \
    -o libborg1.0.dylib $COMMON \
    -install_name borg-ios/libborg1.0.dylib \
    -framework Foundation -framework UIKit -framework AudioToolbox \
    -framework AVFoundation -framework CoreGraphics -framework QuartzCore

echo "done: $(vtool -show-build libborg1.0.dylib 2>/dev/null | awk '/platform/{print $2}')"

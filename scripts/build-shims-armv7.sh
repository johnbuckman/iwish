#!/bin/bash
# Build the borg + ble ObjC shims for armv7/iOS9. Small ObjC files (no huge functions),
# so Apple clang armv7 works directly (same as the Kitchen Timer recipe) -> no NDK wrapper.
set -uo pipefail
ROOT=/Users/john/iwish-ios9
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
CC=$(xcrun --find clang)
TCLINC=$ROOT/src/androwish/jni/tcl/generic
STUB=$ROOT/build/awtcl-armv7/libtclstub8.6.a
A="-arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -fobjc-arc -fPIC -DUSE_TCL_STUBS=1 -DTCL_UTF_MAX=6 -I$TCLINC -Wl,-ld_classic -Wl,-undefined,dynamic_lookup"

echo ">>> borg-ios (armv7)"
$CC -dynamiclib $A -o "$ROOT/borg-ios/libborg1.0.dylib" "$ROOT/borg-ios/tclBorgios.m" "$STUB" \
  -framework Foundation -framework UIKit -framework AudioToolbox -framework AVFoundation -framework CoreGraphics \
  -install_name @loader_path/libborg1.0.dylib 2>&1 | grep -iE 'error:|Relocation|undefined|symbol.* not found' | grep -viE 'tbd|Simulator|ld_classic is dep' | head
file "$ROOT/borg-ios/libborg1.0.dylib" 2>&1 | grep -o arm_v7 && echo "borg armv7 OK" || echo "borg FAIL"

echo ">>> ble-ios (armv7)"
# tclble.m is the de1app-compatible in-process CoreBluetooth backend (the macOS
# tcl-ble-osx native/tclble.m API, ported to armv7/iOS9 with a CBManagerState
# compat shim + the central created on the calling thread so didDiscoverPeripheral
# fires on iOS -- see IOS9-BLE.md). It supersedes the older tclBLEios.m (kept in
# the tree for reference). UIKit is NOT needed by tclble.m.
$CC -dynamiclib $A -o "$ROOT/ble-ios/libble1.0.dylib" "$ROOT/ble-ios/tclble.m" "$STUB" \
  -framework Foundation -framework CoreBluetooth \
  -install_name @loader_path/libble1.0.dylib 2>&1 | grep -iE 'error:|Relocation|undefined|symbol.* not found' | grep -viE 'tbd|Simulator|ld_classic is dep' | head
file "$ROOT/ble-ios/libble1.0.dylib" 2>&1 | grep -o arm_v7 && echo "ble armv7 OK" || echo "ble FAIL"
echo "DONE_SHIMS_ARMV7"

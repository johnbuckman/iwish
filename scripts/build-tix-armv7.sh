#!/bin/bash
# Build Tix (tixwidgets/tixtour) for armv7 / iOS 9 -> loadable dylib + stage.
# Deep ext (includes tkInt.h): needs -DPLATFORM_SDL + sdl2tk/sdl, and the TEA
# Makefile's macOS-XQuartz X11 refs stripped. Usage: build-tix-armv7.sh [stage-dir]
set -uo pipefail
ROOT=/Users/john/iwish-ios9
JNI="$ROOT/src/androwish/jni"
SDL="$JNI/sdl2tk/sdl"; T="$JNI/Tix"; SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
STAGE="${1:-$ROOT/dist/iWish-armv7.app/lib-batteries/Tix8.4.3}"
ARM64STAGE=/Users/john/iwish/dist/iWish.app/lib-batteries/Tix8.4.3  # for the library .tcl + demos

cd "$T"
EXTRA_CFLAGS="-DPLATFORM_SDL -I$SDL" bash "$ROOT/build-ext-armv7.sh" "$T" >/tmp/tix-armv7.log 2>&1
# drop the macOS XQuartz X11 the TEA Makefile adds (undefined Xlib syms resolve at load)
perl -pi -e 's@-L/opt/X11/lib@@g; s@-lX11@@g; s@-lXext@@g; s@-lXft@@g; s@-I/opt/X11/include@@g' Makefile
make CXX="$ROOT/armv7-toolchain/cxx" LDFLAGS="-arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -Wl,-undefined,dynamic_lookup -Wl,-ld_classic -lc++ -lc++abi" >>/tmp/tix-armv7.log 2>&1
[ -f "$T/libTix8.4.3.dylib" ] || { echo "BUILD FAILED"; tail -20 /tmp/tix-armv7.log; exit 1; }
echo "built: $(lipo -info "$T/libTix8.4.3.dylib")"

# stage: reuse the arm64 Tix8.4.3 dir (correct pkgIndex full-path load + library .tcl +
# demos/tixwidgets.tcl + demos/widget) and swap in the armv7 dylib.
rm -rf "$STAGE"; cp -R "$ARM64STAGE" "$STAGE"
cp "$T/libTix8.4.3.dylib" "$STAGE/libTix8.4.3.dylib"
echo "DONE — Tix8.4.3 (armv7) staged at $STAGE"

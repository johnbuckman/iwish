#!/bin/bash
# Cross-compile an AndroWish TEA extension for the iOS device -> loadable dylib.
# Sibling of build-ext-cat.sh (Catalyst). Usage: build-ext-sim.sh <ext-src-dir> [extra configure args...]
set -uo pipefail
ROOT=/Users/john/iwish
EXTDIR="$1"; shift
MINVER=15.0
SIMSDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC=$(xcrun --sdk iphoneos --find clang)
CXX=$(xcrun --sdk iphoneos --find clang++)
SIMc="-target arm64-apple-ios${MINVER} -miphoneos-version-min=${MINVER} -isysroot $SIMSDK"
# link: undefined symbols (Tcl/Tk stubs) resolved at load time against the sim wish
SIMl="-target arm64-apple-ios${MINVER} -miphoneos-version-min=${MINVER} -isysroot $SIMSDK -Wl,-undefined,dynamic_lookup"

TCLDIR=$ROOT/build/awtcl-dev
TKDIR=$ROOT/src/androwish/jni/sdl2tk/sdl
TKINC=$ROOT/src/androwish/jni/sdl2tk/generic
TCLINC=$ROOT/src/androwish/jni/tcl/generic

cd "$EXTDIR"
make distclean >/dev/null 2>&1 || true

export CC CXX
export CFLAGS="$SIMc -fPIC -DTCL_UTF_MAX=6 -I$TCLINC -I$TKINC -I$ROOT/src/androwish/jni/sdl2tk/xlib ${EXTRA_CFLAGS:-}"
export CPPFLAGS="$SIMc"
export LDFLAGS="$SIMl ${EXTRA_LDFLAGS:-}"

./configure \
  --build=arm64-apple-darwin --host=arm-apple-darwin \
  --with-tcl="$TCLDIR" --with-tk="$TKDIR" \
  --with-tclinclude="$TCLINC" --with-tkinclude="$TKINC" \
  --enable-threads --enable-shared \
  "$@" 2>&1 | tail -12
echo "=== CONFIGURE EXIT: $? ==="
# TEA links Tk extensions against -ltk8.6 / sdl2tk/unix; fix for sdl2tk
perl -pi -e 's/-ltk8\.6/-lsdl2tkstub8.6/g; s@sdl2tk/unix@sdl2tk/sdl@g; s/-ltkstub8\.6/-lsdl2tkstub8.6/g' Makefile 2>/dev/null
echo "=== make ==="
make 2>&1 | grep -iE "error:|\.dylib|undefined|Undefined" | head -20
echo "=== result dylib ==="
find . -maxdepth 2 -name "*.dylib" 2>/dev/null
echo "DONE_EXT_SIM"

#!/bin/bash
# Cross-compile an AndroWish TEA extension for armv7 / iOS 9 -> loadable dylib.
# Port of build-ext-dev.sh. Uses the armv7 wrapper toolchain (NDK compile + Apple/ld_classic
# link), theos 9.3 SDK, TCL_UTF_MAX=6, 32-bit ABI cache. Usage: build-ext-armv7.sh <ext-src-dir> [configure args...]
set -uo pipefail
ROOT=/Users/john/iwish-ios9
EXTDIR="$1"; shift
MINVER=9.0
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
CC="$ROOT/armv7-toolchain/cc"
CXX="$ROOT/armv7-toolchain/cxx"
# clang 16+ (NDK clang-18) makes these hard errors; old TEA ext code trips them -> downgrade.
WNO="-Wno-undef-prefix -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
ARCH="-arch armv7 -isysroot $SDK -miphoneos-version-min=$MINVER $WNO"
# dynamic_lookup: Tcl/Tk stub symbols resolve at load against the host wish; ld_classic for old SDK
LINKF="$ARCH -Wl,-undefined,dynamic_lookup -Wl,-ld_classic -lc++ -lc++abi"
# 32-bit armv7 ABI (NOT arm64's 8/8)
export ac_cv_sizeof_int=4 ac_cv_sizeof_long=4 ac_cv_sizeof_long_long=8 ac_cv_sizeof_void_p=4 ac_cv_sizeof_size_t=4

TCLDIR=$ROOT/build/awtcl-armv7
TKDIR=$ROOT/src/androwish/jni/sdl2tk/sdl
TKINC=$ROOT/src/androwish/jni/sdl2tk/generic
TCLINC=$ROOT/src/androwish/jni/tcl/generic

cd "$EXTDIR"
make distclean >/dev/null 2>&1 || true
find . -maxdepth 2 -name '*.dylib' -delete 2>/dev/null || true   # drop stale (arm64) dylib

export CC CXX
export CFLAGS="$ARCH -fPIC -DTCL_UTF_MAX=6 -I$TCLINC -I$TKINC -I$ROOT/src/androwish/jni/sdl2tk/xlib -I$ROOT/src/SDL2-2.30.11/include ${EXTRA_CFLAGS:-}"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$ARCH"
export LDFLAGS="$LINKF ${EXTRA_LDFLAGS:-}"

./configure \
  --build=arm64-apple-darwin --host=arm-apple-darwin \
  --with-tcl="$TCLDIR" --with-tk="$TKDIR" \
  --with-tclinclude="$TCLINC" --with-tkinclude="$TKINC" \
  --enable-threads --enable-shared \
  "$@" 2>&1 | tail -8
echo "=== CONFIGURE EXIT: ${PIPESTATUS[0]} ==="
# TEA links Tk extensions against -ltk8.6 / sdl2tk/unix; fix for sdl2tk
perl -pi -e 's/-ltk8\.6/-lsdl2tkstub8.6/g; s@sdl2tk/unix@sdl2tk/sdl@g; s/-ltkstub8\.6/-lsdl2tkstub8.6/g' Makefile 2>/dev/null
# strip host x86 /usr/local SDL2 headers (their SDL_cpuinfo.h pulls x86 immintrin.h)
perl -pi -e 's@-I/usr/local/include/SDL2@@g; s@-I/usr/local/include\b@@g' Makefile 2>/dev/null
echo "=== make ==="
make 2>&1 | grep -iE "error:|Relocation|\.dylib|undefined symbol|symbol.* not found" | grep -viE 'tbd file|Simulator|ld_classic is dep' | head -20
echo "=== result dylib(s) ==="
find . -maxdepth 2 -name "*.dylib" 2>/dev/null
echo "DONE_EXT_ARMV7"

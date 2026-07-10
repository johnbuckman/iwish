#!/bin/bash
# Build TkBLT (blt::graph/barchart/vector) for armv7 / iOS 9 -> loadable dylib.
# armv7 port of ~/iwish/build-tkblt-dev.sh. Uses build-ext-armv7.sh (NDK compile +
# Apple/ld_classic link, theos 9.3 SDK, TCL_UTF_MAX=6, 32-bit ABI).
# Usage: build-tkblt-armv7.sh [stage-dir]
set -uo pipefail
ROOT=/Users/john/iwish-ios9
JNI="$ROOT/src/androwish/jni"
SDL="$JNI/sdl2tk/sdl"
SRC="$JNI/tkblt"
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
STAGE="${1:-$ROOT/dist/IwishDE1-armv7.app/lib-batteries/Tkblt3.2}"

[ -d "$SRC/generic" ] || { echo "no tkblt source at $SRC"; exit 1; }

# 1. build via the armv7 TEA harness. Deep-ext flags: -DPLATFORM_SDL + sdl2tk/sdl.
echo "=== building libtkblt3.2.dylib (armv7) ==="
EXTRA_CFLAGS="-DPLATFORM_SDL -I$SDL" bash "$ROOT/build-ext-armv7.sh" "$SRC" >/tmp/tkblt-armv7-build.log 2>&1

# 2. strip the stray -lX11 the TEA Makefile appends, and relink cleanly with the
#    armv7 link flags (dynamic_lookup + ld_classic + libc++). The LDFLAGS live in
#    the harness ENV, not the Makefile, so a bare `make` drops them -> relink here.
cd "$SRC"
perl -pi -e 's@-L/usr/local/lib @@g; s/-lX11 //g' Makefile
rm -f libtkblt3.2.dylib
CXX="$ROOT/armv7-toolchain/cxx"
make LDFLAGS="-arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -Wl,-undefined,dynamic_lookup -Wl,-ld_classic -lc++ -lc++abi" >>/tmp/tkblt-armv7-build.log 2>&1

if [ ! -f "$SRC/libtkblt3.2.dylib" ]; then
  echo "BUILD FAILED — tail of /tmp/tkblt-armv7-build.log:"; tail -25 /tmp/tkblt-armv7-build.log; exit 1
fi
echo "built: $(lipo -info "$SRC/libtkblt3.2.dylib")"

# 3. stage: dylib + graph.tcl (version 3.0->3.2 to match Tkblt_Init) + clean pkgIndex.
echo "=== staging into $STAGE ==="
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$SRC/libtkblt3.2.dylib" "$STAGE/"
cp "$SRC/library/graph.tcl"  "$STAGE/"
perl -pi -e 's/^package provide Tkblt 3\.0/package provide Tkblt 3.2/' "$STAGE/graph.tcl"
cat > "$STAGE/pkgIndex.tcl" <<'PKG'
# TkBLT (staged for iWish / armv7-ios9-sdl2tk). load the armv7 dylib (init =
# Tkblt_Init, provides Tkblt 3.2) then source the graph.tcl glue (patched to 3.2).
package ifneeded Tkblt 3.2 [list apply {{dir} {
    load [file join $dir libtkblt3.2.dylib] Tkblt
    source [file join $dir graph.tcl]
}} $dir]
PKG
echo "DONE — Tkblt3.2 (armv7) staged at $STAGE"

#!/bin/bash
# Build TkBLT (William Joye's maintained BLT subset — the scientific-plotting
# widgets blt::graph / blt::barchart / blt::vector, used by SAOImage DS9) for
# the iOS device, and stage it as a loadable battery.
#
# Why TkBLT instead of the classic BLT 2.4 (see build-blt-dev.sh): TkBLT drops
# all of BLT's X11-only widgets (container, cutbuffer, drag&drop, tabset, hierbox
# …) — exactly the pieces that don't exist on sdl2tk and needed per-widget
# stubbing. What remains is pure plotting drawn through Tk's own API, so it
# cross-compiles cleanly. There are NO `#include <X11/…>` in the sources; the
# XDrawLines/XFillArc/… calls resolve at load against the SdlTk* symbols the
# iWish binary exports (same -undefined dynamic_lookup trick as every ext).
#
# Prereqs: the awtcl-dev Tcl stubs + sdl2tk built (see build-device.sh), and
# build-ext-dev.sh present. Usage: build-tkblt-dev.sh [stage-dir]
#   stage-dir defaults to dist/iWish.app/lib-batteries/Tkblt3.2
set -uo pipefail
ROOT="${IWISH_ROOT:-$HOME/iwish}"
JNI="$ROOT/src/androwish/jni"
SDL="$JNI/sdl2tk/sdl"
SRC="$JNI/tkblt"
STAGE="${1:-$ROOT/dist/iWish.app/lib-batteries/Tkblt3.2}"

# 1. fetch source (maintained fork) if not already present
if [ ! -d "$SRC/generic" ]; then
  echo "=== cloning TkBLT into $SRC ==="
  git clone --depth 1 https://github.com/wjoye/tkblt.git "$SRC"
fi

# 2. build the dylib via the shared TEA harness. The key flags for any "deep"
#    extension (one that pulls in tkInt.h -> tkPort.h) are -DPLATFORM_SDL (use
#    sdl2tk's Tk port, not the real X11 one) + -I <sdl2tk>/sdl (SdlTkX.h decls).
echo "=== building libtkblt3.2.dylib ==="
EXTRA_CFLAGS="-DPLATFORM_SDL -I$SDL" "$ROOT/build-ext-dev.sh" "$SRC" >/tmp/tkblt-build.log 2>&1

# 3. the generated TEA Makefile appends a stray "-L/usr/local/lib -lX11" (wrong
#    arch; ld only warns and ignores it). Strip it and relink cleanly, keeping
#    the dynamic_lookup flag (which lives in build-ext-dev.sh's LDFLAGS env, not
#    in the Makefile — so a bare `make` would turn the SdlTk* refs into errors).
cd "$SRC"
perl -pi -e 's@-L/usr/local/lib @@g; s/-lX11 //g' Makefile
rm -f libtkblt3.2.dylib
make LDFLAGS="-target arm64-apple-ios15.0 -miphoneos-version-min=15.0 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) -Wl,-undefined,dynamic_lookup" >>/tmp/tkblt-build.log 2>&1
if [ ! -f "$SRC/libtkblt3.2.dylib" ]; then
  echo "BUILD FAILED — see /tmp/tkblt-build.log"; tail -20 /tmp/tkblt-build.log; exit 1
fi
echo "built: $(lipo -info "$SRC/libtkblt3.2.dylib")"

# 4. stage battery = dylib + graph.tcl + a corrected pkgIndex.
#    Two upstream-packaging bugs are fixed here:
#      (a) graph.tcl does `package provide Tkblt 3.0`, but Tkblt_Init (C) provides
#          3.2 (PACKAGE_VERSION) -> `package require` fails "3.2 failed: 3.0
#          provided instead". Bump graph.tcl to 3.2 so the two agree.
#      (b) upstream's generated pkgIndex.tcl has a literal "\n" (backslash-n,
#          not a newline) between the load and the `source graph.tcl` -> the glue
#          never runs. Write a clean ifneeded instead.
echo "=== staging into $STAGE ==="
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$SRC/libtkblt3.2.dylib" "$STAGE/"
cp "$SRC/library/graph.tcl"  "$STAGE/"
perl -pi -e 's/^package provide Tkblt 3\.0/package provide Tkblt 3.2/' "$STAGE/graph.tcl"
cat > "$STAGE/pkgIndex.tcl" <<'PKG'
# TkBLT (staged for iWish / iphoneos-sdl2tk). load the arm64 dylib (init =
# Tkblt_Init) then source the graph.tcl glue. Version is 3.2 to match both the
# C init and the (patched) graph.tcl provide.
package ifneeded Tkblt 3.2 [list apply {{dir} {
    load [file join $dir libtkblt3.2.dylib] Tkblt
    source [file join $dir graph.tcl]
}} $dir]
PKG
echo "DONE — Tkblt3.2 staged. In iWish: package require Tkblt; blt::graph .g ..."

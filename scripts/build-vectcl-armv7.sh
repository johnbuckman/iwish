#!/bin/bash
# Build VecTcl (vectcl numeric library) for armv7 / iOS 9 -> loadable dylib + stage.
# Two source patches vs stock (both in the bundled f2c math lib, unavailable on iOS):
#   - f2c_mathlib.h: `rv = system(buff)` -> stubbed (no fork/exec on iOS)
#   - f2c_mathlib.h: `drem(x,y)` -> `remainder(x,y)` (drem removed from the iOS libm)
# Usage: build-vectcl-armv7.sh [stage-dir]
set -uo pipefail
ROOT=/Users/john/iwish-ios9
JNI="$ROOT/src/androwish/jni"
SDL="$JNI/sdl2tk/sdl"; V="$JNI/VecTcl"
STAGE="${1:-$ROOT/dist/iWish-armv7.app/lib-batteries/vectcl0.3}"
ARM64STAGE=/Users/john/iwish/dist/iWish.app/lib-batteries/vectcl0.3

# idempotent source patches
perl -pi -e 's/rv = system\(buff\)/rv = -1; (void)buff/; s/^double drem\(\);/\/* drem unavailable on iOS; use remainder() *\//; s/drem\(/remainder(/g' "$V/generic/f2c_mathlib.h"

cd "$V"
EXTRA_CFLAGS="-DPLATFORM_SDL -I$SDL" bash "$ROOT/build-ext-armv7.sh" "$V" >/tmp/vectcl-armv7.log 2>&1
f=$(find "$V" -maxdepth 2 -name "libvectcl0.3.dylib" | head -1)
[ -n "$f" ] || { echo "BUILD FAILED"; tail -20 /tmp/vectcl-armv7.log; exit 1; }
echo "built: $(lipo -info "$f")"

# stage: reuse the arm64 vectcl0.3 dir (pkgIndex + vexpr.tcl + demo), swap the dylib.
rm -rf "$STAGE"; cp -R "$ARM64STAGE" "$STAGE"
cp "$f" "$STAGE/libvectcl0.3.dylib"
echo "DONE — vectcl0.3 (armv7) staged at $STAGE  (vectclab demo stays greyed: needs a Tk-enabled slave interp, incompatible with static sdl2tk)"

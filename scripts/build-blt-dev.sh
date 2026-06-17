#!/bin/bash
# Build BLT 2.4 (libBLT24 -> tkblt shim) for the iOS device. Mirrors the
# Catalyst recipe (memory iwish_ios_port) with the sim arch.
set -uo pipefail
ROOT=/Users/john/iwish
cd "$ROOT/src/androwish/jni/blt"
SIMSDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC=$(xcrun --sdk iphoneos --find clang)
export CC
NOMODS="-DNO_PRINTER -DNO_CONTAINER -DNO_EPSCANV -DNO_DRAGDROP -DNO_DND -DNO_HIERBOX -DNO_HTEXT -DNO_TABSET -DNO_TABNOTEBOOK -DNO_TREEVIEW -DNO_TED -DNO_CUTBUFFER -DNO_DDE -DNO_MOUNTAIN -DNO_TABLE -DNO_BGEXEC -DNO_WINOP -DNO_TILEFRAME -DNO_TILEBUTTON -DNO_TILESCROLLBAR"
# cross-compile: preset autoconf sizeof cache as ENV (NOT configure args)
export ac_cv_sizeof_void_p=8 ac_cv_sizeof_long=8 ac_cv_sizeof_long_long=8 ac_cv_sizeof_int=4
export CFLAGS="-target arm64-apple-ios15.0 -miphoneos-version-min=15.0 -isysroot $SIMSDK -fPIC -DPLATFORM_SDL=1 -DTCL_UTF_MAX=6 -I$ROOT/src/androwish/jni/sdl2tk/sdl -I$ROOT/src/androwish/jni/sdl2tk/xlib -I$ROOT/src/androwish/jni/sdl2tk/generic -I$ROOT/src/androwish/jni/tcl/unix -I$ROOT/src/androwish/jni/tcl/generic -Dfinite=isfinite -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-int-conversion -Wno-error $NOMODS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-target arm64-apple-ios15.0 -miphoneos-version-min=15.0 -isysroot $SIMSDK"

make distclean >/dev/null 2>&1 || true
./configure --host=arm-apple-darwin --build=arm64-apple-darwin \
  --with-tcl="$ROOT/build/awtcl-dev" --with-tk="$ROOT/src/androwish/jni/sdl2tk/sdl" \
  --disable-shared 2>&1 | tail -6
echo "=== CONFIGURE EXIT: $? ==="

# configure regenerates bltConfig.h with the broken size_t/pid_t defines -> re-comment
perl -pi -e 's@^#define size_t unsigned@/* #define size_t unsigned */@; s@^#define pid_t int@/* #define pid_t int */@' src/bltConfig.h
# patch shared/Makefile: sdl2tk stubs, sim Tcl stubs, drop X11, dynamic_lookup
SM=src/shared/Makefile
perl -pi -e 's@-ltk8\.6@-L'"$ROOT"'/src/androwish/jni/sdl2tk/sdl -lsdl2tkstub8.6@g' "$SM"
perl -pi -e 's@-ltcl8\.6@-L'"$ROOT"'/build/awtcl-dev -ltclstub8.6@g' "$SM"
perl -pi -e 's@-LNONE@@g; s@-lX11@@g' "$SM"
perl -pi -e 's@(SHLIB_LD_FLAGS\s*=.*)@$1 -Wl,-undefined,dynamic_lookup@' "$SM"
rm -f src/shared/*.o

echo "=== make build_shared ==="
make build_shared 2>&1 | grep -iE "error:|Error [0-9]|undefined|\.so$|symbol not found" | head -30
echo "=== BUILD EXIT: ${PIPESTATUS[0]} ==="
find . -name "libBLT*.so" -o -name "libBLT*.dylib" 2>/dev/null
echo "DONE_BLT_SIM"

#!/bin/bash
# Build BLT 2.4 (libBLT24 -> tkblt shim for de1app) for armv7/iOS9.
# Port of build-blt-dev.sh. CRITICAL: armv7 ABI cache is void_p=4 (NOT arm64's 8),
# else bltConfig.h size_t/pid_t misfire -> the de1app shot-graph createProc crash.
set -uo pipefail
ROOT=/Users/john/iwish-ios9
cd "$ROOT/src/androwish/jni/blt"
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
CC="$ROOT/armv7-toolchain/cc"
export CC
NOMODS="-DNO_PRINTER -DNO_CONTAINER -DNO_EPSCANV -DNO_DRAGDROP -DNO_DND -DNO_HIERBOX -DNO_HTEXT -DNO_TABSET -DNO_TABNOTEBOOK -DNO_TREEVIEW -DNO_TED -DNO_CUTBUFFER -DNO_DDE -DNO_MOUNTAIN -DNO_TABLE -DNO_BGEXEC -DNO_WINOP -DNO_TILEFRAME -DNO_TILEBUTTON -DNO_TILESCROLLBAR"
# 32-bit armv7 autoconf sizeof cache as ENV (old configure misreads them as host triples if args)
export ac_cv_sizeof_void_p=4 ac_cv_sizeof_long=4 ac_cv_sizeof_long_long=8 ac_cv_sizeof_int=4
A="-arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -Wno-undef-prefix"
export CFLAGS="$A -fPIC -DPLATFORM_SDL=1 -DTCL_UTF_MAX=6 -I$ROOT/src/androwish/jni/sdl2tk/sdl -I$ROOT/src/androwish/jni/sdl2tk/xlib -I$ROOT/src/androwish/jni/sdl2tk/generic -I$ROOT/src/androwish/jni/tcl/unix -I$ROOT/src/androwish/jni/tcl/generic -Wno-error=implicit-function-declaration -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion -Wno-error $NOMODS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="$A -Wl,-ld_classic"

make distclean >/dev/null 2>&1 || true
rm -f src/shared/*.o src/*.o
./configure --host=arm-apple-darwin --build=arm64-apple-darwin \
  --with-tcl="$ROOT/build/awtcl-armv7" --with-tk="$ROOT/src/androwish/jni/sdl2tk/sdl" \
  --disable-shared 2>&1 | tail -6
echo "=== CONFIGURE EXIT: ${PIPESTATUS[0]} ==="
# configure regenerates bltConfig.h with broken size_t/pid_t -> re-comment
perl -pi -e 's@^#define size_t unsigned@/* #define size_t unsigned */@; s@^#define pid_t int@/* #define pid_t int */@' src/bltConfig.h
SM=src/shared/Makefile
perl -pi -e 's@-ltk8\.6@-L'"$ROOT"'/src/androwish/jni/sdl2tk/sdl -lsdl2tkstub8.6@g' "$SM"
perl -pi -e 's@-ltcl8\.6@-L'"$ROOT"'/build/awtcl-armv7 -ltclstub8.6@g' "$SM"
perl -pi -e 's@-LNONE@@g; s@-lX11@@g' "$SM"
perl -pi -e 's@(SHLIB_LD_FLAGS\s*=.*)@$1 -Wl,-undefined,dynamic_lookup -Wl,-ld_classic@' "$SM"
rm -f src/shared/*.o
make -C src build_shared 2>&1 | grep -iE 'error:|Relocation|\.so|\.dylib|undefined|symbol.* not found' | grep -viE 'tbd file|Simulator|ld_classic is dep' | head -20
echo "=== result ==="; find . -maxdepth 2 -name 'libBLT*.so' -o -maxdepth 2 -name 'libBLT*.dylib' 2>/dev/null
echo "DONE_BLT_ARMV7"

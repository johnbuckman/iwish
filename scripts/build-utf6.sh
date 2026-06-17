#!/bin/bash
# Rebuild iWish's AndroWish Tcl and sdl2tk for Mac Catalyst with a chosen
# TCL_UTF_MAX (default 6 = UCS-4, full astral Unicode, matching AndroWish).
# Usage: build-utf6.sh tcl       # rebuild Tcl only
#        build-utf6.sh sdl2tk    # rebuild sdl2tk only (needs Tcl already built)
#        build-utf6.sh all       # both
# Env:   UTFMAX=6 (override)
set -uo pipefail
ROOT=/Users/john/iwish
MINVER=15.0
UTFMAX="${UTFMAX:-6}"
MACSDK=$(xcrun --sdk macosx --show-sdk-path)
IOSSUP="$MACSDK/System/iOSSupport"
CC=$(xcrun --sdk macosx --find clang)
CXX=$(xcrun --sdk macosx --find clang++)
CATc="-target arm64-apple-ios${MINVER}-macabi -isysroot $MACSDK -iframework $IOSSUP/System/Library/Frameworks -isystem $IOSSUP/usr/include"
CATl="-target arm64-apple-ios${MINVER}-macabi -isysroot $MACSDK -L$IOSSUP/usr/lib -F$IOSSUP/System/Library/Frameworks"
WHAT="${1:-all}"

build_tcl() {
  echo ">>> AndroWish Tcl (catalyst, TCL_UTF_MAX=$UTFMAX)"
  rm -rf "$ROOT/build/awtcl-cat"; mkdir -p "$ROOT/build/awtcl-cat"; cd "$ROOT/build/awtcl-cat"
  export CC CFLAGS="$CATc -DZIPFS_IN_TCL=1 -DTCL_UTF_MAX=$UTFMAX" CPPFLAGS="$CATc" LDFLAGS="$CATl"
  "$ROOT/src/androwish/jni/tcl/unix/configure" \
    --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/awtcl-cat" --disable-shared --disable-framework \
    tcl_cv_strtod_buggy=ok tcl_cv_strtod_unbroken=ok ac_cv_func_strtod=yes \
    ac_cv_func_memcmp_working=yes tcl_cv_strstr_unbroken=ok tcl_cv_strtoul_unbroken=ok ac_cv_func_mkstemp=yes \
    >/tmp/utf6_tcl_cfg.log 2>&1 || { echo "TCL configure FAILED"; tail -20 /tmp/utf6_tcl_cfg.log; exit 1; }
  sed -i '' 's/ -DTCL_LOAD_FROM_MEMORY=1//g' Makefile
  make -j8 binaries >/tmp/utf6_tcl_make.log 2>&1 || { echo "TCL make FAILED"; tail -25 /tmp/utf6_tcl_make.log; exit 1; }
  echo "TCL built: $(ls -la "$ROOT/build/awtcl-cat/tclsh" 2>/dev/null)"
}

build_sdl2tk() {
  echo ">>> sdl2tk + sdl2wish (catalyst, TCL_UTF_MAX=$UTFMAX)"
  SHIM="$ROOT/build/shimbin-cat"
  cd "$ROOT/src/androwish/jni/sdl2tk/sdl"
  make distclean >/dev/null 2>&1 || true; rm -f build-stamp libagg.a
  export PATH="$SHIM:$PATH" CC CXX
  export CFLAGS="$CATc -fPIC -DZIPFS_IN_TCL=1 -DAGG_CUSTOM_ALLOCATOR=1 -DTCL_UTF_MAX=$UTFMAX"
  export CXXFLAGS="$CATc -fPIC -DTCL_UTF_MAX=$UTFMAX"
  export CPPFLAGS="$CATc -DTCL_UTF_MAX=$UTFMAX"
  export LDFLAGS="$CATl"
  export PKG_CONFIG_PATH="$ROOT/dist/pkgconfig-cat" PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-cat"
  ./configure --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/sdl2tk-cat" --disable-shared --disable-rpath \
    --with-tcl="$ROOT/build/awtcl-cat" \
    tcl_cv_strtod_buggy=ok ac_cv_func_strtod=yes ac_cv_func_memcmp_working=yes \
    >/tmp/utf6_tk_cfg.log 2>&1 || { echo "TK configure FAILED"; tail -20 /tmp/utf6_tk_cfg.log; exit 1; }
  perl -pi -e 's@-I/usr/X11R6/include@@g' Makefile
  perl -pi -e 's@-DBUILD_tk@@g' Makefile
  perl -pi -e 's@MODULE_SCOPE=@MODULE_SCOPE_NOTUSED=@g' Makefile
  perl -pi -e 's@-lSDL2@-lSDL2main -lSDL2 -liconv@g' Makefile
  perl -pi -e 's@ -DTCL_LOAD_FROM_MEMORY=1@@g' Makefile
  perl -pi -e 's@-Wl,-(weak_)?framework,OpenGLES@@g' Makefile
  # SdlTkInt.o's PowerinfoObjCmd uses IOKit power-source APIs (IOPS*) on Catalyst.
  perl -pi -e 's@(-Wl,-framework,QuartzCore)@$1 -Wl,-framework,IOKit@ unless /IOKit/' Makefile
  make libagg.a >/tmp/utf6_tk_make.log 2>&1 || { echo "TK libagg FAILED"; tail -25 /tmp/utf6_tk_make.log; exit 1; }
  make binaries >>/tmp/utf6_tk_make.log 2>&1 || { echo "TK binaries FAILED"; tail -25 /tmp/utf6_tk_make.log; exit 1; }
  echo "TK built: $(ls -la "$ROOT/src/androwish/jni/sdl2tk/sdl/sdl2wish" 2>/dev/null)"
}

case "$WHAT" in
  tcl) build_tcl;;
  sdl2tk) build_sdl2tk;;
  all) build_tcl; build_sdl2tk;;
  *) echo "usage: $0 tcl|sdl2tk|all"; exit 2;;
esac
echo "DONE_UTF6_BUILD ($WHAT)"

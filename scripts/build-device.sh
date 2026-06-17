#!/bin/bash
# Build the whole iwish stack for the iOS DEVICE arch (arm64-apple-ios, iphoneos SDK)
# so it runs natively on Apple Silicon macOS via /System/iOSSupport ("Designed for iPad").
set -uo pipefail
ROOT=/Users/john/iwish
MINVER=15.0
SDK=iphoneos
SDKROOT=$(xcrun --sdk $SDK --show-sdk-path)
CC=$(xcrun --sdk $SDK --find clang)
CXX=$(xcrun --sdk $SDK --find clang++)
TGT=arm64-apple-ios${MINVER}
ARCHFLAGS="-arch arm64 -isysroot $SDKROOT -target $TGT -miphoneos-version-min=${MINVER}"
LOG=/tmp/iwish_device_build.log
: > "$LOG"
say(){ echo ">>> $*" | tee -a "$LOG"; }

# ---------- 1. FreeType ----------
say "FreeType (device)"
(
  cd "$ROOT/src/androwish/jni/freetype"
  make distclean >/dev/null 2>&1 || true
  export CC CFLAGS="$ARCHFLAGS -fPIC" CPPFLAGS="$ARCHFLAGS" LDFLAGS="$ARCHFLAGS"
  ./configure --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/ft-dev" --disable-shared --enable-static \
    --with-bzip2=no --with-png=no --with-brotli=no --with-harfbuzz=no --with-zlib=no
  make -j8 && make install
) >>"$LOG" 2>&1 || { echo "FREETYPE FAILED"; exit 1; }

# ---------- 2. SDL2 ----------
say "SDL2 (device)"
(
  rm -rf "$ROOT/build/sdl-dev" "$ROOT/dist/sdl-dev"; mkdir -p "$ROOT/build/sdl-dev"
  cd "$ROOT/build/sdl-dev"
  cmake "$ROOT/src/SDL2-2.30.11" \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$MINVER \
    -DCMAKE_INSTALL_PREFIX="$ROOT/dist/sdl-dev" \
    -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF \
    -DSDL_CCACHE=OFF -DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER= -DCMAKE_OBJC_COMPILER_LAUNCHER=
  cmake --build . --target SDL2-static SDL2main -j8
  cmake --install .
) >>"$LOG" 2>&1 || { echo "SDL2 FAILED"; exit 1; }

# ---------- 3. AndroWish Tcl 8.6.10 ----------
say "AndroWish Tcl (device)"
(
  rm -rf "$ROOT/build/awtcl-dev" "$ROOT/dist/awtcl-dev"; mkdir -p "$ROOT/build/awtcl-dev"
  cd "$ROOT/build/awtcl-dev"
  export CC CFLAGS="$ARCHFLAGS -DZIPFS_IN_TCL=1 -DTCL_UTF_MAX=6" CPPFLAGS="$ARCHFLAGS" LDFLAGS="$ARCHFLAGS"
  "$ROOT/src/androwish/jni/tcl/unix/configure" \
    --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/awtcl-dev" --disable-shared --disable-framework \
    tcl_cv_strtod_buggy=ok tcl_cv_strtod_unbroken=ok ac_cv_func_strtod=yes \
    ac_cv_func_memcmp_working=yes tcl_cv_strstr_unbroken=ok tcl_cv_strtoul_unbroken=ok ac_cv_func_mkstemp=yes
  sed -i '' 's/ -DTCL_LOAD_FROM_MEMORY=1//g' Makefile
  make -j8 binaries
) >>"$LOG" 2>&1 || { echo "AWTCL FAILED"; exit 1; }

# ---------- 4. pkgconfig + shims ----------
say "pkgconfig + shims (device)"
mkdir -p "$ROOT/dist/pkgconfig-dev"
cp "$ROOT/dist/sdl-dev/lib/pkgconfig/sdl2.pc" "$ROOT/dist/pkgconfig-dev/"
cp "$ROOT/dist/ft-dev/lib/pkgconfig/freetype2.pc" "$ROOT/dist/pkgconfig-dev/"
SHIM="$ROOT/build/shimbin-dev"; rm -rf "$SHIM"; mkdir -p "$SHIM"
cat > "$SHIM/freetype-config" <<EOF
#!/bin/bash
case "\$1" in
  --cflags) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-dev" pkg-config --cflags freetype2;;
  --libs)   PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-dev" pkg-config --libs freetype2;;
  --ftversion|--version) echo "26.1.20";;
esac
EOF
cat > "$SHIM/sdl2-config" <<EOF
#!/bin/bash
case "\$1" in
  --cflags) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-dev" pkg-config --cflags sdl2;;
  --libs|--static-libs) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-dev" pkg-config --libs sdl2;;
  --version) echo "2.30.11";;
esac
EOF
chmod +x "$SHIM"/*

# ---------- 5. sdl2tk (Tk + SdlTkX + AGG) + sdl2wish ----------
say "sdl2tk + sdl2wish (device)"
(
  cd "$ROOT/src/androwish/jni/sdl2tk/sdl"
  make distclean >/dev/null 2>&1 || true; rm -f build-stamp libagg.a
  export PATH="$SHIM:$PATH"
  export CC CXX
  export CFLAGS="$ARCHFLAGS -fPIC -DZIPFS_IN_TCL=1 -DTCL_UTF_MAX=6 -DAGG_CUSTOM_ALLOCATOR=1"
  export CXXFLAGS="$ARCHFLAGS -fPIC"
  export CPPFLAGS="$ARCHFLAGS"
  export LDFLAGS="$ARCHFLAGS"
  export PKG_CONFIG_PATH="$ROOT/dist/pkgconfig-dev" PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-dev"
  ./configure --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/sdl2tk-dev" --disable-shared --disable-rpath \
    --with-tcl="$ROOT/build/awtcl-dev" \
    tcl_cv_strtod_buggy=ok ac_cv_func_strtod=yes ac_cv_func_memcmp_working=yes
  perl -pi -e 's@-I/usr/X11R6/include@@g' Makefile
  perl -pi -e 's@-DBUILD_tk@@g' Makefile
  perl -pi -e 's@MODULE_SCOPE=@MODULE_SCOPE_NOTUSED=@g' Makefile
  perl -pi -e 's@-lSDL2@-lSDL2main -lSDL2 -liconv@g' Makefile
  perl -pi -e 's@ -DTCL_LOAD_FROM_MEMORY=1@@g' Makefile
  make libagg.a
  make binaries
) >>"$LOG" 2>&1 || { echo "SDL2TK FAILED (see $LOG)"; tail -25 "$LOG"; exit 1; }

WISH="$ROOT/src/androwish/jni/sdl2tk/sdl/sdl2wish"
say "RESULT"
ls -la "$WISH"
vtool -show-build "$WISH" 2>&1 | grep -iE "platform|minos"
echo "DONE_DEVICE_BUILD"

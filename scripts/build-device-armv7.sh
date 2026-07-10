#!/bin/bash
# Build the iwish FOUNDATION (FreeType, SDL2, AndroWish Tcl, sdl2tk, sdl2wish) for
# armv7 / iOS 9 -> jailbroken iPad mini 1 (iPad2,5, iOS 9.3.5, A5, no Metal).
#
# Uses the theos iPhoneOS9.3 SDK + the CLASSIC linker (the modern Xcode linker can't
# link the old SDK). 32-bit ABI: void*=4/long=4 (NOT arm64's 8) -> autoconf cache preset.
# Rendering: OpenGLES2 (A5 has no Metal).
set -uo pipefail
ROOT=/Users/john/iwish-ios9
MINVER=9.0
SDKROOT="$HOME/theos/sdks/iPhoneOS9.3.sdk"
# CC/CXX = wrappers: NDK clang-18 compiles (Apple clang-21's armv7 backend can't
# assemble Tcl's huge functions -> "Relocation Not In Range"), Apple clang links
# with -ld_classic (proven loadable-jailbreak path).
CC="$ROOT/armv7-toolchain/cc"
CXX="$ROOT/armv7-toolchain/cxx"
# -Wno-undef-prefix: 9.3 SDK's TargetConditionals.h predates TARGET_OS_OSX/MACCATALYST;
# undefined -> 0 is the correct value for a real iOS device, just don't -Werror on it.
ARCHFLAGS="-arch armv7 -isysroot $SDKROOT -miphoneos-version-min=$MINVER -Wno-undef-prefix"
LDCLASSIC="-Wl,-ld_classic"
# CRITICAL: 32-bit armv7 ABI cache (arm64 used 8/8; armv7 is 4/4). Wrong values poison size_t.
ABICACHE="ac_cv_sizeof_int=4 ac_cv_sizeof_long=4 ac_cv_sizeof_long_long=8 ac_cv_sizeof_void_p=4 ac_cv_sizeof_size_t=4 ac_cv_sizeof_long_double=16"
LOG=/tmp/iwish_armv7_build.log
: > "$LOG"
say(){ echo ">>> $*" | tee -a "$LOG"; }

[ -d "$SDKROOT" ] || { echo "ERROR: theos 9.3 SDK missing at $SDKROOT"; exit 1; }

# ld_classic concurrent-build deadlock guard (a second run wedges the Mac -> reboot).
LOCK="$ROOT/.build-armv7.lock"
if ! mkdir "$LOCK" 2>/dev/null; then echo "ERROR: another armv7 build is running ($LOCK)"; exit 1; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# --- Idempotent theos-SDK stub fixups (same as KitchenTimer recipe) ---------
if [ ! -f "$SDKROOT/usr/lib/system/liblaunch.tbd" ]; then
  cat > "$SDKROOT/usr/lib/system/liblaunch.tbd" <<'TBD'
---
archs:                 [ armv7, armv7s, arm64, i386, x86_64 ]
platform:              ios
install-name:          /usr/lib/system/liblaunch.dylib
current-version:       0
compatibility-version: 1
exports:
  - archs:              [ armv7, armv7s, arm64, i386, x86_64 ]
    symbols:            [ _bootstrap_port, _bootstrap_look_up, _launch_msg,
                          _launch_data_free, _launch_data_new_string ]
...
TBD
  say "patched SDK: liblaunch.tbd"
fi
if [ ! -d "$SDKROOT/usr/include/c++/v1" ]; then
  mkdir -p "$SDKROOT/usr/include/c++"
  cp -R "$(xcrun --sdk iphoneos --show-sdk-path)/usr/include/c++/v1" "$SDKROOT/usr/include/c++/v1"
  say "patched SDK: libc++ v1 headers (theos SDK shipped only libstdc++ 4.2.1)"
fi
if [ ! -f "$SDKROOT/usr/include/AvailabilityVersions.h" ]; then
  cp "$(xcrun --sdk iphoneos --show-sdk-path)/usr/include/AvailabilityVersions.h" "$SDKROOT/usr/include/AvailabilityVersions.h"
  say "patched SDK: AvailabilityVersions.h"
fi
# crt_externs.h: the modern SDK copy pulls in _bounds.h (absent in 9.3); write a minimal stub.
if [ ! -f "$SDKROOT/usr/include/crt_externs.h" ] || grep -q _bounds.h "$SDKROOT/usr/include/crt_externs.h" 2>/dev/null; then
  rm -f "$SDKROOT/usr/include/crt_externs.h"
  cat > "$SDKROOT/usr/include/crt_externs.h" <<'CRT'
#ifndef _CRT_EXTERNS_H_
#define _CRT_EXTERNS_H_
#include <sys/cdefs.h>
__BEGIN_DECLS
extern char ***_NSGetArgv(void);
extern int    *_NSGetArgc(void);
extern char ***_NSGetEnviron(void);
extern char  **_NSGetProgname(void);
__END_DECLS
#endif
CRT
  say "patched SDK: crt_externs.h (minimal)"
fi
if ! grep -q '\[ _memset,' "$SDKROOT/usr/lib/system/libsystem_c.tbd"; then
  python3 - "$SDKROOT/usr/lib/system/libsystem_c.tbd" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
add=("  - archs:              [ armv7, armv7s, arm64, i386, x86_64 ]\n"
     "    symbols:            [ _memset, _memcpy, _memmove, _memcmp, _memchr, _bzero ]\n")
s=s.replace("exports:\n","exports:\n"+add,1); open(p,'w').write(s)
PY
  say "patched SDK: mem syms in libsystem_c.tbd"
fi
if ! grep -q '_strchr,' "$SDKROOT/usr/lib/system/libsystem_c.tbd"; then
  python3 - "$SDKROOT/usr/lib/system/libsystem_c.tbd" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
add=("  - archs:              [ armv7, armv7s, arm64, i386, x86_64 ]\n"
     "    symbols:            [ _strchr, _strrchr, _strcmp, _strncmp, _strcasecmp,\n"
     "                          _strncasecmp, _strcoll, _strxfrm, _strpbrk, _strspn,\n"
     "                          _strcspn, _strsep, _strtok, _strtok_r, _index, _rindex,\n"
     "                          _bcmp, _bcopy, _ffs ]\n")
s=s.replace("exports:\n","exports:\n"+add,1); open(p,'w').write(s)
PY
  say "patched SDK: str syms in libsystem_c.tbd"
fi

# ---------- 1. FreeType ----------
if [ -f "$ROOT/dist/ft-armv7/lib/libfreetype.a" ]; then say "FreeType (armv7) cached, skip"; else
say "FreeType (armv7)"
(
  cd "$ROOT/src/androwish/jni/freetype"
  make distclean >/dev/null 2>&1 || true
  export CC CFLAGS="$ARCHFLAGS -fPIC" CPPFLAGS="$ARCHFLAGS" LDFLAGS="$ARCHFLAGS $LDCLASSIC"
  ./configure --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/ft-armv7" --disable-shared --enable-static \
    --with-bzip2=no --with-png=no --with-brotli=no --with-harfbuzz=no --with-zlib=no \
    $ABICACHE
  make -j8 && make install
) >>"$LOG" 2>&1 || { echo "FREETYPE FAILED"; tail -25 "$LOG"; exit 1; }
fi

# ---------- 2. SDL2 (GLES2, no Metal) ----------
if [ -f "$ROOT/dist/sdl-armv7/lib/libSDL2.a" ]; then say "SDL2 (armv7) cached, skip"; else
say "SDL2 (armv7, GLES2)"
(
  rm -rf "$ROOT/build/sdl-armv7" "$ROOT/dist/sdl-armv7"; mkdir -p "$ROOT/build/sdl-armv7"
  cd "$ROOT/build/sdl-armv7"
  cmake "$ROOT/src/SDL2-2.30.11" \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDKROOT" \
    -DCMAKE_OSX_ARCHITECTURES=armv7 -DCMAKE_OSX_DEPLOYMENT_TARGET=$MINVER \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_INSTALL_PREFIX="$ROOT/dist/sdl-armv7" \
    -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF \
    -DSDL_METAL=OFF -DSDL_OPENGLES=ON -DSDL_OPENGL=OFF \
    -DSDL_AUDIO=OFF -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF -DSDL_HIDAPI=OFF -DSDL_SENSOR=OFF \
    -DSDL_CCACHE=OFF -DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER= -DCMAKE_OBJC_COMPILER_LAUNCHER= \
    -DCMAKE_EXE_LINKER_FLAGS="$LDCLASSIC" -DCMAKE_SHARED_LINKER_FLAGS="$LDCLASSIC"
  cmake --build . --target SDL2-static SDL2main -j8
  cmake --install .
) >>"$LOG" 2>&1 || { echo "SDL2 FAILED"; tail -40 "$LOG"; exit 1; }
fi

# ---------- 3. AndroWish Tcl 8.6.10 ----------
if [ -f "$ROOT/build/awtcl-armv7/libtcl8.6.a" ]; then say "AndroWish Tcl (armv7) cached, skip"; else
say "AndroWish Tcl (armv7)"
(
  rm -rf "$ROOT/build/awtcl-armv7" "$ROOT/dist/awtcl-armv7"; mkdir -p "$ROOT/build/awtcl-armv7"
  cd "$ROOT/build/awtcl-armv7"
  export CC CFLAGS="$ARCHFLAGS -DZIPFS_IN_TCL=1 -DTCL_UTF_MAX=6" CPPFLAGS="$ARCHFLAGS" LDFLAGS="$ARCHFLAGS $LDCLASSIC"
  "$ROOT/src/androwish/jni/tcl/unix/configure" \
    --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/awtcl-armv7" --disable-shared --disable-framework \
    tcl_cv_strtod_buggy=ok tcl_cv_strtod_unbroken=ok ac_cv_func_strtod=yes \
    ac_cv_func_memcmp_working=yes tcl_cv_strstr_unbroken=ok tcl_cv_strtoul_unbroken=ok ac_cv_func_mkstemp=yes \
    $ABICACHE
  sed -i '' 's/ -DTCL_LOAD_FROM_MEMORY=1//g' Makefile
  make -j8 binaries
) >>"$LOG" 2>&1 || { echo "AWTCL FAILED"; tail -30 "$LOG"; exit 1; }
fi

# ---------- 4. pkgconfig + shims ----------
say "pkgconfig + shims (armv7)"
mkdir -p "$ROOT/dist/pkgconfig-armv7"
cp "$ROOT/dist/sdl-armv7/lib/pkgconfig/sdl2.pc" "$ROOT/dist/pkgconfig-armv7/"
cp "$ROOT/dist/ft-armv7/lib/pkgconfig/freetype2.pc" "$ROOT/dist/pkgconfig-armv7/"
SHIM="$ROOT/build/shimbin-armv7"; rm -rf "$SHIM"; mkdir -p "$SHIM"
cat > "$SHIM/freetype-config" <<EOF
#!/bin/bash
case "\$1" in
  --cflags) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-armv7" pkg-config --cflags freetype2;;
  --libs)   PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-armv7" pkg-config --libs freetype2;;
  --ftversion|--version) echo "26.1.20";;
esac
EOF
cat > "$SHIM/sdl2-config" <<EOF
#!/bin/bash
case "\$1" in
  --cflags) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-armv7" pkg-config --cflags sdl2;;
  --libs|--static-libs) PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-armv7" pkg-config --libs sdl2;;
  --version) echo "2.30.11";;
esac
EOF
chmod +x "$SHIM"/*

# ---------- 5. sdl2tk + sdl2wish ----------
say "sdl2tk + sdl2wish (armv7)"
(
  cd "$ROOT/src/androwish/jni/sdl2tk/sdl"
  make distclean >/dev/null 2>&1 || true; rm -f build-stamp libagg.a sdl2wish *.o
  export PATH="$SHIM:$PATH"
  export CC CXX
  export CFLAGS="$ARCHFLAGS -fPIC -DZIPFS_IN_TCL=1 -DTCL_UTF_MAX=6 -DAGG_CUSTOM_ALLOCATOR=1"
  export CXXFLAGS="$ARCHFLAGS -fPIC -stdlib=libc++"
  export CPPFLAGS="$ARCHFLAGS"
  # -lc++ -lc++abi: on armv7 the driver doesn't auto-link c++abi (operator new/delete live there)
  export LDFLAGS="$ARCHFLAGS $LDCLASSIC -lc++ -lc++abi"
  export PKG_CONFIG_PATH="$ROOT/dist/pkgconfig-armv7" PKG_CONFIG_LIBDIR="$ROOT/dist/pkgconfig-armv7"
  ./configure --build=arm64-apple-darwin --host=arm-apple-darwin \
    --prefix="$ROOT/dist/sdl2tk-armv7" --disable-shared --disable-rpath \
    --with-tcl="$ROOT/build/awtcl-armv7" \
    tcl_cv_strtod_buggy=ok ac_cv_func_strtod=yes ac_cv_func_memcmp_working=yes \
    $ABICACHE
  perl -pi -e 's@-I/usr/X11R6/include@@g' Makefile
  perl -pi -e 's@-DBUILD_tk@@g' Makefile
  perl -pi -e 's@MODULE_SCOPE=@MODULE_SCOPE_NOTUSED=@g' Makefile
  perl -pi -e 's@-lSDL2@-lSDL2main -lSDL2 -liconv@g' Makefile
  perl -pi -e 's@ -DTCL_LOAD_FROM_MEMORY=1@@g' Makefile
  make libagg.a
  make binaries
) >>"$LOG" 2>&1 || { echo "SDL2TK FAILED (see $LOG)"; tail -40 "$LOG"; exit 1; }

WISH="$ROOT/src/androwish/jni/sdl2tk/sdl/sdl2wish"
say "RESULT"
ls -la "$WISH" 2>&1 | tee -a "$LOG"
file "$WISH" 2>&1 | tee -a "$LOG"
echo "DONE_ARMV7_FOUNDATION" | tee -a "$LOG"

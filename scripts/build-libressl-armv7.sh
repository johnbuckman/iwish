#!/bin/bash
# Build LibreSSL static libs for armv7/iOS9 -> /tmp/ssl-armv7 prefix (for tls).
set -uo pipefail
ROOT=/Users/john/iwish-ios9
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
CC="$ROOT/armv7-toolchain/cc"
PFX=/tmp/ssl-armv7
export CC
export ac_cv_sizeof_int=4 ac_cv_sizeof_long=4 ac_cv_sizeof_long_long=8 ac_cv_sizeof_void_p=4 ac_cv_sizeof_size_t=4
A="-arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -Wno-undef-prefix"
export CFLAGS="$A -fPIC -Dendbr64= -D_DARWIN_C_SOURCE -D__BSD_VISIBLE=1 -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error"
export CPPFLAGS="$A"
export LDFLAGS="$A -Wl,-ld_classic"
cd "$ROOT/src/androwish/jni/libressl"
make distclean >/dev/null 2>&1 || true
./configure --host=arm-apple-darwin --build=arm64-apple-darwin \
  --with-pic --disable-shared --disable-tests --disable-asm \
  --prefix="$PFX" 2>&1 | tail -5
echo "=== CONFIGURE EXIT: ${PIPESTATUS[0]} ==="
# include FIRST (generates openssl/opensslconf.h), then crypto+ssl (skip apps/tests)
make -C include 2>&1 | tail -2
make -C crypto -j8 2>&1 | grep -iE 'error:|Relocation' | grep -viE 'tbd|Simulator|ld_classic is dep' | head -10
make -C ssl -j8 2>&1 | grep -iE 'error:|Relocation' | grep -viE 'tbd|Simulator|ld_classic is dep' | head -10
make -C include install >/dev/null 2>&1 || true
mkdir -p "$PFX/lib" "$PFX/include"
cp crypto/.libs/libcrypto.a ssl/.libs/libssl.a "$PFX/lib/" 2>/dev/null
cp -R include/openssl "$PFX/include/" 2>/dev/null
echo "=== result ==="; file "$PFX/lib/libcrypto.a" 2>/dev/null | head -1; lipo -archs "$PFX/lib/libcrypto.a" 2>/dev/null
echo "DONE_LIBRESSL_ARMV7"

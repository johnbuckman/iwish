#!/bin/bash
# Cross-compile libcurl (static .a) for armv7 / iOS 9, TLS via the armv7 LibreSSL already built
# for the `tls` package (/tmp/ssl-armv7). Produces curl/lib/.libs/libcurl.a as arm_v7.
# (Secure Transport was tried first but the sparse theos 9.3 SDK lacks CoreServices.framework.)
# Consumed by build-tclcurl-armv7.sh (--with-libcurl).
set -uo pipefail
ROOT=/Users/john/iwish-ios9
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
MINVER=9.0
SSL=${SSL:-/tmp/ssl-armv7}             # armv7 LibreSSL (libssl.a/libcrypto.a + openssl headers)
CC="$ROOT/armv7-toolchain/cc"          # NDK-compile armv7 wrapper (compile only; .a = ar, no link)
WNO="-Wno-undef-prefix -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types -Wno-error=incompatible-pointer-types -Wno-error=deprecated-declarations"
ARCH="-arch armv7 -isysroot $SDK -miphoneos-version-min=$MINVER $WNO"
[ -f "$SSL/lib/libssl.a" ] || { echo "ERROR: no LibreSSL at $SSL — run build-libressl-armv7.sh"; exit 1; }
export ac_cv_sizeof_int=4 ac_cv_sizeof_long=4 ac_cv_sizeof_long_long=8 ac_cv_sizeof_void_p=4 ac_cv_sizeof_size_t=4 ac_cv_sizeof_off_t=8 ac_cv_sizeof_curl_off_t=8
# curl cross-compile: its recv/send/select probes try to LINK (and can't run) -> pre-seed the
# curl-specific cache vars (NOT ac_cv_func_*) with the standard Darwin signatures so they're skipped.
export curl_cv_func_recv=yes curl_cv_func_send=yes curl_cv_func_select=yes
export curl_cv_func_recv_args="int,void *,size_t,int,ssize_t"
export curl_cv_func_send_args="int,const void *,size_t,int,ssize_t"
export curl_cv_func_select_args="int,fd_set *,fd_set *,fd_set *,struct timeval *,int"

cd "$ROOT/src/androwish/jni/curl"
make distclean >/dev/null 2>&1 || true
find lib -name '*.o' -delete 2>/dev/null || true
find lib/.libs -name 'libcurl.a' -delete 2>/dev/null || true

# LibreSSL's libcrypto references <endian.h> be/le fns iOS libc lacks (be32toh, htobe32, …).
# Same shim the tls package uses — compile it and link it into every conftest so curl's
# OpenSSL detection (HMAC_Update in -lcrypto) links, and keep the .o for the TclCurl consumer.
ENDIAN_O="$ROOT/build/endian_armv7.o"
mkdir -p "$ROOT/build"
"$CC" -c $ARCH -fPIC "$ROOT/endian_compat.c" -o "$ENDIAN_O"

export CC
export CFLAGS="$ARCH -fPIC -Os"
export CPPFLAGS="$ARCH -I$(pwd)/include -I$SSL/include"
export LDFLAGS="$ARCH -L$SSL/lib"
export LIBS="-lssl -lcrypto -lz $ENDIAN_O"

./configure \
  --host=arm-apple-darwin --build=arm64-apple-darwin \
  --disable-shared --enable-static \
  --with-ssl="$SSL" \
  --without-libpsl --without-librtmp --without-brotli --without-zstd --without-nghttp2 \
  --disable-ldap --disable-ldaps --disable-manual --disable-verbose \
  --disable-dict --disable-gopher --disable-telnet --disable-tftp --disable-rtsp --disable-smb \
  2>&1 | tail -12
echo "=== CONFIGURE EXIT: ${PIPESTATUS[0]} ==="
echo "=== make (lib only) ==="
make -C lib 2>&1 | grep -iE "error:|Relocation|Bad CPU|\bError [0-9]|undefined|not found" | grep -viE 'ld_classic is dep|tbd file|deprecated' | head -25
echo "=== result ==="
if [ -f lib/.libs/libcurl.a ]; then file lib/.libs/libcurl.a; else echo "NO libcurl.a"; fi
echo "DONE_CURL_ARMV7"

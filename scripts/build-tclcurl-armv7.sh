#!/bin/bash
# Build TclCurl for armv7 / iOS 9, linking against the armv7 static libcurl.a produced by
# build-curl-armv7.sh (Secure Transport TLS). Run build-curl-armv7.sh FIRST.
set -uo pipefail
ROOT=/Users/john/iwish-ios9
CURL="$ROOT/src/androwish/jni/curl"
CURLA="$CURL/lib/.libs/libcurl.a"
if [ ! -f "$CURLA" ] || ! file "$CURLA" | grep -q arm_v7 2>/dev/null; then
  # `file` on a static .a prints per-member; check via a quick lipo/otool fallback
  if ! (lipo -info "$CURLA" 2>/dev/null | grep -qi armv7); then
    echo "ERROR: $CURLA missing or not armv7 — run build-curl-armv7.sh first"; exit 1
  fi
fi
# libcurl.a is just curl's own objects — the TclCurl dylib must also pull in LibreSSL
# (-lssl -lcrypto), zlib, and the endian shim libcrypto needs (be32toh/etc.).
SSL=${SSL:-/tmp/ssl-armv7}
ENDIAN_O="$ROOT/build/endian_armv7.o"
export EXTRA_CFLAGS="-I$CURL/include"
export EXTRA_LDFLAGS="$CURLA -L$SSL/lib -lssl -lcrypto -lz $ENDIAN_O"
bash "$ROOT/build-ext-armv7.sh" "$ROOT/src/androwish/jni/TclCurl" \
  --with-curlinclude="$CURL/include" \
  --with-libcurl="$CURL/lib/.libs"

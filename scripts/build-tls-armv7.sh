#!/bin/bash
# Build tcltls for armv7/iOS9 against the LibreSSL static libs in /tmp/ssl-armv7.
set -uo pipefail
ROOT=/Users/john/iwish-ios9
SDK="$HOME/theos/sdks/iPhoneOS9.3.sdk"
CC="$ROOT/armv7-toolchain/cc"
PFX=/tmp/ssl-armv7
# endian shim (.o) for libcrypto's be32toh/etc.
"$CC" -c -arch armv7 -isysroot "$SDK" -miphoneos-version-min=9.0 -fPIC "$ROOT/endian_compat.c" -o /tmp/endian_armv7.o
echo "endian shim: $(file /tmp/endian_armv7.o | grep -o arm_v7)"
EXTRA_CFLAGS="-I$PFX/include" \
EXTRA_LDFLAGS="-L$PFX/lib -lssl -lcrypto /tmp/endian_armv7.o" \
bash "$ROOT/build-ext-armv7.sh" "$ROOT/src/androwish/jni/tls" \
  --with-ssl-dir="$PFX" --with-openssl-dir="$PFX" \
  CFLAGS="-DNO_SSL2=1 -DNO_SSL3=1" 2>&1 | grep -iE 'CONFIGURE EXIT|error:|Relocation|\.dylib|undefined|symbol.* not found|DONE_EXT' | grep -viE 'tbd|Simulator|ld_classic is dep' | tail -15
echo "=== arch ==="; file "$ROOT/src/androwish/jni/tls/"*.dylib 2>/dev/null | grep -o arm_v7

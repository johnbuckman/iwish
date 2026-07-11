#!/bin/bash
# relocate-frameworks.sh <path/to/iWish.app>
#
# Move every native .dylib extension out of lib-batteries/ (and lib/) into
# Frameworks/ (flat), and rewrite the Tcl `load` paths accordingly.
#
# WHY: AltStore / SideStore re-sign a sideloaded app with the user's Apple ID
# via `ldid`, which signs the main executable and everything in Frameworks/ —
# but NOT dylibs in other folders. iWish used to keep ~63 extension dylibs under
# lib-batteries/, so after an AltStore re-sign those kept their original team's
# signature and iOS rejected the bundle with 0xe8008001 ("failed to verify code
# signature"). Putting every dylib in Frameworks/ makes the re-sign consistent.
#
# The dylibs have no inter-dependencies (each install_name is a bare basename;
# Tcl/Tk is statically linked into the main executable; cross-symbols resolve via
# flat namespace), so they can be flattened with no install_name_tool surgery.
#
# RUN THIS AS THE FINAL STEP, after ALL dylibs (batteries + ble/borg shims) are
# staged, and BEFORE sign-and-install-device.sh / IPA packaging. It is safe to
# re-run (idempotent): already-relocated bundles are left unchanged.
set -euo pipefail
APP="${1:?usage: relocate-frameworks.sh <path/to/iWish.app>}"
FW="$APP/Frameworks"
mkdir -p "$FW"
PERL=/usr/bin/perl   # system perl; avoid any x86-only Homebrew perl/xargs on arm64

echo "=== 1. move every .dylib (flatten) into Frameworks/ (dedup identical) ==="
moved=0; deduped=0
while IFS= read -r f; do
  base=$(basename "$f")
  if [ -e "$FW/$base" ]; then
    if cmp -s "$f" "$FW/$base"; then rm -f "$f"; deduped=$((deduped+1)); continue
    else echo "!! basename collision, different content: $base"; exit 2; fi
  fi
  mv "$f" "$FW/$base"; moved=$((moved+1))
done < <(find "$APP/lib-batteries" "$APP/lib" -name "*.dylib")
echo "moved=$moved deduped=$deduped  Frameworks now has $(find "$FW" -name '*.dylib' | wc -l | tr -d ' ')"

echo "=== 2. rewrite [file join \$dir <name>.dylib] -> ../../Frameworks (guarded) ==="
for t in $(find "$APP/lib-batteries" "$APP/lib" -name '*.tcl'); do
  $PERL -0777 -pi -e 's/\[file join \$dir\s+(?!\.\. \.\. Frameworks)(?:\.\s+)?("?)([^\s\]"]*\.dylib)\1\s*\]/[file join \$dir .. .. Frameworks $1$2$1]/g' "$t"
done

echo "=== 3. special loaders: tls::initlib and the two vfs.tcl (\$::vfs::self / [info script]) ==="
for t in "$APP/lib-batteries/tls/pkgIndex.tcl"; do
  [ -f "$t" ] && $PERL -pi -e 's/tls::initlib \$dir (?!\[file join)(\S+\.dylib)/tls::initlib [file join \$dir .. .. Frameworks] $1/g' "$t"
done
for t in "$APP/lib-batteries/tclvfs/vfs.tcl" "$APP/lib-batteries/vfs1.4.2/vfs.tcl"; do
  [ -f "$t" ] && $PERL -pi -e 's/ (?!\.\. \.\. Frameworks)(libvfs1\.4\.2\.dylib)\]/ .. .. Frameworks $1]/g' "$t"
done

echo "=== 4. sanity checks ==="
stray=$(find "$APP" -name "*.dylib" -not -path "*/Frameworks/*" | wc -l | tr -d ' ')
echo "stray dylibs outside Frameworks: $stray"; [ "$stray" -eq 0 ] || { find "$APP" -name '*.dylib' -not -path '*/Frameworks/*'; exit 3; }
bad=$(grep -rnE '\[file join (\$dir|\$::vfs::self|\[file dirname)[^]]*\.dylib' --include=*.tcl "$APP/lib-batteries" "$APP/lib" 2>/dev/null | grep -vc 'Frameworks' || true)
echo "dylib loads NOT routed via Frameworks: $bad"; [ "$bad" -eq 0 ] || { grep -rnE '\[file join (\$dir|\$::vfs::self|\[file dirname)[^]]*\.dylib' --include=*.tcl "$APP/lib-batteries" "$APP/lib" | grep -v Frameworks; exit 4; }
echo "OK — Frameworks-relocated. Now sign (all Frameworks/*.dylib + exec + app) and package."

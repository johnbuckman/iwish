#!/bin/bash
# relocate-frameworks.sh <path/to/iWish.app>
#
# Wrap every native .dylib extension (from lib-batteries/ and lib/) in its own
# .framework bundle under Frameworks/, and rewrite the Tcl `load` paths.
#
# WHY .framework (not a loose dylib in Frameworks/): AltStore / SideStore re-sign
# a sideloaded app with the user's Apple ID using their pinned `ldid`
# (rileytestut/ldid). That ldid's Sign(folder) only re-signs nested code it
# recognises as a BUNDLE — its regex matches `Frameworks/<name>.framework/…
# Info.plist` and `PlugIns/<name>.appex/…`. A LOOSE `Frameworks/foo.dylib` is not
# a bundle, so ldid does NOT re-sign it; it keeps its original signature and iOS
# rejects the install with 0xe8008001 ("failed to verify code signature"). Each
# dylib therefore needs a real .framework wrapper (dir + Info.plist) so ldid
# re-signs it with the user's team on install.
#
# The dylibs have no inter-dependencies (each install_name is a bare basename;
# Tcl/Tk is statically linked into the main executable; cross-symbols resolve via
# flat namespace), and Tcl `load`s each by explicit path — so no install_name
# surgery is needed.
#
# RUN THIS AS THE FINAL STEP, after ALL dylibs (batteries + ble/borg shims) are
# staged, and BEFORE sign-and-install-device.sh / IPA packaging. Idempotent-ish:
# run once on a freshly-assembled bundle (dylibs still in lib-batteries/).
set -euo pipefail
APP="${1:?usage: relocate-frameworks.sh <path/to/iWish.app>}"
FW="$APP/Frameworks"
mkdir -p "$FW"
PERL=/usr/bin/perl   # system perl; avoid any x86-only Homebrew perl on arm64
MINOS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist" 2>/dev/null || echo 15.0)"

sanitize() { echo "$1" | tr -c 'A-Za-z0-9' '-'; }

mkfw() { # mkfw <dylibfile> ; creates Frameworks/<base>.framework/<base> + Info.plist
  local f="$1" base fwdir
  base=$(basename "$f" .dylib)          # e.g. libble1.0
  fwdir="$FW/$base.framework"
  if [ -d "$fwdir" ]; then              # collision (e.g. the two identical libvfs)
    if cmp -s "$f" "$fwdir/$base"; then rm -f "$f"; return 0
    else echo "!! framework collision, different content: $base"; exit 2; fi
  fi
  mkdir -p "$fwdir"
  mv "$f" "$fwdir/$base"
  cat > "$fwdir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$base</string>
<key>CFBundleIdentifier</key><string>org.iwish.fw.$(sanitize "$base")</string>
<key>CFBundleName</key><string>$base</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
<key>MinimumOSVersion</key><string>$MINOS</string>
</dict></plist>
PLIST
}

echo "=== 1. wrap every .dylib in a .framework under Frameworks/ ==="
n=0
while IFS= read -r f; do mkfw "$f"; n=$((n+1)); done < <(find "$APP/lib-batteries" "$APP/lib" -name "*.dylib")
echo "processed $n dylibs -> $(find "$FW" -maxdepth 1 -name '*.framework' | wc -l | tr -d ' ') frameworks"

echo "=== 2. rewrite [file join \$dir X.dylib] -> [file join \$dir .. .. Frameworks X.framework Xbase] ==="
for t in $(find "$APP/lib-batteries" "$APP/lib" -name '*.tcl'); do
  # [file join $dir (.)? ("?)libFOO.dylib("?)]  ->  [file join $dir .. .. Frameworks libFOO.framework libFOO]
  $PERL -0777 -pi -e 's{\[file join \$dir\s+(?!\.\. \.\. Frameworks)(?:\.\s+)?"?((?:lib)?[^\s\]"/]*?)\.dylib"?\s*\]}{[file join \$dir .. .. Frameworks $1.framework $1]}g' "$t"
done

echo "=== 3. special loaders: tls::initlib and the two vfs.tcl ==="
# tls: tls::initlib $dir libtls1.6.9.dylib  ->  tls::initlib [file join $dir .. .. Frameworks libtls1.6.9.framework] libtls1.6.9
for t in "$APP/lib-batteries/tls/pkgIndex.tcl"; do
  [ -f "$t" ] && $PERL -pi -e 's{tls::initlib \$dir (?!\[file join)("?)((?:lib)?[^\s"]*?)\.dylib\1}{tls::initlib [file join \$dir .. .. Frameworks $2.framework] $2}g' "$t"
done
# vfs: [file join <dirvar> libvfs1.4.2.dylib] -> [file join <dirvar> .. .. Frameworks libvfs1.4.2.framework libvfs1.4.2]
for t in "$APP/lib-batteries/tclvfs/vfs.tcl" "$APP/lib-batteries/vfs1.4.2/vfs.tcl"; do
  [ -f "$t" ] && $PERL -pi -e 's{ (?!\.\. \.\. Frameworks)(lib)?vfs1\.4\.2\.dylib\]}{ .. .. Frameworks ${1}vfs1.4.2.framework ${1}vfs1.4.2]}g' "$t"
done

echo "=== 4. sanity checks ==="
stray=$(find "$APP" -name "*.dylib" | wc -l | tr -d ' ')
echo "any .dylib files remaining anywhere: $stray (want 0 — all became .framework execs)"
[ "$stray" -eq 0 ] || { find "$APP" -name '*.dylib'; exit 3; }
bad=$(grep -rnE '\.dylib' --include=*.tcl "$APP/lib-batteries" "$APP/lib" 2>/dev/null | grep -iE 'load|initlib' | grep -vE 'filetype|\{\.|lsearch|pattern|dll' | wc -l | tr -d ' ')
echo "load lines still mentioning .dylib: $bad (want 0)"
[ "$bad" -eq 0 ] || { grep -rnE '\.dylib' --include=*.tcl "$APP/lib-batteries" "$APP/lib" | grep -iE 'load|initlib' | grep -vE 'filetype|\{\.|lsearch|pattern|dll'; exit 4; }
echo "OK — framework-wrapped. Sign every Frameworks/*.framework + exec + app, then package."

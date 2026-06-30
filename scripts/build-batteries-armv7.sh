#!/bin/bash
# Assemble all built armv7 dylibs (+ their pkgIndex.tcl + library scripts) into
# dist/iWish-batteries-armv7/lib/<pkg>/. Each TEA pkgIndex uses [file join $dir ...] so
# co-locating dylib+pkgIndex makes `package require` work.
set -uo pipefail
ROOT=/Users/john/iwish-ios9
JNI=$ROOT/src/androwish/jni
OUT=$ROOT/dist/iWish-batteries-armv7/lib
rm -rf "$OUT"; mkdir -p "$OUT"
n=0
# Every dir under jni (+ shims + blt) that produced an armv7 dylib alongside a pkgIndex.tcl
for dy in $(rtk proxy find "$JNI" -name '*.dylib'); do
  d=$(dirname "$dy")
  file "$dy" | grep -q arm_v7 || continue
  pk="$d/pkgIndex.tcl"
  [ -f "$pk" ] || continue
  # package dir name = basename of the dir (e.g. tdom, libjpeg->jpegtcl handled by pkgIndex)
  name=$(basename "$d")
  dest="$OUT/$name"; mkdir -p "$dest"
  cp "$dy" "$dest/" 2>/dev/null
  cp "$pk" "$dest/" 2>/dev/null
  # companion scripts. pkgIndex/Init reference them as [file join $dir X.tcl] (flat) or a
  # subdir (e.g. template/). Source scatters them in src/ lib/ library/ library/<sub>/.
  # (1) flatten src/lib/library *.tcl to the package root (ral.tcl, csv.tcl, trofs.tcl, ...)
  for sub in src lib library; do for t in "$d/$sub"/*.tcl; do [ -f "$t" ] && cp "$t" "$dest/" 2>/dev/null; done; done
  # (2) mirror subdirs under library/ to the package root (tclvfs library/template -> dest/template)
  if [ -d "$d/library" ]; then for sd in "$d/library"/*/; do [ -d "$sd" ] && cp -R "$sd" "$dest/" 2>/dev/null; done; fi
  # (3) catch-all: preserve any other *.tcl structure
  rsync -a --include='*/' --include='*.tcl' --exclude='*' "$d/" "$dest/" 2>/dev/null
  n=$((n+1))
done
# shims (borg/ble) + BLT: hand-place with a generated pkgIndex
mkdir -p "$OUT/borg1.0"; cp "$ROOT/borg-ios/libborg1.0.dylib" "$OUT/borg1.0/" 2>/dev/null
echo 'package ifneeded Borg 1.0 [list apply {{dir} { load [file join $dir libborg1.0.dylib] Borg; package provide Borg 1.0 }} $dir]' > "$OUT/borg1.0/pkgIndex.tcl"
mkdir -p "$OUT/ble1.0"; cp "$ROOT/ble-ios/libble1.0.dylib" "$OUT/ble1.0/" 2>/dev/null
echo 'package ifneeded Ble 1.0 [list apply {{dir} { load [file join $dir libble1.0.dylib] Ble; package provide Ble 1.0 }} $dir]' > "$OUT/ble1.0/pkgIndex.tcl"
BLTSO=$(rtk proxy find "$JNI/blt" -name 'libBLT24.so' | head -1)
if [ -n "$BLTSO" ]; then mkdir -p "$OUT/BLT2.4"; cp "$BLTSO" "$OUT/BLT2.4/"; echo 'package ifneeded BLT 2.4 [list load [file join $dir libBLT24.so] BLT]' > "$OUT/BLT2.4/pkgIndex.tcl"; fi
# ---- pure-Tcl packages from assets/ (arch-free: snit, json, tcllib, http, lambda, huddle,
# mqtt, bwidget, ...). Skip any whose pkgIndex does a bare `load` of a native lib (those are
# Android monolith stubs that would shadow / fail) and any name a native dylib pkg already provides.
ASSETS=$ROOT/src/androwish/assets
purec=0
for ad in "$ASSETS"/*/; do
  [ -d "$ad" ] || continue
  name=$(basename "$ad")
  pk="$ad/pkgIndex.tcl"
  [ -f "$pk" ] || continue
  # skip if it loads a shared lib (native stub) -> our built dylib packages cover those
  if grep -qE 'load .*(\[info sharedlibextension\]|\.so|\.dylib|lib[A-Za-z])' "$pk"; then continue; fi
  [ -d "$OUT/$name" ] && continue   # native build already staged this dir name
  cp -R "$ad" "$OUT/$name" 2>/dev/null
  purec=$((purec+1))
done
echo "assembled $n native TEA packages + borg/ble/BLT + $purec pure-Tcl packages into $OUT"
echo "package dirs: $(ls "$OUT" | wc -l)"
ls "$OUT"

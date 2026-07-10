#!/bin/bash
# Stage AndroWish "batteries" (builtin demo apps + their pure-Tcl support pkgs)
# into the DEVICE app bundle iWishBare.app/lib-batteries so the Console File>Demos
# menu can run them on the iPad. Pure-Tcl only here (Phase 1); C-extension demos
# get their iphoneos dylibs added by later phases.
set -uo pipefail
ROOT=/Users/john/iwish
AW=$ROOT/src/androwish
ASSETS=$AW/assets
APP=$ROOT/dist/iWish.app
LB=$APP/lib-batteries
mkdir -p "$LB"

copy() { # copy <src-glob> [destname]
  local src dst
  src=$(ls -d $1 2>/dev/null | head -1)
  if [ -z "$src" ]; then echo "  MISS  $1"; return 1; fi
  dst="$LB/${2:-$(basename "$src")}"
  rm -rf "$dst"; cp -R "$src" "$dst" && echo "  ok    ${2:-$(basename "$src")}"
}

echo "=== Phase 1: pure-Tcl apps + support packages ==="
# --- builtin demo apps (pure Tcl/Tk) ---
copy "$ASSETS/tkcon2.7"
copy "$ASSETS/tkinspect5.1.6"
# calc0 NOT bundled: calc -> yeti/ylex requires Itcl (C ext) -> add in Phase 2
copy "$ASSETS/TkMC1.0"
copy "$ASSETS/tkbugz"
# --- Tk widget demo (ships with sdl2tk) ---
copy "$AW/jni/sdl2tk/library/demos" tkdemos
# --- pure-Tcl support packages ---
copy "$ASSETS/tcllib1.21"       # comm (tkinspect), textutil, snit, base64, ...
# fix tcllib struct pkgIndex version skew (declares 2.1, struct.tcl provides 2.2)
sed -i '' 's/ifneeded struct            2.1/ifneeded struct            2.2/' "$LB/tcllib1.21/struct/pkgIndex.tcl" 2>/dev/null || true
copy "$ASSETS/tklib0.7"         # wcb + ctext (calc), many widgets
copy "$ASSETS/bwidget1.9"       # notebook/stardom (later) + general
copy "$ASSETS/fsdialog1.15"     # tkmc
copy "$ASSETS/yeti0.4.2"        # calc (yeti + ylex)

# === Phase 2: C-extension demos (iphoneos dylibs) ==========================
# Build the dylibs first (once):  bash build-ext-dev.sh <srcdir> [args]
#   itcl     : jni/tcl/pkgs/itcl4.2.0
#   sqlite3  : jni/tcl/pkgs/sqlite3.45.1   (EXTRA_CFLAGS=-Dpread64=pread -Dpwrite64=pwrite
#              -Wno-implicit-int -Wno-implicit-function-declaration -Wno-error ; ac_cv_func_strchrnul=no)
#   tdom     : jni/tdom                    (MUST match device TCL_UTF_MAX=6, harness sets it)
#   tktable  : jni/tktable
#   treectrl : jni/tktreectrl              (dylib name libtreectrl2.4.dylib)
#   zint     : jni/zint/backend_tcl
JNI=$AW/jni; CAT=$ROOT/dist/iWish-batteries/lib
stage_ext() { # <catalyst-dir> <staged-name> <device-dylib>
  [ -f "$3" ] || { echo "  MISS dylib $3 (build it: build-ext-dev.sh)"; return 1; }
  rm -rf "$LB/$2"; cp -R "$CAT/$1" "$LB/$2"
  cp "$3" "$LB/$2/$(basename "$3")"   # overwrite the macabi dylib with the IOS one
  echo "  ext $2: $(vtool -show-build "$LB/$2/$(basename "$3")" 2>/dev/null | grep -oE 'IOS|MACCATALYST' | head -1)"
}
echo "=== Phase 2: C-ext packages (IOS dylibs) ==="
stage_ext itcl       itcl4.2.0   "$JNI/tcl/pkgs/itcl4.2.0/libitcl4.2.0.dylib"
stage_ext sqlite3    sqlite3     "$JNI/tcl/pkgs/sqlite3.45.1/libsqlite3.45.1.dylib"
stage_ext tdom       tdom0.9     "$JNI/tdom/libtdom0.9.3.dylib"
stage_ext Tktable    Tktable2.11 "$JNI/tktable/libTktable2.11.dylib"
stage_ext tktreectrl treectrl2.4 "$JNI/tktreectrl/libtreectrl2.4.dylib"
stage_ext zint       zint2.13    "$JNI/zint/backend_tcl/libzint2.13.0.dylib"
# demo scripts + companions
cp -R "$JNI/tktable/demos"    "$LB/Tktable2.11/demos" 2>/dev/null
cp -R "$JNI/tktreectrl/demos" "$LB/treectrl2.4/demos" 2>/dev/null
# treectrl.tcl does an UNCAUGHT `source filelist-bindings.tcl` relative to its own
# dir -> the companions must sit FLAT next to treectrl.tcl (not in a library/ subdir).
cp "$JNI/tktreectrl/library/"*.tcl "$LB/treectrl2.4/" 2>/dev/null
cp "$ASSETS/zint2.13/demo.tcl" "$LB/zint2.13/demo.tcl" 2>/dev/null
# standalone demo apps that use the above exts
for a in tksqlite0.5.13 stardom0.42 calc0; do rm -rf "$LB/$a"; cp -R "$ASSETS/$a" "$LB/$a"; done
# NOTE: main.tcl must set ::treectrl_library + ITCL_LIBRARY/TREECTRL_LIBRARY env
# (tcl_findLibrary); see ~/iwish/main-device.tcl.

# === Phase 3: image/graphical C-ext demos =================================
# Build first (once):
#   Img:    EXTRA_CFLAGS="-DPNG_ARM_NEON_OPT=0" build-ext-dev.sh jni/tkimg
#           (5 niche formats raw/dted/flir/xbm/xpm need a direct `make` in their
#            subdir afterward — top make skips them; Img meta-pkg requires them)
#   tkpath: build-ext-dev.sh jni/tkpath ; then in Makefile swap the host SDL
#           include -I/usr/local/include/SDL2 -> -I$ROOT/dist/sdl-dev/include/SDL2
#           and -L/opt/local/lib -lfreetype -> -L$ROOT/dist/ft-dev/lib -lfreetype ; make
#   tkvnc:  build-ext-dev.sh jni/tkvnc
echo "=== Phase 3: Img + tkpath + tkvnc ==="
# Img: reuse Catalyst pkgIndex, swap ALL 24 dylibs to the IOS builds
rm -rf "$LB/Img1.4.11"; cp -R "$CAT/Img1.4.11" "$LB/Img1.4.11"
for dl in "$LB/Img1.4.11/"*.dylib; do d=$(find "$JNI/tkimg" -name "$(basename "$dl")" 2>/dev/null|head -1); [ -n "$d" ] && cp "$d" "$dl"; done
cp "$JNI/tkimg/demo.tcl" "$LB/Img1.4.11/demo.tcl"
# tkpath
rm -rf "$LB/tkpath0.3.3"; cp -R "$CAT/tkpath" "$LB/tkpath0.3.3"
cp "$JNI/tkpath/libtkpath0.3.3.dylib" "$LB/tkpath0.3.3/"; cp -R "$JNI/tkpath/demos" "$LB/tkpath0.3.3/demos"
# tkvnc (no Catalyst dir): assets vnc demo + device package
rm -rf "$LB/vnc0.5"; cp -R "$ASSETS/vnc0.5" "$LB/vnc0.5"
cp "$JNI/tkvnc/libvnc0.5.dylib" "$LB/vnc0.5/"; cp "$JNI/tkvnc/pkgIndex.tcl" "$LB/vnc0.5/pkgIndex.tcl"
# standalone demo apps + pure-Tcl deps
for a in notebook2.2 tkchat1.500 touchcal0.1; do rm -rf "$LB/$a"; cp -R "$ASSETS/$a" "$LB/$a"; done
echo "  Phase-3 platforms: $(for f in "$LB/Img1.4.11/"*.dylib "$LB/tkpath0.3.3/"*.dylib "$LB/vnc0.5/"*.dylib; do vtool -show-build "$f" 2>/dev/null|grep -oE 'IOS|MACCATALYST'|head -1; done | sort | uniq -c | tr '\n' ' ')"
# STILL GREYED (infeasible on iOS): helpviewer(BLT/tkdnd/hv3), vectclab(vectcl),
# tixwidgets/tixtour(Tix/X11), zinc-widget(Tkzinc/GL), 3ddemo(Canvas3d/GL),
# dungfork(augeas), fuse(libfuse). tls not built (tkchat's tls is optional/catch).

echo "=== staged under $LB ==="
ls "$LB"
echo "DONE_BATTERIES_STAGING"

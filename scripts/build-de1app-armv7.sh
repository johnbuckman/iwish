#!/bin/bash
# Assemble + ldid-sign dist/IwishDE1-armv7.app for the jailbroken iPad mini 1 (iOS 9.3.5).
# de1app for armv7. The de1plus source tree (433M) does NOT ship inside the app bundle
# (system / has only ~196M free); it is deployed separately to /private/var/de1plus and
# the launcher sources it from there. The app bundle carries only: the armv7 sdl2wish
# (renamed IwishDE1), the Tcl/Tk script libraries, the armv7 batteries, libhardexit, a
# thin launcher main.tcl, an Info.plist (com.decent.de1app, BLE + landscape), icons.
set -euo pipefail
ROOT=/Users/john/iwish-ios9
AW=$ROOT/src/androwish/jni
APP=$ROOT/dist/IwishDE1-armv7.app
WISH=$AW/sdl2tk/sdl/sdl2wish
BAT=$ROOT/dist/iWish-batteries-armv7/lib
REF=/Users/john/iwish/dist/IwishDE1dev.app
BID=com.decent.de1app
DE1ROOT=/private/var/de1plus     # where de1plus is deployed on-device

file "$WISH" | grep -q arm_v7 || { echo "ERROR: sdl2wish not armv7"; exit 1; }
[ -d "$BAT" ] || { echo "ERROR: batteries not built ($BAT)"; exit 1; }
[ -f "$ROOT/libhardexit.dylib" ] || { echo "ERROR: libhardexit.dylib missing"; exit 1; }

rm -rf "$APP"; mkdir -p "$APP/lib"
cp "$WISH" "$APP/IwishDE1"
cp "$ROOT/libhardexit.dylib" "$APP/libhardexit.dylib"
cp -R "$AW/tcl/library"    "$APP/lib/tcl8.6"
cp -R "$AW/sdl2tk/library" "$APP/lib/tk8.6"
cp -R "$BAT"               "$APP/lib-batteries"

# de1app's utils.tcl `ios_install_hardexit` package-requires hardexit; give it a pkgIndex
mkdir -p "$APP/lib-batteries/hardexit"
cp "$ROOT/libhardexit.dylib" "$APP/lib-batteries/hardexit/"
cat > "$APP/lib-batteries/hardexit/pkgIndex.tcl" <<'PK'
package ifneeded hardexit 1.0 [list load [file join $dir libhardexit.dylib] Hardexit]
PK

# icons (arch-independent) from the arm64 reference, if present
for f in AppIcon60x60@2x.png AppIcon76x76@2x~ipad.png Assets.car; do
  [ -e "$REF/$f" ] && cp "$REF/$f" "$APP/" 2>/dev/null || true
done

# ---- thin launcher (models the arm64 IwishDE1dev main.tcl, but sources de1plus from
# $DE1ROOT on /private/var instead of from inside the bundle). ios.tcl recomputes
# $::home via `file dirname [info script]`, so it resolves to $DE1ROOT automatically.
cat > "$APP/main.tcl" <<TCL
# IwishDE1 armv7 / iOS9 launcher -- THIN bootstrap. de1plus lives on $DE1ROOT (not in
# the bundle: system / is too full for the 433M tree). Script libs + native batteries
# ship in the bundle. de1app.tcl detects iWish via borg, redirects writable root to
# ~/Documents/Decent, and installs the hardexit handler itself.
set _docs [file normalize ~/Documents]
catch {file mkdir \$_docs}
set ::_log [open [file join \$_docs de1_launch.log] w]; fconfigure \$::_log -buffering none
proc L {m} { catch {puts \$::_log \$m} }
L "IwishDE1 armv7 launcher: tcl=[info patchlevel]"

set bundle [file dirname [info nameofexecutable]]
set de1root "$DE1ROOT"
L "bundle=\$bundle de1root=\$de1root"

if {![info exists ::tcl_library] || ![file isdirectory \$::tcl_library]} { set ::tcl_library [file join \$bundle lib tcl8.6] }
if {![info exists ::tk_library]  || ![file isdirectory \$::tk_library]}  { set ::tk_library  [file join \$bundle lib tk8.6] }
if {[catch {uplevel #0 [list source [file join \$::tcl_library init.tcl]]} _ie]} { L "init.tcl re-source err: \$_ie" }
if {\$::tk_library ni \$::auto_path} { lappend ::auto_path \$::tk_library }

# native-extension batteries (read-only, from the bundle). recursive: tcllib modules nest.
set bat [file join \$bundle lib-batteries]
proc _addpaths {dir} {
    if {[file exists [file join \$dir pkgIndex.tcl]]} { lappend ::auto_path \$dir }
    foreach sub [glob -nocomplain -type d -directory \$dir *] { _addpaths \$sub }
}
lappend ::auto_path \$bat
_addpaths \$bat
foreach {p v} {itcl ITCL_LIBRARY itk ITK_LIBRARY tktreectrl TREECTRL_LIBRARY vu VU_LIBRARY} {
    if {[file isdirectory [file join \$bat \$p]]} { set ::env(\$v) [file join \$bat \$p] }
}
if {[file isdirectory [file join \$bat tktreectrl]]} { set ::treectrl_library [file join \$bat tktreectrl] }

cd \$de1root
encoding system utf-8
L "sourcing de1plus.tcl from \$de1root"
if {[catch {uplevel #0 [list source [file join \$de1root de1plus.tcl]]} e]} {
    L "DE1 ERROR: \$e"; L "--- errorInfo ---"; L \$::errorInfo
} else { L "de1plus.tcl sourced ok" }
L "launcher done; event loop"
TCL

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>IwishDE1</string>
  <key>CFBundleIdentifier</key><string>${BID}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>IwishDE1</string>
  <key>CFBundleDisplayName</key><string>DE1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFiles</key><array><string>AppIcon60x60</string><string>AppIcon76x76</string></array>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>MinimumOSVersion</key><string>9.0</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
  <key>DTPlatformName</key><string>iphoneos</string>
  <key>DTPlatformVersion</key><string>9.3</string>
  <key>DTSDKName</key><string>iphoneos9.3</string>
  <key>UIDeviceFamily</key><array><integer>2</integer></array>
  <key>UIRequiredDeviceCapabilities</key><array><string>armv7</string></array>
  <key>NSBluetoothAlwaysUsageDescription</key><string>DE1 connects to your espresso machine over Bluetooth.</string>
  <key>NSBluetoothPeripheralUsageDescription</key><string>DE1 connects to your espresso machine over Bluetooth.</string>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>com.decent.de1app</string>
    <key>CFBundleURLSchemes</key><array><string>de1app</string></array>
  </dict></array>
  <key>UIStatusBarHidden</key><true/>
  <!-- Let SDL's view controller govern the status bar (it returns
       prefersStatusBarHidden=YES). The explicit setStatusBarHidden fallback in
       SDL's app delegate + view controller handles iOS 9 where the plist key
       alone is ignored. -->
  <key>UIViewControllerBasedStatusBarAppearance</key><true/>
  <key>UIRequiresFullScreen</key><true/>
  <key>UISupportedInterfaceOrientations~ipad</key>
  <array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
</dict></plist>
PLIST

cat > "$ROOT/IwishDE1.entitlements" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>platform-application</key><true/>
  <key>com.apple.private.security.no-container</key><true/>
  <key>get-task-allow</key><true/>
  <key>dynamic-codesigning</key><true/>
</dict></plist>
ENT

xattr -cr "$APP" 2>/dev/null || true
ldid -S"$ROOT/IwishDE1.entitlements" "$APP/IwishDE1"
ldid -S"$ROOT/IwishDE1.entitlements" "$APP/libhardexit.dylib" 2>/dev/null || true
echo "BUILT: $APP"
du -sh "$APP"
echo "--- component sizes ---"
du -sh "$APP"/* 2>/dev/null | sort -h
file "$APP/IwishDE1"
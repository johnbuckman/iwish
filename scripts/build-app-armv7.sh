#!/bin/bash
# Assemble + ldid-sign dist/iWish-armv7.app for the jailbroken iPad mini 1 (iOS 9.3.5).
# Bundles: iWish(=sdl2wish), tclsh(armv7, for Tcl regression over SSH), lib/{tcl8.6,tk8.6},
# the Tcl + Tk test suites, and a dispatcher main.tcl (demo, or runs a regression on a flag).
set -euo pipefail
ROOT=/Users/john/iwish-ios9
AW=$ROOT/src/androwish/jni
APP=$ROOT/dist/iWish-armv7.app
WISH=$AW/sdl2tk/sdl/sdl2wish
TCLSH=$ROOT/build/awtcl-armv7/tclsh
BID=org.iwish.tk

file "$WISH" | grep -q arm_v7 || { echo "ERROR: sdl2wish not armv7 (run build-device-armv7.sh)"; exit 1; }

rm -rf "$APP"; mkdir -p "$APP/lib"
cp "$WISH" "$APP/iWish"
cp "$TCLSH" "$APP/tclsh"
cp -R "$AW/tcl/library"        "$APP/lib/tcl8.6"
cp -R "$AW/sdl2tk/library"     "$APP/lib/tk8.6"
# test suites
cp -R "$AW/tcl/tests"          "$APP/tests-tcl"
cp -R "$AW/sdl2tk/tests"       "$APP/tests-tk"

# dispatcher main.tcl (auto-run on SpringBoard launch via the tkAppInit no-arg block)
cat > "$APP/main.tcl" <<'TCL'
# iWish armv7 / iOS 9 launcher. Flag-driven so one bundle can demo OR run regressions.
set base [file dirname [info nameofexecutable]]
proc log {m} { set f [open "/tmp/iwish_run.log" a]; puts $f $m; close $f }
catch {log "main.tcl start: tcl [info patchlevel]"}

if {[file exists /tmp/iwish_runtk]} {
    # Tk regression suite — runs under SpringBoard (real GUI). Crash-resilient + resumable:
    # per-file flushed progress + a done-list so a relaunch resumes past a crasher.
    catch {log "running Tk suite"}
    set dir $base/tests-tk
    # bgerror -> log, never pop a modal dialog (those block the whole suite in sdl2tk)
    proc bgerror {m} { catch {set f [open /tmp/iwish_bgerror.log a]; puts $f $m; close $f} }
    # skip: modal/dialog/WM/embed tests that hang headless + winfo.test (sdl2tk atom-as-pointer
    # crash on winfo atomname <int>) + any extra from /tmp/iwish_skip
    set skip {choosedir.test filebox.test clrpick.test msgbox.test winDialog.test send.test \
              xmfbox.test unixWm.test wm.test macWm.test unixEmbed.test macEmbed.test embed.test \
              focus.test grab.test select.test clipboard.test unixSelect.test visual.test \
              safe.test bgerror.test winfo.test}
    catch {set fh [open /tmp/iwish_skip r]; lappend skip {*}[read $fh]; close $fh}
    # resume: files already completed in a prior run
    set done {}
    catch {set fh [open /tmp/iwish_done_files r]; set done [read $fh]; close $fh}
    # runAllTests emits the per-file "foo.test: Total N Passed.." tally lines (cleanupTests
    # in standalone mode does not). Neuter exit so the final cleanupTests can't kill us
    # before we write the done flag.
    cd $dir
    set ::argv [list -outfile /tmp/iwish_tk_results.txt -notfile $skip]
    set ::argc [llength $::argv]
    rename exit ::__real_exit
    proc exit {args} {}
    if {[catch {uplevel #0 [list source [file join $dir all.tcl]]} err]} {
        catch {log "tk suite error: $err"}
    }
    set f [open /tmp/iwish_tk_done w]; puts $f done; close $f
    ::__real_exit 0
}

# default: a simple Tk demo proving rendering works
wm title . "iWish armv7 / iOS9"
label .l -text "iWish on iOS 9 (armv7)\nTcl/Tk [info patchlevel]" -font {Helvetica 28} -justify center
pack .l -expand 1 -fill both -padx 20 -pady 20
button .b -text "Tap me" -font {Helvetica 24} -command {.l configure -text "Tapped!\nTk works on iPad mini 1"}
pack .b -pady 20
catch {log "demo UI built"}
TCL

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>iWish</string>
  <key>CFBundleIdentifier</key><string>${BID}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>iWish</string>
  <key>CFBundleDisplayName</key><string>iWish</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>MinimumOSVersion</key><string>9.0</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
  <key>DTPlatformName</key><string>iphoneos</string>
  <key>DTPlatformVersion</key><string>9.3</string>
  <key>DTSDKName</key><string>iphoneos9.3</string>
  <key>UIDeviceFamily</key><array><integer>2</integer></array>
  <key>UIRequiredDeviceCapabilities</key><array><string>armv7</string></array>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>org.iwish.tk</string>
    <key>CFBundleURLSchemes</key><array><string>iwish</string></array>
  </dict></array>
  <key>UIStatusBarHidden</key><true/>
  <key>UISupportedInterfaceOrientations~ipad</key>
  <array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
  </array>
</dict></plist>
PLIST

cat > "$ROOT/iWish.entitlements" <<'ENT'
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
ldid -S"$ROOT/iWish.entitlements" "$APP/iWish"
ldid -S"$ROOT/iWish.entitlements" "$APP/tclsh"
echo "BUILT: $APP"
du -sh "$APP"; file "$APP/iWish" "$APP/tclsh"

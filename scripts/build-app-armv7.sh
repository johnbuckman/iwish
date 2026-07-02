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

if {[file exists /tmp/iwish_runbat]} {
    # Battery load-test under wish (Tk present). Tests every package incl. Tk exts.
    set lib /tmp/iWish-batteries-armv7/lib
    # recursive auto_path: every dir with a pkgIndex (tcllib modules are nested e.g. tcllib1.21/snit)
    proc addpaths {dir} {
        foreach sub [glob -nocomplain -type d -directory $dir *] {
            if {[file exists [file join $sub pkgIndex.tcl]]} { lappend ::auto_path $sub }
            addpaths $sub
        }
    }
    addpaths $lib
    foreach {var dir} {ITCL_LIBRARY itcl4.2.0 ITK_LIBRARY itk TREECTRL_LIBRARY tktreectrl VU_LIBRARY vu TROFS_LIBRARY trofs} {
        if {[file isdirectory $lib/$dir]} { set ::env($var) $lib/$dir }
    }
    set out [open /tmp/iwish_bat_results.txt a]; fconfigure $out -buffering none
    set pkgs {}
    foreach pf [lsort [glob -nocomplain -directory $lib -join * pkgIndex.tcl]] {
        set fh [open $pf]; set txt [read $fh]; close $fh
        foreach {m name ver} [regexp -all -inline {package ifneeded (\S+) (\S+)} $txt] { lappend pkgs $name }
    }
    # also nested (tcllib modules)
    foreach pf [glob -nocomplain -directory $lib -join * * pkgIndex.tcl] {
        set fh [open $pf]; set txt [read $fh]; close $fh
        foreach {m name ver} [regexp -all -inline {package ifneeded (\S+) (\S+)} $txt] { lappend pkgs $name }
    }
    # crash-resumable: a segfaulting package would abort the run; record the current pkg
    # (flushed) so a relaunch can skip it, and persist a done-set to resume.
    set skip {}; catch {set fh [open /tmp/iwish_bat_skip r]; set skip [read $fh]; close $fh}
    set done {}; catch {set fh [open /tmp/iwish_bat_done_pkgs r]; set done [read $fh]; close $fh}
    set ok 0; set fail 0
    foreach name [lsort -unique $pkgs] {
        if {[lsearch -exact $skip $name] >= 0} { puts $out "SKIP $name"; continue }
        if {[lsearch -exact $done $name] >= 0} { continue }
        set cf [open /tmp/iwish_bat_cur w]; puts $cf $name; close $cf
        if {[catch {package require $name} e]} { puts $out "FAIL $name: [string range $e 0 80]"; incr fail } else { puts $out "OK   $name"; incr ok }
        set df [open /tmp/iwish_bat_done_pkgs a]; puts $df $name; close $df
    }
    puts $out "=== batteries: $ok ok, $fail fail (this run) ==="; close $out
    set f [open /tmp/iwish_bat_done w]; puts $f done; close $f
    exit 0
}

# default: start up like desktop wish on macOS — an interactive Tk console plus an
# empty main window. The console channels are already initialised (PLATFORM_SDL sets
# docon=1 in tkMain.c) and Tk_CreateConsoleWindow ran in AppInit, but tkMain.c does
# `console hide` whenever a startup script (this main.tcl) is present — so just re-show it.

# --- unix-like convenience commands for the console -------------------------
# The Tk console evaluates typed commands in THIS (main) interp. `ls`/`cat` etc.
# aren't Tcl commands; the usual `unknown`->exec fallback is useless here (a
# SpringBoard-launched app can't reliably fork/exec, and the device busybox lacks
# head/tail/wc/tr anyway). Provide pure-Tcl equivalents (cd/pwd are built in).
proc ls {args} {
    set long 0; set dir [pwd]; set pats {}
    foreach a $args {
        if {$a in {-l -la -al -ll}} { set long 1 } elseif {[file isdirectory $a]} {
            set dir $a
        } else { lappend pats $a }
    }
    if {![llength $pats]} { set pats [list *] }
    set files {}
    foreach p $pats { lappend files {*}[glob -nocomplain -directory $dir $p] }
    set out {}
    foreach f [lsort -unique $files] {
        set name [file tail $f]
        if {[file isdirectory $f]} { append name / }
        if {$long} {
            set sz [expr {[file isdirectory $f] ? 0 : [file size $f]}]
            lappend out [format "%10d  %s" $sz $name]
        } else { lappend out $name }
    }
    return [join $out \n]
}
interp alias {} dir {} ls
interp alias {} ll  {} ls -l
proc cat {args} {
    set out {}
    foreach f $args { set fp [open $f r]; lappend out [read $fp]; close $fp }
    return [join $out ""]
}
interp alias {} more {} cat
interp alias {} less {} cat
proc _slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }
proc _headtail {which args} {
    set n 10; set files {}
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        if {$a eq "-n"} { set n [lindex $args [incr i]] } \
        elseif {[regexp {^-([0-9]+)$} $a -> num]} { set n $num } \
        else { lappend files $a }
    }
    set out {}
    foreach f $files {
        set lines [split [string trimright [_slurp $f] \n] \n]
        if {$which eq "head"} { lappend out {*}[lrange $lines 0 [expr {$n-1}]] } \
        else { lappend out {*}[lrange $lines end-[expr {$n-1}] end] }
    }
    return [join $out \n]
}
proc head {args} { _headtail head {*}$args }
proc tail {args} { _headtail tail {*}$args }
proc grep {pattern args} {
    set out {}
    foreach f $args {
        set ln 0
        foreach line [split [_slurp $f] \n] {
            incr ln
            if {[regexp -- $pattern $line]} { lappend out "$f:$ln:$line" }
        }
    }
    return [join $out \n]
}
proc wc {args} {
    set out {}
    foreach f $args {
        set d [_slurp $f]
        lappend out [format "%7d %7d %7d  %s" \
            [llength [split [string trimright $d \n] \n]] \
            [llength [regexp -all -inline {\S+} $d]] [string length $d] $f]
    }
    return [join $out \n]
}
proc rm {args} {
    set rec 0; set files {}
    foreach a $args {
        switch -- $a { -f {} -r - -rf - -fr {set rec 1} default {lappend files $a} }
    }
    foreach f $files { if {$rec} { file delete -force $f } else { file delete $f } }
    return ""
}
proc cp {args} { set d [lindex $args end]; foreach s [lrange $args 0 end-1] { file copy -force $s $d }; return "" }
proc mv {args} { set d [lindex $args end]; foreach s [lrange $args 0 end-1] { file rename -force $s $d }; return "" }
proc mkdir {args} { foreach d $args { file mkdir $d }; return "" }
proc touch {args} { foreach f $args { if {![file exists $f]} { close [open $f a] } }; return "" }
proc echo {args} { return [join $args " "] }
proc env {} { set o {}; foreach k [lsort [array names ::env]] { lappend o "$k=$::env($k)" }; return [join $o \n] }
proc which {cmd} {
    if {[llength [info commands $cmd]]} { return "$cmd: Tcl/console command" } \
    else { return "$cmd: not found (external programs can't reliably run from the app)" }
}

wm title . "iWish"
if {[catch {console show} err]} { catch {log "console show failed: $err"} }
catch {log "console + empty window up (unix cmds: ls cat head tail grep wc rm cp mv mkdir touch which)"}
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
  <key>UIViewControllerBasedStatusBarAppearance</key><true/>
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

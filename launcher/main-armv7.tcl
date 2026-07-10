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

# --- batteries on auto_path (so the demos' `package require`s resolve) --------
set ::iwish_batteries [file join $base lib-batteries]
if {[file isdirectory $::iwish_batteries]} {
  proc _iwish_add_pkgdirs {root} {
    if {[file exists [file join $root pkgIndex.tcl]] && ($root ni $::auto_path)} { lappend ::auto_path $root }
    foreach d [glob -nocomplain -type d -directory $root *] { _iwish_add_pkgdirs $d }
  }
  if {$::iwish_batteries ni $::auto_path} { lappend ::auto_path $::iwish_batteries }
  catch {_iwish_add_pkgdirs $::iwish_batteries}
  foreach {_sub _envv} {itcl4.2.0 ITCL_LIBRARY tktreectrl TREECTRL_LIBRARY itk ITK_LIBRARY vu VU_LIBRARY trofs TROFS_LIBRARY} {
    set _d [file join $::iwish_batteries $_sub]
    if {[file isdirectory $_d]} { set ::env($_envv) $_d }
  }
  if {[file isdirectory [file join $::iwish_batteries tktreectrl]]} {
    set ::treectrl_library [file join $::iwish_batteries tktreectrl]
  }
}
# load the borg iOS bridge (used by the borg/ble demos)
catch { package require borg }

wm title . "iWish"
if {[catch {console show} err]} { catch {log "console show failed: $err"} }
catch {console eval {wm title . "iWish"}}
catch {log "console + empty window up (unix cmds: ls cat head tail grep wc rm cp mv mkdir touch which)"}

# ===========================================================================
# File > Demos submenu (above Exit) — same as the arm64 iWish. Each item sources
# a bundled demo out of lib-batteries/. Missing demos grey out automatically.
# ===========================================================================
set ::iwish_builtin_apps {
  paint       iwish-demos/paint.tcl
  borgdemo    iwish-demos/borgdemo.tcl
  bledemo     iwish-demos/bledemo.tcl
  bltgraph    iwish-demos/bltgraph.tcl
  widget      tkdemos/widget
  tkcon       {tkcon2*/tkcon.tcl}
  tkinspect   {tkinspect*/tkinspect.tcl}
  calc        {calc*/calc.tcl}
  tkmc        {TkMC*/tkmc.tcl}
  bugz        tkbugz/tk_bugz.tcl
  tksqlite    {tksqlite*/tksqlite.tcl}
  tktable     {Tktable*/demos/spreadsheet.tcl}
  treectrl    {treectrl*/demos/demo.tcl}
  zint        {zint*/demo.tcl}
  stardom     {stardom*/stardom.tcl}
  imgdemo     {Img*/demo.tcl}
  tkpdemo     {tkpath*/demos/all.tcl}
  notebook    notebook2.2/notebook.tcl
  vncviewer   {vnc*/vncviewer.tcl}
  tkchat      {tkchat*/tkchat.tcl}
  tixwidgets  {Tix*/demos/tixwidgets.tcl}
  tixtour     {Tix*/demos/widget}
}
proc iwish_builtin_resolve {name} {
  foreach {n pat} $::iwish_builtin_apps {
    if {$n eq $name} {
      set hits [glob -nocomplain [file join $::iwish_batteries $pat]]
      return [expr {[llength $hits] ? [lindex $hits 0] : ""}]
    }
  }
  return ""
}
proc iwish_builtin_menuspec {} {
  set out {}
  foreach {n pat} $::iwish_builtin_apps { lappend out $n [expr {[iwish_builtin_resolve $n] ne ""}] }
  return $out
}
proc iwish_run_builtin {name} {
  set path [iwish_builtin_resolve $name]
  if {$path eq ""} { catch {tk_messageBox -icon info -title "Demos" -message "\"$name\" is not bundled."}; return }
  set ::argv0 $path; set ::argv {}
  if {[catch {uplevel #0 [list source $path]} err]} {
    catch {tk_messageBox -icon error -title "Demos: $name" -message $err}
  }
}
proc iwish_install_demos_menu {{tries 0}} {
  if {[catch {console eval {winfo exists .menubar.file}} ok] || !$ok} {
    if {$tries < 40} { after 150 [list iwish_install_demos_menu [expr {$tries+1}]] }
    return
  }
  catch {console eval {
    if {![winfo exists .menubar.file.demos]} {
      menu .menubar.file.demos -tearoff 0
      set idx -1
      for {set i 0} {$i <= [.menubar.file index end]} {incr i} {
        if {[catch {.menubar.file type $i} t] || $t ne "command"} continue
        set l [.menubar.file entrycget $i -label]
        if {[string match -nocase *xit* $l] || [string match -nocase *quit* $l]} { set idx $i; break }
      }
      if {$idx >= 0} { .menubar.file insert $idx cascade -label "Demos" -menu .menubar.file.demos } \
      else { .menubar.file add cascade -label "Demos" -menu .menubar.file.demos }
      foreach {nm avail} [consoleinterp eval iwish_builtin_menuspec] {
        .menubar.file.demos add command -label $nm \
          -state [expr {$avail ? "normal" : "disabled"}] \
          -command [list consoleinterp eval [list iwish_run_builtin $nm]]
      }
    }
  }}
}
after 300 iwish_install_demos_menu

# --- window placement: main wish window +20+20, console centered --------------
proc iwish_center_console {{tries 0}} {
  if {[catch {console eval {winfo exists .}} ok] || !$ok} {
    if {$tries < 40} { after 150 [list iwish_center_console [expr {$tries+1}]] }
    return
  }
  catch {console eval {
    update idletasks
    set w [winfo width .];  if {$w <= 1} { set w [winfo reqwidth .] }
    set h [winfo height .]; if {$h <= 1} { set h [winfo reqheight .] }
    set x [expr {([winfo screenwidth .]  - $w) / 2}]
    set y [expr {([winfo screenheight .] - $h) / 2}]
    if {$x < 0} { set x 0 }
    if {$y < 0} { set y 0 }
    wm geometry . +$x+$y
  }}
}
after 300 {catch {wm geometry . +20+20}}
after 300 iwish_center_console

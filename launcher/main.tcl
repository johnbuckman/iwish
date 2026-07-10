# iWish (AndroWish on iOS) -- batteries-included Tcl/Tk. Boots a Tk console + window.
set bundle [file dirname [info nameofexecutable]]
if {![info exists ::tcl_library] || ![file isdirectory $::tcl_library]} { set ::tcl_library [file join $bundle lib tcl8.6] }
if {![info exists ::tk_library]  || ![file isdirectory $::tk_library]}  { set ::tk_library  [file join $bundle lib tk8.6] }
catch {uplevel #0 [list source [file join $::tcl_library init.tcl]]}
if {$::tk_library ni $::auto_path} { lappend ::auto_path $::tk_library }
catch {package require Tk}
catch {wm title . "iWish"}
# Start in the app's writable Documents dir (small + writable) rather than the
# read-only bundle, so a bare `ls`/`find` operates somewhere sensible.
catch {set d [file join $::env(HOME) Documents]; file mkdir $d; cd $d}
# ls/cat/grep/... are runtime built-ins now (lib/tcl8.6/unix-commands.tcl,
# sourced from init.tcl), so the launcher no longer defines them.
catch {console show}
catch {console eval {wm title . "iWish"}}   ;# the console window is "iWish", not "Console"
# Load the borg iOS bridge (used by the borg/ble demos and by callers below).
catch {
  lappend ::auto_path [file join $bundle lib]
  package require borg
}

# ===========================================================================
# AndroWish builtin demo apps  ->  Console "File > Demos" submenu (above Exit)
# ===========================================================================
# These are the apps AndroWish/undroidwish normally launches from the command
# line (e.g. `undroidwish widget`). Each menu item sources the app's script out
# of lib-batteries/. Apps whose backing script/extension isn't bundled in this
# build appear greyed-out.
set ::iwish_batteries [file join $bundle lib-batteries]
if {[file isdirectory $::iwish_batteries]} {
  # Register every bundled package dir (recursively) on auto_path so the demos'
  # `package require`s (comm, snit, BWidget, wcb, yeti, ...) resolve.
  proc _iwish_add_pkgdirs {root} {
    if {[file exists [file join $root pkgIndex.tcl]] && ($root ni $::auto_path)} {
      lappend ::auto_path $root
    }
    foreach d [glob -nocomplain -type d -directory $root *] { _iwish_add_pkgdirs $d }
  }
  if {$::iwish_batteries ni $::auto_path} { lappend ::auto_path $::iwish_batteries }
  catch {_iwish_add_pkgdirs $::iwish_batteries}
  # Some C extensions locate their companion .tcl via a *_LIBRARY env var or a
  # global (their pkgIndex/Init uses tcl_findLibrary). Point them at the staged
  # dirs. treectrl.tcl carries no `package provide`, so tcl_findLibrary's
  # usability check rejects it UNLESS ::treectrl_library is preset (then it trusts
  # the global and skips the check).
  foreach {_sub _envv} {itcl4.2.0 ITCL_LIBRARY treectrl2.4 TREECTRL_LIBRARY itk ITK_LIBRARY vu VU_LIBRARY} {
    set _d [file join $::iwish_batteries $_sub]
    if {[file isdirectory $_d]} { set ::env($_envv) $_d }
  }
  if {[file isdirectory [file join $::iwish_batteries treectrl2.4]]} {
    set ::treectrl_library [file join $::iwish_batteries treectrl2.4]
  }
}

# name -> source-target glob, relative to lib-batteries.
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
  vectclab    {VecTcLab*/vectclab.tcl}
  vncviewer   {vnc*/vncviewer.tcl}
  helpviewer  {helpviewer*/main.tcl}
  tkchat      {tkchat*/tkchat.tcl}
  tixwidgets  {Tix*/demos/tixwidgets.tcl}
  tixtour     {Tix*/demos/widget}
  zinc-widget {Tkzinc*/demos/zinc-widget}
  3ddemo      {Canvas3d*/demo/shapes.tcl}
  dungfork    {augeas*/dungfork.tcl}
  fuse        {fuse*/fusevfs.tcl}
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
  foreach {n pat} $::iwish_builtin_apps {
    lappend out $n [expr {[iwish_builtin_resolve $n] ne ""}]
  }
  return $out
}
proc iwish_run_builtin {name} {
  set path [iwish_builtin_resolve $name]
  if {$path eq ""} {
    catch {tk_messageBox -icon info -title "Demos" -message \
      "\"$name\" is not bundled in this iWish build."}
    return
  }
  set ::argv0 $path; set ::argv {}
  if {[catch {uplevel #0 [list source $path]} err]} {
    catch {tk_messageBox -icon error -title "Demos: $name" -message $err}
  }
}
# Inject the cascade into the console's File menu, just above Exit. The console
# lives in a separate interp, so drive it via `console eval` and call back into
# this (main) interp via `consoleinterp eval`. Retry until the menubar is up.
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
      if {$idx >= 0} {
        .menubar.file insert $idx cascade -label "Demos" -menu .menubar.file.demos
      } else {
        .menubar.file add cascade -label "Demos" -menu .menubar.file.demos
      }
      foreach {nm avail} [consoleinterp eval iwish_builtin_menuspec] {
        .menubar.file.demos add command -label $nm \
          -state [expr {$avail ? "normal" : "disabled"}] \
          -command [list consoleinterp eval [list iwish_run_builtin $nm]]
      }
    }
  }}
}
after 300 iwish_install_demos_menu

# ===========================================================================
# Window placement on launch: main wish window near the top-left (+20+20),
# console centered on screen. The console lives in a separate interp, so drive
# it via `console eval` and retry until it's realized (same pattern as the
# Demos menu). Deferred so Tk has mapped the windows first.
# ===========================================================================
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

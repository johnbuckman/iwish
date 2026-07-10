#!/usr/bin/env tclsh
# Static verifier for the staged armv7 battery packages.
# For every lib/<pkg>/pkgIndex.tcl, find each [file join $dir ...] used in a
# `source` or `load`, resolve it against the package dir, and report any target
# that does not exist on disk. That is exactly the "companion-script placement"
# class of failure (the file the pkgIndex promises to source/load isn't there).
set root [lindex $argv 0]
if {$root eq ""} { set root /Users/john/iwish-ios9/dist/iWish-batteries-armv7/lib }

proc scan_pkgindex {dir pk} {
    set fh [open $pk r]; set txt [read $fh]; close $fh
    # Collect every [file join $dir ...] target's segment list. Then report a target as
    # missing only if it does not exist AND no other referenced target with the same final
    # basename exists (that covers pkgIndex fallback chains like Thread's ttrace lookup:
    #   [file join $dir .. lib ttrace.tcl] || [file join $dir ttrace.tcl]).
    set targets {}
    foreach m [regexp -all -inline {\[file join \$dir ([^\]]*)\]} $txt] {
        if {[string match {\[file join*} $m]} continue   ;# skip the full-match entries
        set segs [string trim [regsub -all {[\"\{\}]} $m ""]]
        if {$segs eq ""} continue
        # skip targets whose path is a runtime variable (e.g. iwidgets' `foreach file {...}`
        # then [file join $dir $file]) — not statically resolvable, not a placement bug.
        if {[string match {*$*} $segs]} continue
        lappend targets $segs
    }
    # basenames that DO exist on disk
    set satisfied {}
    foreach segs $targets {
        if {[file exists [file join $dir {*}$segs]]} { dict set satisfied [lindex $segs end] 1 }
    }
    set missing {}
    foreach segs $targets {
        if {[file exists [file join $dir {*}$segs]]} continue
        if {[dict exists $satisfied [lindex $segs end]]} continue   ;# fallback alt exists
        lappend missing $segs
    }
    return $missing
}

set totalpkg 0; set badpkg 0
foreach d [lsort [glob -nocomplain -type d $root/*]] {
    set pk [file join $d pkgIndex.tcl]
    if {![file exists $pk]} continue
    incr totalpkg
    set miss [scan_pkgindex $d $pk]
    if {[llength $miss]} {
        incr badpkg
        puts "BROKEN [file tail $d]:"
        foreach s [lsort -unique $miss] { puts "    missing -> $s" }
    }
}
puts "----"
puts "scanned $totalpkg packages, $badpkg have missing source/load targets"

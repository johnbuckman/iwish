# iWish Unix-style commands  -- part of the iWish runtime.
#
# iOS sandboxes fork/exec, so Tcl's `exec ls`, `exec cat`, `exec cp`, ... can
# never run from a packaged app. This file provides pure-Tcl replacements for the
# common filesystem/text utilities that Tcl code usually shells out to.
#
# It is sourced by the runtime at startup (from lib/tcl8.6/init.tcl), so these
# commands exist in EVERY interpreter -- available to all Tcl programs, not just
# the interactive console.
#
# Deliberately NOT provided, because Tcl already has them as built-ins:
#   pwd, cd            -> built-in
#   date               -> clock format / clock seconds
#   sleep              -> after / after+vwait
#   sort, uniq, tr     -> lsort / lsearch / string map  (data, not files)
#   test, [ ]          -> file exists / file isdirectory / expr
#
# Cannot be provided without exec or privileged syscalls iOS forbids (so they are
# intentionally left undefined rather than faked):
#   ps, kill, top, nice           (process table / signals)
#   df, mount, diskutil           (volume info)
#   ping, ifconfig, ssh, curl     (raw networking -- use Tcl's http/socket/TclCurl)
#   sudo, chown                   (privilege / ownership)
#
# Commands here never override an existing command: if a program (or another
# package) already defines one of these names, that definition is kept.

namespace eval ::iwishunix {
    variable cmds {ls cat head tail grep wc cp mv rm mkdir rmdir touch ln chmod du find basename dirname echo}
    # Safety cap on a single command's line output. A command that emits thousands
    # of lines blocks the event loop while churning the console widget, and the
    # process gets memory-killed by iOS as the renderer catches up. Streaming
    # commands (ls/grep/find) stop at this many lines; emit() also yields to the
    # event loop periodically so output drains incrementally instead of all at once.
    variable maxlines 2000
    variable count 0
}

proc ::iwishunix::define {name body} {
    if {[llength [info commands ::$name]] == 0} {
        proc ::$name {args} $body
    }
}

# Print one output line; yield to the event loop every so often; stop the command
# (via a sentinel error caught by run{}) once the line cap is reached.
proc ::iwishunix::emit {line} {
    variable count; variable maxlines
    puts $line
    incr count
    if {($count % 256) == 0} {catch {update idletasks}}
    if {$count >= $maxlines} {
        puts "(output truncated at $maxlines lines -- narrow your command)"
        return -code error __limit__
    }
}

# Run a streaming command body: reset the line counter, swallow the cap sentinel.
proc ::iwishunix::run {script} {
    variable count; set count 0
    set rc [catch {uplevel 1 $script} e opts]
    if {$rc && $e ne "__limit__"} {return -options $opts $e}
    return ""
}

# ---- listing -------------------------------------------------------------
::iwishunix::define ls {
    set long 0; set all 0; set targets {}
    foreach a $args {
        if {[string match -* $a]} {
            if {[string match *l* $a]} {set long 1}
            if {[string match *a* $a]} {set all 1}
        } else { lappend targets $a }
    }
    if {![llength $targets]} {set targets [list .]}
    set multi [expr {[llength $targets] > 1}]
    ::iwishunix::run {
        foreach t $targets {
            if {[file isfile $t]} { ::iwishunix::emit $t; continue }
            if {$multi} {::iwishunix::emit "$t:"}
            set names [lsort [glob -nocomplain -directory $t -tails -- *]]
            if {$all} {
                set dots {}
                foreach h [lsort [glob -nocomplain -directory $t -tails -- .*]] {
                    if {$h ni {. ..}} {lappend dots $h}
                }
                set names [concat $dots $names]
            }
            foreach f $names {
                set full [file join $t $f]
                set isdir [file isdirectory $full]
                if {$long} {
                    ::iwishunix::emit [format "%s %10s  %s  %s" [expr {$isdir ? "d" : "-"}] \
                        [expr {$isdir ? "-" : [file size $full]}] \
                        [clock format [file mtime $full] -format "%Y-%m-%d %H:%M"] \
                        [expr {$isdir ? "$f/" : $f}]]
                } else {
                    ::iwishunix::emit [expr {$isdir ? "$f/" : $f}]
                }
            }
            if {$multi} {::iwishunix::emit ""}
        }
    }
}

# ---- view / text ---------------------------------------------------------
::iwishunix::define cat {
    foreach f $args {
        set fh [open $f r]; puts -nonewline [read $fh]; close $fh
    }
}
::iwishunix::define head {
    set n 10; set files {}
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        if {$a eq "-n"} {set n [lindex $args [incr i]]} \
        elseif {[regexp {^-([0-9]+)$} $a -> m]} {set n $m} \
        else {lappend files $a}
    }
    foreach f $files {
        set fh [open $f r]; set i 0
        while {$i < $n && [gets $fh line] >= 0} {puts $line; incr i}
        close $fh
    }
}
::iwishunix::define tail {
    set n 10; set files {}
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        if {$a eq "-n"} {set n [lindex $args [incr i]]} \
        elseif {[regexp {^-([0-9]+)$} $a -> m]} {set n $m} \
        else {lappend files $a}
    }
    foreach f $files {
        set fh [open $f r]; set lines [split [read $fh] \n]; close $fh
        if {[lindex $lines end] eq ""} {set lines [lrange $lines 0 end-1]}
        if {$n < [llength $lines]} {set lines [lrange $lines end-[expr {$n-1}] end]}
        foreach l $lines {puts $l}
    }
}
::iwishunix::define grep {
    set ci 0; set num 0; set pat ""; set files {}
    foreach a $args {
        switch -- $a {
            -i {set ci 1}
            -n {set num 1}
            -in - -ni {set ci 1; set num 1}
            default {if {$pat eq ""} {set pat $a} else {lappend files $a}}
        }
    }
    set re [expr {$ci ? "(?i)$pat" : $pat}]
    set multi [expr {[llength $files] > 1}]
    ::iwishunix::run {
        foreach f $files {
            set fh [open $f r]; set ln 0
            while {[gets $fh line] >= 0} {
                incr ln
                if {[regexp -- $re $line]} {
                    set p [expr {$multi ? "$f:" : ""}]
                    if {$num} {append p "$ln:"}
                    ::iwishunix::emit "$p$line"
                }
            }
            close $fh
        }
    }
}
::iwishunix::define wc {
    foreach f $args {
        set fh [open $f r]; set data [read $fh]; close $fh
        puts [format "%8d %8d %8d  %s" \
            [regexp -all \n $data] \
            [llength [regexp -all -inline {\S+} $data]] \
            [string length $data] $f]
    }
}

# ---- filesystem ----------------------------------------------------------
::iwishunix::define cp {
    set p {}; foreach a $args {if {![string match -* $a]} {lappend p $a}}
    set dest [lindex $p end]
    foreach s [lrange $p 0 end-1] {file copy -force -- $s $dest}
}
::iwishunix::define mv {
    set p {}; foreach a $args {if {![string match -* $a]} {lappend p $a}}
    set dest [lindex $p end]
    foreach s [lrange $p 0 end-1] {file rename -force -- $s $dest}
}
::iwishunix::define rm {
    foreach a $args {if {![string match -* $a]} {file delete -force -- $a}}
}
::iwishunix::define mkdir {
    foreach a $args {if {![string match -* $a]} {file mkdir $a}}
}
::iwishunix::define rmdir {
    foreach a $args {if {![string match -* $a]} {file delete -- $a}}
}
::iwishunix::define touch {
    foreach f $args {
        if {[string match -* $f]} continue
        if {[file exists $f]} {file mtime $f [clock seconds]} else {close [open $f a]}
    }
}
::iwishunix::define ln {
    set sym 0; set p {}
    foreach a $args {if {$a eq "-s"} {set sym 1} elseif {![string match -* $a]} {lappend p $a}}
    lassign $p target link
    if {$link eq ""} {set link [file tail $target]}
    file link [expr {$sym ? "-symbolic" : "-hard"}] $link $target
}
::iwishunix::define chmod {
    set mode [lindex $args 0]
    foreach f [lrange $args 1 end] {file attributes $f -permissions $mode}
}
::iwishunix::define du {
    set dirs [expr {[llength $args] ? [lsearch -all -inline -not $args -*] : [list .]}]
    if {![llength $dirs]} {set dirs [list .]}
    foreach d $dirs {puts [format "%10d  %s" [::iwishunix::bytes $d 1] $d]}
}
# Sum file sizes; like du, don't follow symlinks during the walk ($top follows
# an explicit symlink start point).
proc ::iwishunix::bytes {path {top 0}} {
    set t [file type $path]
    if {$t eq "file"} {return [file size $path]}
    if {$t ne "directory" && !($top && $t eq "link" && [file isdirectory $path])} {return 0}
    set sum 0
    foreach f [glob -nocomplain -directory $path -- * .*] {
        if {[file tail $f] in {. ..}} continue
        incr sum [bytes $f]
    }
    return $sum
}
::iwishunix::define find {
    set start .; set namepat *
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        if {$a eq "-name"} {set namepat [lindex $args [incr i]]} \
        elseif {![string match -* $a]} {set start $a}
    }
    ::iwishunix::run {::iwishunix::walk $start $namepat 1}
}
# Like real find: descend into real directories only -- do NOT follow symlinks
# encountered during traversal (prevents runaway/cyclic walks via /var, /tmp, ...).
# The explicit start point IS followed even if it is a symlink ($top).
proc ::iwishunix::walk {path namepat top} {
    if {[string match $namepat [file tail $path]]} {emit $path}
    set t [file type $path]
    if {$t eq "directory" || ($top && $t eq "link" && [file isdirectory $path])} {
        foreach f [lsort [glob -nocomplain -directory $path -- *]] {walk $f $namepat 0}
    }
}

# ---- misc ----------------------------------------------------------------
# basename/dirname RETURN (composable: `set d [dirname $f]`); the console echoes
# the result. echo prints its arguments.
::iwishunix::define basename {return [file tail [lindex $args 0]]}
::iwishunix::define dirname  {return [file dirname [lindex $args 0]]}
::iwishunix::define echo     {puts [join $args " "]}

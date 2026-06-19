#!/usr/bin/env tclsh
# Stress test for the large-output console crash: run `find` many times and exit.
#
# On the iWish runtime (iPad), `find`'s output floods the in-app Tk console -- the
# sink whose churn memory-killed the app. A fixed runtime (output cap + event-loop
# yield in unix-commands.tcl) must survive all iterations and exit cleanly. The
# crash hits on a SINGLE big `find`, so survival through the first iterations
# already proves the per-call fix; the full 10000 also flushes out slow leaks.
#
# Progress is written (flushed) to a log so the result is recoverable even if the
# process is killed:  the last line is "DONE ... PASSED" iff it survived.
#
# Config via env:
#   IWISH_STRESS_N    iterations (default 10000)
#   IWISH_STRESS_DIR  dir to find over (default: cwd; on device set to Documents)
#   IWISH_STRESS_LOG  progress log (default: ~/Documents/find_stress.log or ./)

catch {package require Tk; catch {wm title . "find-stress"}; catch {console show}}

# On the device these are runtime built-ins; on host tclsh, source them.
if {![llength [info commands find]]} {
    catch {source [file join [file dirname [file normalize [info script]]] unix-commands.tcl]}
}

proc envor {name default} {
    if {[info exists ::env($name)]} {return $::env($name)}
    return $default
}
set N   [envor IWISH_STRESS_N 10000]
set dir [envor IWISH_STRESS_DIR [pwd]]
if {[info exists ::env(HOME)]} {
    set deflog [file join $::env(HOME) Documents find_stress.log]
} else {
    set deflog [file join [pwd] find_stress.log]
}
set LOG [envor IWISH_STRESS_LOG $deflog]

proc slog {m} {catch {set fh [open $::LOG a]; puts $fh "[clock milliseconds] $m"; flush $fh; close $fh}}
catch {file delete $LOG}
catch {cd $dir}
set hasTk [expr {[llength [info commands wm]] > 0}]
slog "START N=$N cwd=[pwd] tk=$hasTk"

set done 0
for {set i 1} {$i <= $N} {incr i} {
    if {[catch {find} e]} {slog "ERROR at iter $i: $e"; break}
    set done $i
    if {$i % 200 == 0} {slog "iter $i emitted~$::iwishunix::count"; catch {update}}
}

if {$done == $N} {
    slog "DONE reached=$done/$N PASSED"
} else {
    slog "STOPPED reached=$done/$N FAILED"
}
catch {update}
catch {puts "find-stress: reached $done/$N"}
exit [expr {$done == $N ? 0 : 1}]

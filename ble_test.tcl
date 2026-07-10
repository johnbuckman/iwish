# ble_test.tcl -- portable BLE scan test for iOS (armv7) and macOS reference.
# Usage: tclsh ble_test.tcl <path-to-libble.dylib>
# Logs to /tmp/de1_ble_mac.log on macOS, /var/mobile/Documents/de1_ble_ios.log on iOS.

if {$argc < 1} {
    puts stderr "Usage: [info nameofexecutable] $argv0 <path-to-libble.dylib>|<path-to-tcl-ble-osx-dir>"
    exit 1
}
set arg0 [lindex $argv 0]

if {[file exists /var/mobile/Documents]} {
    set logpath /var/mobile/Documents/de1_ble_ios.log
} else {
    set logpath /tmp/de1_ble_mac.log
}

set log [open $logpath w]
fconfigure $log -buffering none
fconfigure stdout -buffering none

proc logmsg {msg} {
    global log
    puts $log $msg
    flush $log
    puts $msg
}

set ::discovered 0
set ::state unknown
set ::done 0

proc ble_callback {kind args} {
    logmsg "CALLBACK kind=$kind args=$args (llength=[llength $args])"
    if {$kind eq "state"} {
        if {[llength $args] == 1} {
            set ::state [lindex $args 0]
        } elseif {[dict exists $args state]} {
            set ::state [dict get $args state]
        } else {
            set ::state [lindex $args 0]
        }
        logmsg "STATE: $::state"
    } elseif {$kind eq "scan"} {
        incr ::discovered
        logmsg "SCAN: $args"
    } else {
        logmsg "EVENT $kind: $args"
    }
}

logmsg "ble portable scan test starting"
logmsg "platform: [array get tcl_platform]"
logmsg "arg0: $arg0"

if {[file isdirectory $arg0] && [file exists [file join $arg0 pkgIndex.tcl]]} {
    logmsg "loading tcl-ble-osx package from $arg0"
    lappend auto_path $arg0
    if {[catch {package require ble} err]} {
        logmsg "package require ble error: $err"
        exit 1
    }
} elseif {[file exists $arg0]} {
    logmsg "loading dylib $arg0"
    if {[catch {load $arg0 Ble} err]} {
        logmsg "load error: $err"
        exit 1
    }
} else {
    logmsg "argument is neither a dylib nor a package directory: $arg0"
    exit 1
}

logmsg "state before scanner: [ble state]"

ble scanner ble_callback

after 5000  { logmsg "tick: state=$::state discovered=$::discovered" }
after 10000 { logmsg "tick: state=$::state discovered=$::discovered" }
after 15000 { logmsg "tick: state=$::state discovered=$::discovered" }
after 20000 { set ::done 1 }

vwait ::done

logmsg "FINAL: state=$::state discovered=$::discovered"
close $log
exit 0

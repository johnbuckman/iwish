if {[file exists /tmp/iwish_bletest]} {
    proc blog {m} { catch {set f [open /var/mobile/Documents/ble_gui.log a]; set t [clock format [clock seconds] -format %H:%M:%S]; puts $f "$t $m"; close $f} }
    catch {file delete /var/mobile/Documents/ble_gui.log}
    blog "==== tclble.m v2 foreground test ===="
    set LIB /Applications/IwishDE1.app/lib-batteries/ble1.0/libble1.0.dylib
    if {[catch {load $LIB Ble} e]} { blog "LOAD FAIL $e" } else { blog "loaded ok" }
    blog "ble info (no-arg) = \[[catch {ble info} r]\] {$r}"
    set ::gseen 0; array set ::u {}
    proc gcb {ev data} {
        if {$ev eq "scan"} {
            incr ::gseen
            set a [dict get $data address]
            if {![info exists ::u($a)]} { set ::u($a) 1; blog "DISCOVER [dict get $data name] rssi=[dict get $data rssi] $a" }
        } else { blog "EV $ev $data" }
    }
    catch {ble scanner gcb} r; blog "scanner=$r"
    label .s -text scan -font {Helvetica 28}; pack .s -expand 1 -fill both
    set ::gt 0
    proc gtick {} { incr ::gt; catch {.s configure -text "tclble v2\n${::gt}s uniq=[array size ::u] hits=$::gseen"}
        if {$::gt % 5 == 0} { blog "t=${::gt}s state=[catch {ble state} s; set s] uniq=[array size ::u] hits=$::gseen" }
        if {$::gt >= 25} { blog "==== done uniq=[array size ::u] hits=$::gseen; info=\[[catch {ble info} r]\]{$r} ===="; return }
        after 1000 gtick }
    after 1000 gtick
    return
}

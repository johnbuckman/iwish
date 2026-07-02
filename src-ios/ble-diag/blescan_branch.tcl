if {[file exists /tmp/iwish_blescan]} {
    proc blog {m} { catch {set f [open /var/mobile/Documents/ble_gui.log a]; set t [clock format [clock seconds] -format %H:%M:%S]; puts $f "$t $m"; close $f} }
    catch {file delete /var/mobile/Documents/ble_gui.log}
    blog "==== GUI blescan (foreground SpringBoard) tcl [info patchlevel] ===="
    set LIB /Applications/IwishDE1.app/lib-batteries/ble1.0/libble1.0.dylib
    if {[catch {load $LIB Ble} e]} { blog "LOAD FAIL $e" } else { blog "loaded ok" }
    set ::gseen 0
    proc gcb {ev args} { if {$ev eq "scan"} { incr ::gseen; blog "DISCOVER $args" } else { blog "EV $ev $args" } }
    catch {ble scanner gcb} r; blog "scanner=$r"
    wm title . "BLE scan"
    label .s -text "BLE scan..." -font {Helvetica 30} -justify center
    pack .s -expand 1 -fill both
    set ::gt 0
    proc gtick {} {
        incr ::gt
        catch {.s configure -text "BLE foreground scan\n${::gt}s   seen=$::gseen"}
        if {$::gt % 5 == 0} { blog "t=${::gt}s powerstate=[ble powerstate] seen=$::gseen" }
        if {$::gt >= 30} { blog "==== done seen=$::gseen ===="; return }
        after 1000 gtick
    }
    after 1000 gtick
    return
}

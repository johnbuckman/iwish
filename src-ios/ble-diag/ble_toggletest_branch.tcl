if {[file exists /tmp/iwish_toggletest]} {
    proc blog {m} { catch {set f [open /var/mobile/Documents/ble_gui.log a]; set t [clock format [clock seconds] -format %H:%M:%S]; puts $f "$t $m"; close $f} }
    catch {file delete /var/mobile/Documents/ble_gui.log}
    blog "==== tclble.m v3 + power-cycle test ===="
    if {[catch {exec /tmp/bttoggle 2>@1} o]} { blog "bttoggle ERR $o" } else { blog "bttoggle done" }
    set LIB /Applications/IwishDE1.app/lib-batteries/ble1.0/libble1.0.dylib
    if {[catch {load $LIB Ble} e]} { blog "LOAD FAIL $e" } else { blog "loaded ok" }
    array set ::u {}; set ::gseen 0
    proc gcb {ev data} { if {$ev eq "scan"} { incr ::gseen; set a [dict get $data address]; if {![info exists ::u($a)]} { set ::u($a) 1; blog "DISCOVER [dict get $data name] rssi=[dict get $data rssi] $a" } } else { blog "EV $ev $data" } }
    catch {ble scanner gcb} r; blog "scanner=$r"
    label .s -text scan -font {Helvetica 26}; pack .s -expand 1 -fill both
    set ::gt 0
    proc gtick {} { incr ::gt; catch {.s configure -text "v3+toggle\n${::gt}s uniq=[array size ::u]"}
      if {$::gt%5==0} { blog "t=${::gt}s uniq=[array size ::u] hits=$::gseen" }
      if {$::gt>=22} { blog "==== done uniq=[array size ::u] hits=$::gseen ===="; return }; after 1000 gtick }
    after 1000 gtick
    return
}

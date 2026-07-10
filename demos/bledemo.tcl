# iWish demo: a LightBlue-style Bluetooth LE debugger.
# Scan -> connect -> browse services/characteristics -> read, subscribe
# (receive notifications) and write raw bytes. Uses iWish's CoreBluetooth `ble`
# command (the de1app/AndroWish-compatible API), verified live against a Skale:
#   ble scanner <cb>                cb: "<cb> scan {address .. name .. rssi ..}"
#   ble connect <address> <cb>      -> handle. cb: "<cb> <event> <dict>":
#      connection     {state connected|disconnected mtu ..}
#      characteristic {state discovery suuid <s> sinstance <si> cuuid <c> cinstance <ci>}
#      characteristic {state connected access r|c|w suuid.. sinstance.. cuuid.. cinstance.. value <bytes>}
#   ble read/enable/disable  <h> <suuid> <si> <cuuid> <ci>
#   ble write <h> <suuid> <si> <cuuid> <ci> <data>            ble close <h>
# NB: pass the REAL instance numbers from the discovery event (not 0).
# iOS shows a one-time "allow Bluetooth" prompt on the first scan.
if {[catch {package require ble}]} {
    tk_messageBox -icon error -title "BLE debugger" -message "The ble package failed to load."
    return
}
catch {destroy .bledbg}
toplevel .bledbg
wm title .bledbg "iWish · Bluetooth LE debugger"
wm geometry .bledbg 920x660

array unset ::bd
set ::bd(scanner) ""      ;# scanner token
set ::bd(conn)    ""      ;# connection handle
set ::bd(devs)    [dict create]
set ::bd(order)   {}
set ::bd(cur)     ""      ;# selected char node id
set ::bd(autoname) 1      ;# background auto-name sweep enabled
set ::bd(an_tried) [dict create]  ;# addr -> 1 (already attempted this scan)
set ::bd(resolved) [dict create]  ;# addr -> name resolved via GATT 0x2A00
set ::bd(an_conn)  ""     ;# sweep's in-flight connection handle
set ::bd(an_addr)  ""     ;# addr the sweep is currently resolving
set ::bd(an_after) ""     ;# sweep per-device timeout id
array unset ::bdchar      ;# node-id -> {suuid sinstance cuuid cinstance}
array unset ::bdsub       ;# node-id -> 1 if subscribed

set ::bd(names) [dict create \
    1800 "Generic Access" 1801 "Generic Attribute" 180A "Device Information" \
    180F "Battery" 180D "Heart Rate" FF08 "Skale" \
    2A19 "Battery Level" 2A00 "Device Name" 2A29 "Manufacturer" 2A24 "Model" \
    EF80 "Skale command" EF81 "Skale weight" EF82 "Skale button" \
    A000 "DE1" A002 "DE1 RequestedState" A00E "DE1 StateInfo"]
proc bd_name {uuid} {
    set s [bd_ushort $uuid]
    if {[dict exists $::bd(names) $s]} { return "[dict get $::bd(names) $s]  ($s)" }
    return $uuid
}
# normalise a 128-bit Bluetooth-base UUID down to its 16-bit short form (else upper-case as-is)
proc bd_ushort {uuid} {
    set s [string toupper $uuid]
    if {[regexp {^0000([0-9A-F]{4})-0000-1000-8000-00805F9B34FB$} $s -> x]} { return $x }
    return $s
}
proc bd_hex {data} {
    binary scan $data H* h
    set out {}
    for {set i 0} {$i < [string length $h]} {incr i 2} { lappend out [string range $h $i [expr {$i+1}]] }
    set asc ""
    foreach ch [split $data ""] { scan $ch %c n; append asc [expr {$n>=32 && $n<127 ? $ch : "."}] }
    set hx [join $out " "]; if {$hx eq ""} { set hx "(empty)" }
    return "$hx    |$asc|"
}
proc bd_log {m} {
    set t .bledbg.b.log; $t configure -state normal
    $t insert end "[clock format [clock seconds] -format %H:%M:%S]  $m\n"; $t see end
    $t configure -state disabled
}

# ---- layout --------------------------------------------------------------
frame .bledbg.top
button .bledbg.top.scan -text "Start scan" -width 11 -command bd_toggle_scan
button .bledbg.top.disc -text "Disconnect" -width 11 -command bd_disconnect -state disabled
checkbutton .bledbg.top.auto -text "Auto-name" -variable ::bd(autoname)
label  .bledbg.top.status -text "idle" -fg gray30
pack .bledbg.top.scan .bledbg.top.disc .bledbg.top.auto -side left -padx 4 -pady 4
pack .bledbg.top.status -side left -padx 10
pack .bledbg.top -side top -fill x

panedwindow .bledbg.pw -orient horizontal -sashwidth 6
pack .bledbg.pw -side top -fill both -expand 1 -padx 6 -pady 4
frame .bledbg.pw.left
label .bledbg.pw.left.l -text "Discovered devices" -anchor w
listbox .bledbg.pw.left.lb -width 32 -exportselection 0 -yscrollcommand {.bledbg.pw.left.sb set}
scrollbar .bledbg.pw.left.sb -command {.bledbg.pw.left.lb yview}
button .bledbg.pw.left.con -text "Connect" -command bd_connect_selected -state disabled
pack .bledbg.pw.left.l -side top -fill x
pack .bledbg.pw.left.con -side bottom -fill x -pady {4 0}
pack .bledbg.pw.left.sb -side right -fill y
pack .bledbg.pw.left.lb -side left -fill both -expand 1
bind .bledbg.pw.left.lb <<ListboxSelect>> {.bledbg.pw.left.con configure -state normal}
bind .bledbg.pw.left.lb <Double-1> {after idle bd_connect_selected}
frame .bledbg.pw.right
label .bledbg.pw.right.l -text "Services / characteristics" -anchor w
ttk::treeview .bledbg.pw.right.tv -show tree -selectmode browse -yscrollcommand {.bledbg.pw.right.sb set}
scrollbar .bledbg.pw.right.sb -command {.bledbg.pw.right.tv yview}
pack .bledbg.pw.right.l -side top -fill x
pack .bledbg.pw.right.sb -side right -fill y
pack .bledbg.pw.right.tv -side left -fill both -expand 1
bind .bledbg.pw.right.tv <<TreeviewSelect>> bd_select
.bledbg.pw add .bledbg.pw.left -width 300
.bledbg.pw add .bledbg.pw.right

frame .bledbg.b
pack .bledbg.b -side bottom -fill both -padx 6 -pady {0 6}
labelframe .bledbg.b.det -text " Selected characteristic " -padx 6 -pady 4
pack .bledbg.b.det -side top -fill x
label  .bledbg.b.det.uuid -text "(select a characteristic)" -anchor w -fg gray30
button .bledbg.b.det.read -text "Read" -width 7 -command bd_read -state disabled
button .bledbg.b.det.sub  -text "Subscribe" -width 10 -command bd_subscribe -state disabled
entry  .bledbg.b.det.hex  -width 24
button .bledbg.b.det.write -text "Write hex" -width 9 -command bd_write -state disabled
grid .bledbg.b.det.uuid  -row 0 -column 0 -columnspan 4 -sticky w -pady {0 4}
grid .bledbg.b.det.read  -row 1 -column 0 -padx 2
grid .bledbg.b.det.sub   -row 1 -column 1 -padx 2
grid .bledbg.b.det.hex   -row 1 -column 2 -padx {12 2}
grid .bledbg.b.det.write -row 1 -column 3 -padx 2
label .bledbg.b.det.hint -text "  hex e.g.  03   or  01 a2 ff" -fg gray50
grid .bledbg.b.det.hint  -row 2 -column 2 -columnspan 2 -sticky w
label .bledbg.b.ll -text "Log" -anchor w
text  .bledbg.b.log -height 10 -wrap none -state disabled -font {Menlo 10} -yscrollcommand {.bledbg.b.sb set}
scrollbar .bledbg.b.sb -command {.bledbg.b.log yview}
pack .bledbg.b.ll -side top -anchor w -pady {6 0}
pack .bledbg.b.sb -side right -fill y
pack .bledbg.b.log -side top -fill both -expand 1

# ---- scanning ------------------------------------------------------------
proc bd_render_devs {} {
    set lb .bledbg.pw.left.lb; $lb delete 0 end; set ::bd(order) {}
    set rows {}
    dict for {addr info} $::bd(devs) { lassign $info name rssi; lappend rows [list $rssi $name $addr] }
    foreach r [lsort -integer -index 0 -decreasing $rows] {
        lassign $r rssi name addr
        $lb insert end [format "%4s  %s" $rssi $name]; lappend ::bd(order) $addr
    }
}
# A device that broadcasts no name can often still be labelled from what it DOES
# advertise (without connecting): its service UUIDs (mapped to friendly names) and
# its manufacturer. e.g. "Heart Rate · Apple", "DE1", "Battery".
proc bd_adv_label {data} {
    set parts {}
    set svcs ""; catch {set svcs [dict get $data services]}
    foreach u $svcs {
        set s [bd_ushort $u]
        if {[dict exists $::bd(names) $s]} { lappend parts [dict get $::bd(names) $s] }
    }
    set out [join [lrange $parts 0 2] " / "]
    set mfr ""; catch {set mfr [dict get $data mfr]}
    if {$mfr ne "" && ![string match "0x*" $mfr]} {
        if {$out ne ""} { append out " · $mfr" } else { set out $mfr }
    }
    return $out
}
proc bd_scan_cb {event data} {
    if {$event eq "state"} { catch {.bledbg.top.status configure -text "Bluetooth: [dict get $data state]"}; return }
    if {$event ne "scan"} return
    set addr [dict get $data address]; set name [dict get $data name]; set rssi [dict get $data rssi]
    if {[dict exists $::bd(resolved) $addr]} {
        set name [dict get $::bd(resolved) $addr]   ;# GATT-resolved name wins over a blank ad
    } elseif {$name eq ""} {
        set lbl [bd_adv_label $data]
        set name [expr {$lbl ne "" ? "‹$lbl›" : "(unnamed)"}]  ;# ‹inferred›
    }
    dict set ::bd(devs) $addr [list $name $rssi]; catch {bd_render_devs}
}
# ---- background auto-name sweep ------------------------------------------
# For devices that advertise no usable name, briefly connect, read the GATT
# Device Name (0x2A00), then disconnect — ONE at a time — to fill in the list.
# Each device is tried once per scan; pauses while the user has their own
# connection open; resolved names are cached so continued scanning won't blank them.
proc bd_needs_name {name} { expr {$name eq "(unnamed)" || [string index $name 0] eq "‹"} }
proc bd_autoname_tick {} {
    after 1200 bd_autoname_tick
    if {![winfo exists .bledbg]} return
    if {!$::bd(autoname) || $::bd(conn) ne "" || $::bd(an_conn) ne "" || $::bd(scanner) eq ""} return
    # try the STRONGEST-signal untried unnamed device first — a close device is
    # more likely yours and more likely to accept a connection (distant anonymous
    # beacons mostly refuse and just waste the per-device timeout).
    set best ""; set bestr -999
    dict for {addr info} $::bd(devs) {
        lassign $info name rssi
        if {[dict exists $::bd(an_tried) $addr] || ![bd_needs_name $name]} continue
        if {$rssi ne "" && $rssi != 127 && $rssi > $bestr} { set bestr $rssi; set best $addr }
    }
    if {$best ne ""} { bd_autoname_start $best }
}
proc bd_autoname_start {addr} {
    dict set ::bd(an_tried) $addr 1
    set ::bd(an_addr) $addr; set ::bd(an_vals) [dict create]
    # pause scanning first: the A5 radio can't reliably connect while a scan runs.
    catch {ble stop $::bd(scanner)}
    if {[catch {ble connect $addr bd_autoname_cb} c]} { set ::bd(an_addr) ""; catch {ble start $::bd(scanner)}; return }
    set ::bd(an_conn) $c
    .bledbg.top.status configure -text "auto-naming [string range $addr 0 7]…"
    set ::bd(an_after) [after 9000 bd_autoname_timeout]
}
# Read the "identity" characteristics: Device Name (2A00), and — since many
# devices expose no 2A00 — Manufacturer (2A29) + Model (2A24) as a fallback.
proc bd_autoname_bestname {} {
    set v $::bd(an_vals)
    if {[dict exists $v 2A00]} { return [dict get $v 2A00] }
    set mk {}
    foreach u {2A29 2A24} { if {[dict exists $v $u]} { lappend mk [dict get $v $u] } }
    return [join $mk " "]
}
proc bd_autoname_cb {event data} {
    if {$::bd(an_conn) eq ""} return
    switch -- $event {
        characteristic {
            set cu [bd_ushort [dict get $data cuuid]]
            if {[dict get $data state] eq "discovery"} {
                if {$cu in {2A00 2A29 2A24}} {
                    after 250 [list catch [list ble read $::bd(an_conn) [dict get $data suuid] [dict get $data sinstance] [dict get $data cuuid] [dict get $data cinstance]]]
                }
            } elseif {$cu in {2A00 2A29 2A24}} {
                set v ""; catch {set v [dict get $data value]}
                set s [string trim [string trimright [encoding convertfrom utf-8 $v] "\x00"]]
                if {$s ne ""} { dict set ::bd(an_vals) $cu $s }
                # finish early once we have a solid name (real Device Name, or mfr+model)
                if {[dict exists $::bd(an_vals) 2A00] || ([dict exists $::bd(an_vals) 2A29] && [dict exists $::bd(an_vals) 2A24])} {
                    set nm [bd_autoname_bestname]; if {$nm ne ""} { bd_autoname_finish $nm }
                }
            }
        }
        connection { if {[dict get $data state] eq "disconnected"} { bd_autoname_finish [bd_autoname_bestname] } }
    }
}
proc bd_autoname_timeout {} { bd_autoname_finish [bd_autoname_bestname] }
proc bd_autoname_finish {name} {
    set addr $::bd(an_addr)
    catch {after cancel $::bd(an_after)}
    if {$::bd(an_conn) ne ""} { catch {ble close $::bd(an_conn)} }
    set ::bd(an_conn) ""; set ::bd(an_addr) ""; set ::bd(an_after) ""
    if {$name ne "" && $addr ne ""} {
        dict set ::bd(resolved) $addr $name
        if {[dict exists $::bd(devs) $addr]} {
            lassign [dict get $::bd(devs) $addr] _o rssi
            dict set ::bd(devs) $addr [list $name $rssi]; catch {bd_render_devs}
        }
        catch {bd_log "auto-named [string range $addr 0 7]… -> $name"}
    }
    # resume scanning for the next device
    if {$::bd(scanner) ne "" && $::bd(conn) eq ""} { catch {ble start $::bd(scanner)} }
    catch {.bledbg.top.status configure -text "scanning…"}
}
proc bd_toggle_scan {} {
    if {$::bd(scanner) eq ""} {
        set ::bd(devs) [dict create]; set ::bd(an_tried) [dict create]; bd_render_devs
        if {[catch {ble scanner bd_scan_cb} h]} { bd_log "scan error: $h"; return }
        set ::bd(scanner) $h; catch {ble start $h}
        .bledbg.top.scan configure -text "Stop scan"; .bledbg.top.status configure -text "scanning…"
        bd_log "scan started"
    } else {
        catch {ble stop $::bd(scanner)}; set ::bd(scanner) ""
        .bledbg.top.scan configure -text "Start scan"; .bledbg.top.status configure -text "scan stopped"
    }
}

# ---- connect + discovery -------------------------------------------------
proc bd_connect_selected {} {
    set i [.bledbg.pw.left.lb curselection]; if {$i eq ""} return
    set addr [lindex $::bd(order) $i]; if {$addr eq ""} return
    # abort an in-flight auto-name sweep so it doesn't clash with the user's connect
    if {$::bd(an_conn) ne ""} { catch {after cancel $::bd(an_after)}; catch {ble close $::bd(an_conn)}; set ::bd(an_conn) ""; set ::bd(an_addr) "" }
    if {$::bd(scanner) ne ""} { catch {ble stop $::bd(scanner)}; set ::bd(scanner) ""; .bledbg.top.scan configure -text "Start scan" }
    .bledbg.pw.right.tv delete [.bledbg.pw.right.tv children {}]
    array unset ::bdchar; array unset ::bdsub
    bd_log "connecting to $addr …"
    if {[catch {ble connect $addr bd_conn_cb} c]} { bd_log "connect error: $c"; return }   ;# ADDRESS FIRST
    set ::bd(conn) $c; set ::bd(connaddr) $addr; set ::bd(namedone) 0
    .bledbg.top.status configure -text "connecting…"
}
# Many devices don't broadcast a name in their advertisement, so the scan list
# shows them "(unnamed)". Once connected, read the GATT Device Name (0x2A00) in
# Generic Access and relabel the device — iOS also caches it, so later scans then
# show the name too (this is why an iPad that's connected before shows names).
proc bd_autoread_name {su si cu ci} {
    if {$::bd(conn) eq ""} return
    catch {ble read $::bd(conn) $su $si $cu $ci}
}
proc bd_disconnect {} { if {$::bd(conn) ne ""} { catch {ble close $::bd(conn)} }; bd_on_disconnect }
proc bd_on_disconnect {} {
    set ::bd(conn) ""; .bledbg.top.disc configure -state disabled
    .bledbg.top.status configure -text "disconnected"
    foreach b {read sub write} { .bledbg.b.det.$b configure -state disabled }
    .bledbg.b.det.uuid configure -text "(select a characteristic)"
}
proc bd_conn_cb {event data} {
    switch -- $event {
        connection {
            set st [dict get $data state]; bd_log "connection: $st"
            .bledbg.top.status configure -text "connection: $st"
            if {$st eq "connected"} {
                .bledbg.top.disc configure -state normal
                catch {bd_log "MTU [dict get $data mtu]"}
            } elseif {$st eq "disconnected"} { bd_on_disconnect }
        }
        characteristic {
            set tv .bledbg.pw.right.tv
            set su [dict get $data suuid]; set cu [dict get $data cuuid]
            if {[dict get $data state] eq "discovery"} {
                set si [dict get $data sinstance]; set ci [dict get $data cinstance]
                if {![$tv exists $su]} { $tv insert {} end -id $su -text "▸ [bd_name $su]" -open 1 }
                set id "$su/$cu/$ci"
                if {![$tv exists $id]} { $tv insert $su end -id $id -text "  • [bd_name $cu]" }
                set ::bdchar($id) [list $su $si $cu $ci]
                # auto-read the Device Name characteristic to resolve an unnamed device
                if {[bd_ushort $cu] eq "2A00" && !$::bd(namedone)} {
                    after 400 [list bd_autoread_name $su $si $cu $ci]
                }
            } else {
                set acc [dict get $data access]; set v ""; catch {set v [dict get $data value]}
                set tag [dict get {r READ c NOTIFY w WRITE-ack} $acc]
                bd_log "$tag [bd_name $cu]: [bd_hex $v]"
                # resolved Device Name (0x2A00) -> relabel the device in the scan list
                if {[bd_ushort $cu] eq "2A00" && $v ne "" && $::bd(connaddr) ne ""} {
                    set nm [string trimright [encoding convertfrom utf-8 $v] "\x00"]
                    if {$nm ne ""} {
                        set ::bd(namedone) 1
                        set rssi "?"
                        if {[dict exists $::bd(devs) $::bd(connaddr)]} { lassign [dict get $::bd(devs) $::bd(connaddr)] _o rssi }
                        dict set ::bd(devs) $::bd(connaddr) [list $nm $rssi]
                        catch {bd_render_devs}
                        .bledbg.top.status configure -text "connected: $nm"
                        bd_log "resolved device name (0x2A00): $nm"
                    }
                }
            }
        }
        descriptor { bd_log "subscribe confirmed ([bd_name [dict get $data cuuid]])" }
    }
}

# ---- characteristic ops (REAL instance numbers) --------------------------
proc bd_select {} {
    set id [.bledbg.pw.right.tv selection]
    if {$id eq "" || ![info exists ::bdchar($id)]} {
        set ::bd(cur) ""; foreach b {read sub write} { .bledbg.b.det.$b configure -state disabled }; return
    }
    set ::bd(cur) $id
    lassign $::bdchar($id) su si cu ci
    .bledbg.b.det.uuid configure -text "Characteristic [bd_name $cu]   (service [bd_name $su])"
    set en [expr {$::bd(conn) ne "" ? "normal" : "disabled"}]
    .bledbg.b.det.read configure -state $en
    .bledbg.b.det.write configure -state $en
    .bledbg.b.det.sub configure -state $en -text [expr {[info exists ::bdsub($id)] ? "Unsubscribe" : "Subscribe"}]
}
proc bd_read {} {
    if {$::bd(conn) eq "" || $::bd(cur) eq ""} return
    lassign $::bdchar($::bd(cur)) su si cu ci
    if {[catch {ble read $::bd(conn) $su $si $cu $ci} e]} { bd_log "read error: $e" }
}
proc bd_subscribe {} {
    if {$::bd(conn) eq "" || $::bd(cur) eq ""} return
    set id $::bd(cur); lassign $::bdchar($id) su si cu ci
    if {[info exists ::bdsub($id)]} {
        if {[catch {ble disable $::bd(conn) $su $si $cu $ci} e]} { bd_log "unsubscribe error: $e"; return }
        unset ::bdsub($id); .bledbg.b.det.sub configure -text "Subscribe"; bd_log "unsubscribed [bd_name $cu]"
    } else {
        if {[catch {ble enable $::bd(conn) $su $si $cu $ci} e]} { bd_log "subscribe error: $e"; return }
        set ::bdsub($id) 1; .bledbg.b.det.sub configure -text "Unsubscribe"
        bd_log "subscribed [bd_name $cu] — notifications appear below"
    }
}
proc bd_write {} {
    if {$::bd(conn) eq "" || $::bd(cur) eq ""} return
    set hx [string map {" " "" ":" "" "\t" ""} [.bledbg.b.det.hex get]]
    if {[string length $hx] % 2 || ![string is xdigit -strict $hx]} { bd_log "write: enter even hex digits, e.g. 03"; return }
    lassign $::bdchar($::bd(cur)) su si cu ci
    if {[catch {ble write $::bd(conn) $su $si $cu $ci [binary decode hex $hx]} e]} { bd_log "write error: $e" } else { bd_log "wrote $hx to [bd_name $cu]" }
}

bind .bledbg <Destroy> {
    if {"%W" eq ".bledbg"} {
        if {$::bd(conn) ne ""}    { catch {ble close $::bd(conn)} }
        if {$::bd(scanner) ne ""} { catch {ble stop $::bd(scanner)} }
    }
}
bd_log "ready — Start scan, pick a device, Connect, then Read / Subscribe / Write."
bd_log "tip: Skale weight = subscribe to EF81, then Write 03 to EF80 to start the stream."
bd_log "Auto-name: unnamed devices are briefly connected to read their real name (toggle top-right)."
after 2500 bd_autoname_tick
focus .bledbg

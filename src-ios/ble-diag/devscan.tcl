# devscan.tcl <dylib> ?secs? ?svcuuid ...?
set LIB [lindex $argv 0]
set SECS [expr {[llength $argv] >= 2 ? [lindex $argv 1] : 25}]
set SVCS [lrange $argv 2 end]
proc L {m} { set t [clock format [clock seconds] -format %H:%M:%S]; puts "$t $m"; flush stdout }
L "==== devscan pid [pid] tcl [info patchlevel] secs=$SECS svcs=[llength $SVCS] ===="
if {[catch {load $LIB Ble} e]} { L "LOAD FAILED: $e"; exit 1 }
L "loaded ok"
array set ::seen {}; set ::n 0
proc cb {ev args} {
  switch -- $ev {
    state { L "STATE $args" }
    scan {
      array set d {address ? name ? rssi ?}
      catch { array set d [lindex $args 0] }
      if {![info exists ::seen($d(address))]} {
        set ::seen($d(address)) 1; incr ::n
        L [format "DISCOVER #%-3d rssi=%s name='%s' %s" $::n $d(rssi) $d(name) $d(address)]
      }
    }
    default { L "EV $ev $args" }
  }
}
if {[catch {eval ble scanner cb $SVCS} e]} { L "scanner FAILED: $e" } else { L "scanner=$e" }
set ::t 0
proc tick {} {
  incr ::t
  catch {set ps [ble powerstate]} ps
  if {$::t % 5 == 0} { L "t=${::t}s powerstate=$ps unique=$::n" }
  if {$::t >= $::SECS} { L "==== done unique=$::n ===="; catch {ble stop scanner0}; exit 0 }
  after 1000 tick
}
after 1000 tick
vwait forever

# iWish demo: showcase the "borg" iOS bridge (toast, TTS, beep, brightness,
# vibrate, and live device info). borg is AndroWish's device-integration
# command, ported to iOS (UIKit/AVFoundation/CoreBluetooth) for iWish.
if {[catch {package require borg}]} {
    tk_messageBox -icon error -title "borg demo" -message "The borg package failed to load."
    return
}
catch {destroy .borg}
toplevel .borg
wm title .borg "iWish · borg (iOS bridge)"

label .borg.title -text "borg — the iOS device bridge" -font {Helvetica 17 bold}
label .borg.sub -text "AndroWish's device API, ported to iOS for iWish" -fg gray40
pack  .borg.title -pady {10 0}
pack  .borg.sub -pady {0 8}

# ---- actions -------------------------------------------------------------
labelframe .borg.act -text " Actions " -padx 8 -pady 8
pack .borg.act -fill x -padx 10 -pady 4
proc _borg_btn {label cmd} {
    set b .borg.act.[string tolower $label]
    button $b -text $label -width 9 -height 2 -command $cmd
    pack $b -side left -padx 5
}
_borg_btn Toast {catch {borg toast "Hello from iWish borg — Tcl/Tk running natively on iOS!"}}
_borg_btn Speak {catch {borg speak "This is i wish, running Tcl and Tk natively on i oh S, with the borg bridge."}}
# beep: an ascending 3-note chime (also shows the new `borg beep <soundid>`) —
# a single system "Tink" was too short, so play a short sequence.
_borg_btn Beep {
    catch {borg beep 1103}
    after 140 {catch {borg beep 1104}}
    after 280 {catch {borg beep 1105}}
}
# vibrate: iPads have NO vibration motor, so be honest about it.
_borg_btn Vibrate {
    catch {borg vibrate 400}
    set _m ""; catch {set _m [dict get [borg osbuildinfo] model]}
    if {[string match -nocase *ipad* $_m]} {
        catch {borg toast "iPads have no vibration motor — vibrate is silent here (it works on iPhone)."}
    }
}

# ---- brightness ----------------------------------------------------------
labelframe .borg.br -text " Screen brightness " -padx 8 -pady 6
pack .borg.br -fill x -padx 10 -pady 4
scale .borg.br.s -from 0 -to 100 -orient horizontal -length 320 \
    -command {apply {v {catch {borg brightness $v}}}}
catch {.borg.br.s set [expr {int([borg brightness])}]}
pack .borg.br.s -fill x

# ---- live device info ----------------------------------------------------
labelframe .borg.nfo -text " Device info (via borg) " -padx 6 -pady 6
pack .borg.nfo -fill both -expand 1 -padx 10 -pady 4
text .borg.nfo.t -width 58 -height 12 -wrap word -bd 0 -font {Menlo 11} \
    -yscrollcommand {.borg.nfo.sb set}
scrollbar .borg.nfo.sb -command {.borg.nfo.t yview} -width 18
pack .borg.nfo.sb -side right -fill y
pack .borg.nfo.t -side left -fill both -expand 1
.borg.nfo.t tag configure bold -font {Menlo 12 bold}

proc _borg_fmt {v} {
    # format an even-length dict as "key = value" lines; else show raw
    if {[llength $v] > 0 && [llength $v] % 2 == 0} {
        set out ""
        foreach {k val} $v { append out "    [format %-16s $k] $val\n" }
        return $out
    }
    return "    $v\n"
}
proc _borg_info {} {
    set t .borg.nfo.t
    $t delete 1.0 end
    foreach {label sub} {
        "OS / build"      osbuildinfo
        "Display metrics" displaymetrics
        "Locale"          locale
        "Network"         networkinfo
    } {
        set v ""
        if {[catch {borg $sub} v]} { set v "(unavailable: $v)" }
        $t insert end "$label\n" bold
        $t insert end [_borg_fmt $v]
        $t insert end "\n"
    }
}
button .borg.refresh -text "Refresh info" -command _borg_info
pack .borg.refresh -pady {2 10}
_borg_info

focus .borg

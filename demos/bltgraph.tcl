# iWish demo: TkBLT plotting (blt::graph, blt::barchart, blt::vector).
# TkBLT is William Joye's maintained subset of BLT — just the scientific
# plotting widgets, none of the X11-only widgets that can't run on iOS. Built
# for iphoneos/sdl2tk for iWish. Shows a live animated line graph (fed from
# blt::vectors), a bar chart, crosshairs, a legend, and zoom-by-drag.
if {[catch {package require Tkblt} err]} {
    tk_messageBox -icon error -title "TkBLT demo" \
        -message "TkBLT failed to load:\n$err"
    return
}

catch {destroy .blt}
toplevel .blt
wm title .blt "iWish · TkBLT plotting"

label .blt.title -text "TkBLT — scientific plotting on iOS" -font {Helvetica 17 bold}
label .blt.sub -text "blt::graph · blt::barchart · blt::vector (drag to zoom, right-click/2-finger to unzoom)" -fg gray40
pack  .blt.title -pady {10 0}
pack  .blt.sub   -pady {0 6}

# ---- vectors: shared X, two animated Y series --------------------------------
catch {blt::vector destroy xv s1 s2}
blt::vector create xv s1 s2
set N 200
xv seq 0 [expr {2*3.14159265}] [expr {2*3.14159265/($N-1)}]

proc blt_fill {phase} {
    set n [xv length]
    for {set i 0} {$i < $n} {incr i} {
        set x [xv index $i]
        s1 index $i [expr {sin($x + $phase)}]
        s2 index $i [expr {0.6*cos(2*$x - $phase)}]
    }
}
blt_fill 0

# ---- line graph --------------------------------------------------------------
blt::graph .blt.g -width 560 -height 300 -title "Live waveforms" \
    -plotbackground white -background [.blt cget -bg]
.blt.g element create sine  -xdata xv -ydata s1 -color red   -symbol none -linewidth 2
.blt.g element create cosine -xdata xv -ydata s2 -color blue4 -symbol none -linewidth 2
.blt.g axis configure x -title "radians"
.blt.g axis configure y -title "amplitude" -min -1.2 -max 1.2
.blt.g legend configure -position bottom -relief flat
catch {.blt.g crosshairs on}
pack .blt.g -fill both -expand 1 -padx 10 -pady 4

# zoom-by-drag + unzoom (helpers live in TkBLT's graph.tcl / ::blt namespace)
catch {::blt::ZoomStack .blt.g}
catch {::blt::Crosshairs .blt.g}

# ---- bar chart ---------------------------------------------------------------
blt::barchart .blt.b -width 560 -height 190 -title "Bean counters" \
    -plotbackground white -background [.blt cget -bg] -barmode aligned
# one element, several bars: -xdata/-ydata are equal-length lists (a bare
# scalar is not valid TkBLT bar data).
set ::blt_barnames {1 espresso 2 latte 3 cortado 4 filter 5 decaf}
.blt.b element create cups \
    -xdata {1 2 3 4 5} -ydata {34 21 12 8 5} \
    -foreground steelblue4 -background lightblue -relief raised -bd 1 \
    -showvalues y
# turn the numeric x ticks into drink names via the axis -command callback
proc blt_barlabel {w val} {
    set k [expr {int(round($val))}]
    if {[dict exists $::blt_barnames $k]} { return [dict get $::blt_barnames $k] }
    return ""
}
catch {.blt.b axis configure x -title "" -stepsize 1 -subdivisions 1 -command blt_barlabel}
catch {.blt.b axis configure y -title "cups" -min 0}
catch {.blt.b legend configure -hide yes}
pack .blt.b -fill both -expand 1 -padx 10 -pady 4

# ---- animation ---------------------------------------------------------------
set ::blt_anim 1
set ::blt_phase 0
proc blt_tick {} {
    if {![winfo exists .blt.g]} return
    if {$::blt_anim} {
        set ::blt_phase [expr {$::blt_phase + 0.15}]
        blt_fill $::blt_phase
    }
    after 60 blt_tick
}
frame .blt.ctl
checkbutton .blt.ctl.anim -text "Animate" -variable ::blt_anim
button .blt.ctl.ps -text "Print PostScript → Documents/blt.ps" -command {
    catch {.blt.g postscript output [file join $::env(HOME) Documents blt.ps]}
    catch {borg toast "Saved blt.ps to Documents"}
}
button .blt.ctl.close -text "Close" -command {set ::blt_anim 0; destroy .blt}
pack .blt.ctl.anim .blt.ctl.ps .blt.ctl.close -side left -padx 6
pack .blt.ctl -pady {2 10}

blt_tick
focus .blt

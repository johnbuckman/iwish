# iWish demo: finger-paint canvas (pure Tk, touch-friendly for the iPad).
catch {destroy .paint}
toplevel .paint
wm title .paint "iWish Paint"

set ::paint(color) black
set ::paint(size)  8
set ::paint(last)  {}

frame .paint.tools -bd 1 -relief raised
canvas .paint.c -bg white -width 760 -height 500 \
    -highlightthickness 1 -highlightbackground gray70
pack .paint.tools -side top -fill x
pack .paint.c -side top -fill both -expand 1

# colour swatches (big, finger-sized)
foreach col {black red "#ff7f00" "#e8c000" "#2ca02c" "#1f77b4" purple "#8b4513" white} {
    set b .paint.tools.c[string map {# x " " _} $col]
    button $b -bg $col -activebackground $col -width 3 -height 2 -bd 2 \
        -command [list set ::paint(color) $col]
    pack $b -side left -padx 2 -pady 4
}
label  .paint.tools.sl -text "  Brush "
scale  .paint.tools.sz -from 1 -to 40 -orient horizontal -length 160 \
       -variable ::paint(size) -showvalue 1
button .paint.tools.clr -text "Clear" -width 6 -command {.paint.c delete all}
pack   .paint.tools.sl .paint.tools.sz -side left
pack   .paint.tools.clr -side right -padx 8

# draw with mouse OR finger/trackpad drag
bind .paint.c <ButtonPress-1>   {set ::paint(last) [list %x %y]}
bind .paint.c <B1-Motion> {
    if {[llength $::paint(last)]} {
        .paint.c create line {*}$::paint(last) %x %y \
            -fill $::paint(color) -width $::paint(size) \
            -capstyle round -joinstyle round -smooth 1
    }
    set ::paint(last) [list %x %y]
}
bind .paint.c <ButtonRelease-1> {set ::paint(last) {}}

# a friendly hint that clears on first touch
set ::paint(hint) [.paint.c create text 380 250 -text "draw here — pick a colour above" \
    -fill gray70 -font {Helvetica 20}]
bind .paint.c <ButtonPress-1> {+catch {.paint.c delete $::paint(hint)}}

focus .paint

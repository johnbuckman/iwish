# Prove Tk widgets render on iOS via SdlTk + AGG
. configure -bg "#102830"
wm geometry . 400x700
label .title -text "Tk on iOS — via AndroWish stack" \
    -font {Helvetica 22 bold} -fg white -bg "#102830"
pack .title -pady 24
button .b -text "A real Tk button" -font {Helvetica 18}
pack .b -pady 12
checkbutton .ck -text "checkbutton" -font {Helvetica 16} -fg white -bg "#102830" -selectcolor "#205060"
pack .ck -pady 6
scale .s -from 0 -to 100 -orient horizontal -length 250
pack .s -pady 12
.s set 42
canvas .c -width 320 -height 280 -bg white -highlightthickness 0
pack .c -pady 16
.c create oval 20 20 150 150 -fill "#d84040" -outline black -width 3
.c create rectangle 170 40 300 170 -fill "#3cb464" -outline black -width 3
.c create line 20 200 300 200 -fill blue -width 4
.c create text 160 240 -text "AGG anti-aliased canvas" -font {Helvetica 15}
.c create arc 60 180 160 260 -start 0 -extent 220 -fill "#f0dc28"
update

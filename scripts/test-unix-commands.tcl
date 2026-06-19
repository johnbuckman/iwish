#!/usr/bin/env tclsh
# Regression test for the iWish pure-Tcl Unix commands (unix-commands.tcl).
# Pure-Tcl filesystem/text logic, so it runs identically under host tclsh and the
# iWish runtime. Exits 0 if every check passes, 1 otherwise.

set here [file dirname [file normalize [info script]]]
source [file join $here unix-commands.tcl]

# ---- tiny test harness ---------------------------------------------------
set ::pass 0; set ::fail 0
proc ok {name cond} {
    if {[uplevel 1 [list expr $cond]]} {incr ::pass} else {incr ::fail; puts "FAIL: $name"}
}
proc eq {name got want} {
    if {$got eq $want} {incr ::pass} else {
        incr ::fail; puts "FAIL: $name\n      got : [list $got]\n      want: [list $want]"
    }
}
# Capture what a script writes to stdout (the commands use bare `puts`).
proc capture {script} {
    set ::capbuf ""
    rename ::puts ::__realputs
    proc ::puts {args} {
        set a $args; set nonl 0
        if {[lindex $a 0] eq "-nonewline"} {set nonl 1; set a [lrange $a 1 end]}
        if {[llength $a] == 1 || ([llength $a] == 2 && [lindex $a 0] eq "stdout")} {
            append ::capbuf [lindex $a end]
            if {!$nonl} {append ::capbuf "\n"}
            return
        }
        ::__realputs {*}$args
    }
    set code [catch {uplevel 1 $script} res opts]
    rename ::puts {}
    rename ::__realputs ::puts
    if {$code} {return -options $opts $res}
    return $::capbuf
}
proc lines {s} {
    set s [string trimright $s \n]
    if {$s eq ""} {return {}}
    return [split $s \n]
}
proc writef {path content} {set fh [open $path w]; puts -nonewline $fh $content; close $fh}

# ---- sandbox -------------------------------------------------------------
set sb [file join [pwd] iwish-unixtest-[pid]]
file delete -force $sb
file mkdir $sb
set rc 1
if {[catch {

cd $sb

# ---------- mkdir / rmdir ----------
mkdir sub
ok "mkdir creates dir"      {[file isdirectory $sb/sub]}
mkdir a/b/c
ok "mkdir nested"           {[file isdirectory $sb/a/b/c]}
rmdir sub
ok "rmdir removes empty"    {![file exists $sb/sub]}

# ---------- touch ----------
touch t.txt
ok "touch creates file"     {[file exists $sb/t.txt] && [file size $sb/t.txt] == 0}
touch t.txt
ok "touch existing ok"      {[file exists $sb/t.txt]}

# ---------- echo / basename / dirname ----------
eq "echo"        [capture {echo hello world}] "hello world\n"
eq "basename"    [basename /a/b/c.txt] "c.txt"
eq "dirname"     [dirname /a/b/c.txt] "/a/b"

# ---------- cat ----------
writef f.txt "line1\nline2\n"
eq "cat"         [capture {cat f.txt}] "line1\nline2\n"

# ---------- ls ----------
file delete -force d; file mkdir d
writef d/a.txt "x"; file mkdir d/zsub; writef d/.hide "h"
eq "ls"          [capture {ls d}] "a.txt\nzsub/\n"
eq "ls -a"       [lsort [lines [capture {ls -a d}]]] [lsort {.hide a.txt zsub/}]
ok "ls -l dir"   {[regexp {(?m)^d } [capture {ls -l d}]]}
ok "ls -l file"  {[regexp {(?m)^- } [capture {ls -l d}]]}

# ---------- head / tail ----------
set many ""; for {set i 1} {$i <= 12} {incr i} {append many "line$i\n"}
writef big.txt $many
eq "head default" [lines [capture {head big.txt}]] {line1 line2 line3 line4 line5 line6 line7 line8 line9 line10}
eq "head -5"      [lines [capture {head -5 big.txt}]] {line1 line2 line3 line4 line5}
eq "head -n 3"    [lines [capture {head -n 3 big.txt}]] {line1 line2 line3}
eq "tail -2"      [lines [capture {tail -2 big.txt}]] {line11 line12}
eq "tail default" [lines [capture {tail big.txt}]] {line3 line4 line5 line6 line7 line8 line9 line10 line11 line12}

# ---------- grep ----------
writef g.txt "apple\nBanana\ncherry\napricot\n"
eq "grep"        [lines [capture {grep ap g.txt}]] {apple apricot}
eq "grep -i"     [lsort [lines [capture {grep -i AP g.txt}]]] [lsort {apple apricot}]
eq "grep -n"     [lines [capture {grep -n ap g.txt}]] {1:apple 4:apricot}
writef g2.txt "apple pie\n"
eq "grep multi"  [lsort [lines [capture {grep apple g.txt g2.txt}]]] [lsort [list g.txt:apple "g2.txt:apple pie"]]

# ---------- wc ----------
writef w.txt "a\nb\nc\n"
set wcout [capture {wc w.txt}]
ok "wc counts"   {[scan $wcout "%d %d %d" l ww ch] == 3 && $l == 3 && $ww == 3 && $ch == 6}

# ---------- cp / mv ----------
writef src.txt "hello"
cp src.txt dst.txt
ok "cp file"     {[file exists $sb/dst.txt] && [string equal [capture {cat dst.txt}] "hello"]}
file mkdir cpd; writef cpd/inner.txt "z"
cp cpd cpd2
ok "cp dir recursive" {[file exists $sb/cpd2/inner.txt]}
mv dst.txt moved.txt
ok "mv"          {![file exists $sb/dst.txt] && [file exists $sb/moved.txt]}

# ---------- rm ----------
rm moved.txt
ok "rm file"     {![file exists $sb/moved.txt]}
file mkdir rmd; writef rmd/x "1"
rm -rf rmd
ok "rm -rf dir"  {![file exists $sb/rmd]}

# ---------- ln ----------
writef real.txt "data"
ln -s real.txt mylink
ok "ln -s type"   {[file type $sb/mylink] eq "link"}
ok "ln -s target" {[file readlink $sb/mylink] eq "real.txt"}

# ---------- chmod ----------
writef perm.txt "p"
chmod 0o644 perm.txt
ok "chmod 644"   {([file attributes $sb/perm.txt -permissions] & 0o777) == 0o644}
chmod 0o755 perm.txt
ok "chmod 755"   {([file attributes $sb/perm.txt -permissions] & 0o777) == 0o755}

# ---------- du ----------
file delete -force dud; file mkdir dud/inner
writef dud/f1 [string repeat a 10]
writef dud/inner/f2 [string repeat b 20]
set duout [capture {du dud}]
ok "du sums tree" {[scan $duout "%d" n] == 1 && $n == 30}

# ---------- find ----------
file delete -force tree
file mkdir tree/sub
writef tree/a.txt "1"; writef tree/sub/b.txt "2"
eq "find recurse" [lsort [lines [capture {find tree}]]] [lsort {tree tree/a.txt tree/sub tree/sub/b.txt}]
eq "find -name"   [lsort [lines [capture {find tree -name *.txt}]]] [lsort {tree/a.txt tree/sub/b.txt}]

# find must NOT follow a symlink cycle (the bug we fixed)
ln -s [file normalize tree] tree/loop
set cyc [lsort [lines [capture {find tree}]]]
ok "find lists symlink"      {"tree/loop" in $cyc}
ok "find no descend symlink" {[lsearch -glob $cyc tree/loop/*] == -1}

# output cap stops runaway find
file delete -force capd; file mkdir capd
for {set i 1} {$i <= 6} {incr i} {writef capd/f$i ""}
set save $::iwishunix::maxlines
set ::iwishunix::maxlines 3
set capout [lines [capture {find capd -name f*}]]
set ::iwishunix::maxlines $save
set paths [lsearch -all -inline -glob $capout capd/f*]
ok "find cap stops"   {[llength $paths] == 3}
ok "find cap message" {[lsearch -glob $capout {*output truncated at 3 lines*}] != -1}

# ---------- never clobbers an existing command ----------
proc ::__keep {} {return ORIGINAL}
::iwishunix::define __keep {return REPLACED}
eq "no clobber"  [::__keep] "ORIGINAL"

# ---------- syscall-only commands are intentionally absent ----------
foreach c {ps kill df ping ifconfig top mount sudo} {
    ok "absent: $c" {[llength [info commands ::$c]] == 0}
}

set rc 0
} err opts]} {
    puts "EXCEPTION: $err"
    puts [dict get $opts -errorinfo]
    set rc 1
}

# ---- teardown ------------------------------------------------------------
cd $here
file delete -force $sb
puts "-----------------------------------------"
puts "PASS: $::pass   FAIL: $::fail"
if {$::fail == 0 && $rc == 0} {
    puts "ALL TESTS PASSED"
    exit 0
}
exit 1

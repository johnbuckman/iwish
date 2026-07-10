#!/bin/bash
# Batch-build no-dependency AndroWish extensions for armv7/iOS9. Sequential (ld_classic
# must never run concurrently). Logs PASS/FAIL + arch per ext to /tmp/exts_armv7.log.
ROOT=/Users/john/iwish-ios9
JNI=$ROOT/src/androwish/jni
LOG=/tmp/exts_armv7.log; : > "$LOG"
pass=0; fail=0; FAILED=""

# "relpath|extra_cflags"  (extra_cflags optional)
EXTS=(
  "tcl/pkgs/thread2.8.5|"
  "tcl/pkgs/itcl4.2.0|"
  "tdom|"
  "tksvg|"
  "tktable|"
  "tktreectrl|"
  "parse_args|"
  "rl_json|"
  "tclvfs|"
  "trofs|"
  "tclcsv|"
  "Memchan|"
  "nsf|"
  "tcllibc|"
  "tclral|"
  "tclparser|"
  "tcludp|"
  "tkled|"
  "tknotebook|"
  "pikchr|"
  "tcl-lmdb|"
  "tcl-stbimage|"
  "vu|"
  "tbcload|"
  "pty_tcl|"
  "topcua|"
  "tkhtml|"
)

for entry in "${EXTS[@]}"; do
  rel="${entry%%|*}"; xcf="${entry#*|}"
  d="$JNI/$rel"; name="${rel##*/}"
  if [ ! -d "$d" ]; then echo "MISSING $rel" | tee -a "$LOG"; fail=$((fail+1)); FAILED="$FAILED $name"; continue; fi
  echo ">>> building $name" | tee -a "$LOG"
  EXTRA_CFLAGS="$xcf" bash "$ROOT/build-ext-armv7.sh" "$d" >>"$LOG" 2>&1
  dy=$(find "$d" -maxdepth 2 -name '*.dylib' 2>/dev/null | head -1)
  if [ -n "$dy" ] && file "$dy" | grep -q arm_v7; then
    echo "PASS $name -> $(basename "$dy")" | tee -a "$LOG"; pass=$((pass+1))
  else
    echo "FAIL $name" | tee -a "$LOG"; fail=$((fail+1)); FAILED="$FAILED $name"
  fi
done
echo "==== SUMMARY: $pass passed, $fail failed ====" | tee -a "$LOG"
echo "FAILED:$FAILED" | tee -a "$LOG"

#!/bin/bash
# Build the remaining (non-de1app) extensions for armv7/iOS9. Sequential.
ROOT=/Users/john/iwish-ios9; JNI=$ROOT/src/androwish/jni
LOG=/tmp/extras_armv7.log; : > "$LOG"; pass=0; fail=0; FAILED=""
# "relpath|extra_cflags|extra configure args"
EXTS=(
  "itk||--with-itcl=/Users/john/iwish-ios9/src/androwish/jni/tcl/pkgs/itcl4.2.0"
  "tcl/pkgs/tdbc1.1.1||"
  "imgjp2||"
  "tkvnc||"
  "tkpath||"
  "tcl-stbimage|-DSTBIR_NO_SIMD -DSTBI_NO_SIMD|"
  "tkhtml||"
)
# NOTE: tdbcsqlite3-1.1.1 removed from this batch — it is PURE-TCL (empty PKG_LIB_FILE, no
# dylib), so the "did an arm_v7 .dylib appear?" pass/fail check here always marks it FAIL.
# It ships fine via the pure-Tcl staging in build-batteries-armv7.sh (needs tdbc + sqlite3,
# both built). itk now needs --with-itcl (else configure can't find itclConfig.sh → no Makefile).
for entry in "${EXTS[@]}"; do
  IFS='|' read -r rel xcf args <<< "$entry"
  d="$JNI/$rel"; name="${rel##*/}"
  if [ ! -d "$d" ]; then echo "MISSING $rel" | tee -a "$LOG"; fail=$((fail+1)); FAILED="$FAILED $name"; continue; fi
  echo ">>> building $name" | tee -a "$LOG"
  EXTRA_CFLAGS="$xcf" bash "$ROOT/build-ext-armv7.sh" "$d" $args >>"$LOG" 2>&1
  dy=$(rtk proxy find "$d" -name '*.dylib' 2>/dev/null | head -1)
  if [ -n "$dy" ] && file "$dy" | grep -q arm_v7; then echo "PASS $name -> $(basename "$dy")" | tee -a "$LOG"; pass=$((pass+1))
  else echo "FAIL $name" | tee -a "$LOG"; fail=$((fail+1)); FAILED="$FAILED $name"; fi
done
echo "==== EXTRAS SUMMARY: $pass passed, $fail failed ====" | tee -a "$LOG"
echo "FAILED:$FAILED" | tee -a "$LOG"

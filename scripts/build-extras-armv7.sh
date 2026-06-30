#!/bin/bash
# Build the remaining (non-de1app) extensions for armv7/iOS9. Sequential.
ROOT=/Users/john/iwish-ios9; JNI=$ROOT/src/androwish/jni
LOG=/tmp/extras_armv7.log; : > "$LOG"; pass=0; fail=0; FAILED=""
# "relpath|extra_cflags|extra configure args"
EXTS=(
  "itk||"
  "tcl/pkgs/tdbc1.1.1||"
  "tcl/pkgs/tdbcsqlite3-1.1.1||"
  "imgjp2||"
  "tkvnc||"
  "tkpath||"
  "tcl-stbimage|-DSTBIR_NO_SIMD -DSTBI_NO_SIMD|"
  "tkhtml||"
)
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

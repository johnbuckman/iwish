#!/bin/bash
#
# Apply the iWish (iOS) patches to an AndroWish checkout + an SDL 2.30.11 tree.
#
# Usage:  ./apply-patches.sh /path/to/androwish /path/to/SDL2-2.30.11
#
#   - patches/androwish-*.patch  -> applied at the AndroWish root (git apply / patch -p1)
#   - patches/sdl2/*.patch       -> applied at the SDL2 root (patch -p1)
#
# Re-running is safe-ish: already-applied patches are detected and skipped.
set -uo pipefail

AW="${1:-}"
SDL="${2:-}"
if [ -z "$AW" ] || [ ! -d "$AW/jni" ]; then
    echo "usage: $0 /path/to/androwish /path/to/SDL2-2.30.11" >&2
    exit 1
fi
HERE="$(cd "$(dirname "$0")" && pwd)"

apply_one() { # $1 = root dir, $2 = patch file
    local root="$1" pf="$2" name; name="$(basename "$pf")"
    ( cd "$root" || exit 1
      if patch -p1 --dry-run --reverse -f <"$pf" >/dev/null 2>&1; then
          echo "skip (already applied): $name"; exit 0
      fi
      if patch -p1 --dry-run -f <"$pf" >/dev/null 2>&1; then
          patch -p1 <"$pf" >/dev/null && echo "applied: $name"
      else
          echo "FAILED (does not apply cleanly): $name" >&2; exit 2
      fi )
}

echo "== AndroWish patches =="
for pf in "$HERE"/patches/androwish-*.patch; do apply_one "$AW" "$pf"; done

if [ -n "$SDL" ] && [ -d "$SDL/src/video/uikit" ]; then
    echo "== SDL2 uikit patches =="
    for pf in "$HERE"/patches/sdl2/*.patch; do apply_one "$SDL" "$pf"; done
else
    echo "(skipping SDL2 patches: pass the SDL2-2.30.11 root as arg 2 to apply them)"
fi
echo "done."

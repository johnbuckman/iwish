# iWish on iOS 9 / armv7 (32-bit) — jailbroken iPad mini 1 and friends

This is the 32-bit **armv7 / iOS 9.3** build of iWish, in addition to the modern arm64
iOS/Catalyst build documented in `README.md`. Target hardware: A5/A6-class devices that top
out at iOS 9.3.5 (iPad mini 1 / iPad 2 / iPad 3, etc.) — **no Metal, 32-bit, BLE 4** — deployed
to a **jailbroken** device (no App Store / provisioning needed).

Status: the full stack (FreeType, SDL2, AndroWish Tcl 8.6.10, sdl2tk+AGG, `sdl2wish`) builds
`armv7-apple-ios9.0` and **runs on a real iPad mini 1**. Tcl regression suite: 46075 tests,
38578 passed, 55 failed (all floating-point `long double` precision + 1 fs — armv7's
`long double` == `double`). Tk (sdl2tk) suite: 7930 tests, 6717 passed, 83 failed (all in
sdl2tk's reduced-X11 backend: fonts/events/WM — not armv7 bugs).

## The toolchain problem (and the fix)

Apple clang 21 (Xcode 26) has a **broken armv7 integrated assembler** — it cannot assemble
Tcl's enormous `TEBCresume` function ("Relocation Not In Range", at any -O level, ARM or
Thumb). Apple has deprecated 32-bit, so the backend has bit-rotted.

Fix: a **CC wrapper** (`scripts/armv7-toolchain/cc`) that **compiles with the NDK's clang-18**
(a healthy upstream LLVM) using `--target=armv7-apple-ios9.0`, but **links with Apple clang +
`-Wl,-ld_classic`** (the classic linker — the modern one chokes on the old SDK's `.tbd`s; this
is the same proven path used for the Kitchen Timer jailbreak app). C++ (`cxx`) uses Apple
clang++ `-stdlib=libc++` (AGG's C++ isn't huge, so it doesn't hit the assembler bug).

Adjust the `NDK` path in `scripts/armv7-toolchain/cc`/`cxx` to your NDK install.

## theos 9.3 SDK fixups (the SDK is sparse — `build-device-armv7.sh` applies these idempotently)

- `libsystem_c.tbd`: append `mem*` and `str*` symbol batches (the stub omits strchr/strcmp/…).
- add `liblaunch.tbd`.
- copy `AvailabilityVersions.h` from the modern SDK; write a **minimal `crt_externs.h`** (the
  modern one pulls in `_bounds.h`, absent in 9.3).
- copy the **entire libc++ v1 header set** from the modern SDK (the theos SDK ships only
  libstdc++ 4.2.1). Linking C++ needs explicit `-lc++ -lc++abi` (operator new/delete live in
  libc++abi; the driver won't auto-add it on armv7).

## SDK API-floor source guards (`patches/sdl2-ios9/`)

SDL 2.30.11 uses iOS-10/11/15 APIs unconditionally; under the 9.3 SDK they don't exist, so they
are gated with `__IPHONE_OS_VERSION_MAX_ALLOWED >= NNNNN`:
- `SDL_sysurl.m` — `openURL:options:completionHandler:` (iOS 10) → fall back to `openURL:`
- `SDL_uikitappdelegate.m` — `application:openURL:options:` / `UIApplicationOpenURLOptionsKey` (iOS 10)
- `SDL_uikitviewcontroller.m.ios9` — `setNeedsUpdateOf…` (iOS 11), `CAFrameRateRange` (iOS 15)

Also build SDL2 with **GLES2, Metal OFF** (A5 has no Metal) and unused subsystems off
(`-DSDL_AUDIO/JOYSTICK/HAPTIC/HIDAPI/SENSOR=OFF` — Tk doesn't need them and they pull in more
iOS-10 APIs), plus global `-Wno-undef-prefix` (the 9.3 `TargetConditionals.h` predates
`TARGET_OS_OSX`/`TARGET_OS_MACCATALYST`).

## Build + deploy

```
bash scripts/build-device-armv7.sh   # foundation -> sdl2wish (Mach-O arm_v7, minos 9.0)
bash scripts/build-app-armv7.sh      # -> dist/iWish-armv7.app, ldid-signed (org.iwish.tk)
```
Deploy to the jailbroken device: tar+gzip the .app, `ssh "cat > /tmp/x.tgz"`, extract to
`/Applications/iWish.app`, `uicache -p`. **Launch via SpringBoard** with the registered URL
scheme: `uiopen iwish://run` (uiopen can't launch by bundle id). Tcl-only work runs straight
over SSH with the bundled `tclsh`; the Tk GUI must run under SpringBoard.
```
```

## Batteries (AndroWish extensions) for armv7/iOS9

Build extensions to loadable armv7 dylibs (NDK-compile + Apple/ld_classic link, theos SDK,
TCL_UTF_MAX=6, 32-bit ABI cache, clang16+ -Wno-error downgrades):
- `scripts/build-ext-armv7.sh <extdir> [cfg args]` — one TEA extension.
- `scripts/build-allexts-armv7.sh` — batch of dep-free exts (sqlite3, tdom, thread, itcl,
  tksvg, tktable, tktreectrl, rl_json, nsf, vu, tkled, pikchr, lmdb, … — 25 build clean).
- `scripts/build-blt-armv7.sh` — BLT 2.4 (tkblt, de1app shot graph). CRITICAL armv7 ABI cache
  void_p=4; drop `-Dfinite=isfinite` (the 9.3 math.h declares `finite`); `make -C src build_shared`.
- `scripts/build-shims-armv7.sh` — borg + ble ObjC shims (Apple clang armv7 directly).
- `scripts/build-libressl-armv7.sh` + `build-tls-armv7.sh` — tls via static LibreSSL
  (`make -C include` FIRST to generate opensslconf.h; `endian_compat.c` provides be32toh etc.).
- tkimg (img::jpeg + 24 handler/codec dylibs): `build-ext-armv7.sh tkimg` with
  `EXTRA_CFLAGS=-DPNG_ARM_NEON_OPT=0` (bundled zlib/libpng/libtiff/libjpeg).
- zint: `build-ext-armv7.sh zint/backend_tcl`.
- sqlite3 needs `ac_cv_func_strchrnul=no` (iOS lacks strchrnul; use sqlite's built-in fallback).
- `scripts/build-batteries-armv7.sh` — collect all dylibs + pkgIndex + companion .tcl into
  `dist/iWish-batteries-armv7/lib/<pkg>/`.

Verified on the iPad mini 1 (load-test under wish): **55 packages load**, including every de1app
native dep — BLT, Img/img::jpeg (+all formats), sqlite3, tls, tdom, tksvg, Tktable, treectrl, vu,
Itcl, zint, Borg, Ble, Thread. Remaining failures are non-de1app pure-Tcl companion-script
placement (tclvfs::template/*, ral, tclcsv, trofs, topcua). Tk exts need `*_LIBRARY` env
(ITCL_LIBRARY/ITK_LIBRARY/TREECTRL_LIBRARY/VU_LIBRARY) set to their package dir.

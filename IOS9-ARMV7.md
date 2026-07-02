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
- `scripts/build-ext-armv7.sh <extdir> [cfg args]` — one TEA extension. Passes
  `make TCLSH_PROG=$HOSTTCLSH` (a **native** tclsh, default `/usr/local/bin/tclsh`) so any
  build-time code generation runs on the host — the cross-target armv7 `tclsh` cannot execute on
  the Mac (`Bad CPU type in executable`), which otherwise silently kills exts like tkhtml.
- `scripts/build-allexts-armv7.sh` — batch of dep-free exts (sqlite3, tdom, thread, itcl,
  tksvg, tktable, tktreectrl, rl_json, nsf, vu, tkled, pikchr, lmdb, … — 25 build clean).
- `scripts/build-extras-armv7.sh` — the rest (itk, tdbc, imgjp2, tkvnc, tkpath, tcl-stbimage,
  tkhtml). **itk needs `--with-itcl=<…/tcl/pkgs/itcl4.2.0>`** (else configure can't find
  `itclConfig.sh` and never writes a Makefile → no dylib).
- `scripts/build-blt-armv7.sh` — BLT 2.4 (tkblt, de1app shot graph). CRITICAL armv7 ABI cache
  void_p=4; drop `-Dfinite=isfinite` (the 9.3 math.h declares `finite`); `make -C src build_shared`.
- `scripts/build-shims-armv7.sh` — borg + ble ObjC shims (Apple clang armv7 directly).
- `scripts/build-libressl-armv7.sh` + `build-tls-armv7.sh` — tls via static LibreSSL
  (`make -C include` FIRST to generate opensslconf.h; `endian_compat.c` provides be32toh etc.).
- `scripts/build-curl-armv7.sh` + `build-tclcurl-armv7.sh` — libcurl (static, armv7) + TclCurl.
  TLS is the armv7 LibreSSL (`--with-ssl=/tmp/ssl-armv7`), **not** Secure Transport: the sparse
  theos 9.3 SDK is missing `CoreServices.framework`, which `--with-secure-transport` requires.
  curl's cross-compile link-probes are pre-answered via its own `curl_cv_func_recv/send/select`
  cache vars, and `endian_compat.c` is linked so LibreSSL's `be32toh`/etc. resolve.
- tkimg (img::jpeg + 24 handler/codec dylibs): `build-ext-armv7.sh tkimg` with
  `EXTRA_CFLAGS=-DPNG_ARM_NEON_OPT=0` (bundled zlib/libpng/libtiff/libjpeg).
- zint: `build-ext-armv7.sh zint/backend_tcl`.
- sqlite3 needs `ac_cv_func_strchrnul=no` (iOS lacks strchrnul; use sqlite's built-in fallback).
- `scripts/build-batteries-armv7.sh` — collect all dylibs + pkgIndex + companion scripts into
  `dist/iWish-batteries-armv7/lib/<pkg>/`. Preserves `library/<subdir>/` layout (e.g. tclvfs's
  `template/`), and stages `*.tcl`/`*.tm`/`*.itk`/`*.itcl`/`tclIndex` from `src`/`lib`/`library`/
  `generic` so `tcl_findLibrary` packages (itk mega-widgets, TclCurl's `generic/tclcurl.tcl`) work.
- `scripts/check-battery-pkgindex.tcl <libdir>` — static verifier: parses every staged
  `pkgIndex.tcl`, resolves each `[file join $dir …]` source/load target, and reports any missing
  file. Run it after `build-batteries-armv7.sh` (expected: `0 have missing source/load targets`).

**111 packages assembled; verifier reports 0 missing source/load targets.** Every de1app native
dep loads on the iPad mini 1 under wish — BLT, Img/img::jpeg (+all formats), sqlite3, tls, tdom,
tksvg, Tktable, treectrl, vu, Itcl, Itk, zint, Borg, Ble, Thread. Also builds: tkhtml, tkpath,
tkvnc, imgjp2, tcl-stbimage, tdbc(+sqlite3), TclCurl, iwidgets (on itk). Tk/`tcl_findLibrary` exts
need their `*_LIBRARY` env (ITCL_LIBRARY/ITK_LIBRARY/TREECTRL_LIBRARY/VU_LIBRARY) set to the
package dir. `tdbc::sqlite3` is pure-Tcl (no dylib — don't treat "no arm_v7 dylib" as a failure).

## M2 — de1app running on the iPad mini 1

`scripts/build-de1app-armv7.sh` → `dist/IwishDE1-armv7.app` (65M). de1app boots, renders its
GUI, and runs on the jailbroken iPad mini 1 (iPad2,5, A5, 512MB, iOS 9.3.5).

**Split layout** (system `/` had only ~196M free, so the 433M de1plus tree cannot live in the
app bundle):
- app (65M) → `/Applications/IwishDE1.app`: armv7 `sdl2wish` (renamed `IwishDE1`),
  `lib/{tcl8.6,tk8.6}`, `lib-batteries` (the armv7 battery packages), `libhardexit.dylib`
  (+ `lib-batteries/hardexit/pkgIndex.tcl`), a thin launcher `main.tcl`, `Info.plist`
  (`com.decent.de1app`, BLE usage keys, landscape, URL scheme `de1app://`).
- de1plus (433M, the arch-independent curated `de1plus` tree, reused as-is) → `/private/var/de1plus`.
- writable home → `~/Documents/Decent` (ios.tcl seeds it on first run).

The launcher sources de1plus from `/private/var/de1plus`; `ios.tcl` recomputes `$::home` via
`file dirname [info script]`, so it resolves there automatically. Launch with `uiopen de1app://run`.
`scripts/hardexit.c` builds the armv7 `libhardexit.dylib` (`clang -dynamiclib -arch armv7
-include unistd.h ... build/awtcl-armv7/libtclstub8.6.a`); de1app's `ios_install_hardexit`
routes `exit` through it.

**Result:** iOS detection, full data-tree seeding, hardexit load, all native batteries, and GUI
rendering (sdl2tk AGG software rasterizer + SDL software blits, presented via GLES2 — the A5 has
no Metal) all work, confirmed by on-device `spindump` (`ImgPhotoPutResizedRotatedBlock` at startup,
then `doDrawRect<agg::pixfmt_alpha_blend_rgba>` + `SDL_Blit_*_Modulate_Blend` steady state).

**Performance** is the limiting factor: startup is multi-minute (Tk photo-image scaling of skin
assets pegs both A5 cores; iOS logs non-fatal `EXC_RESOURCE CPU` watchdog warnings, not crashes),
and steady state holds ~0.7–0.8 of one core in software compositing. Memory is tight (~58MB free,
heavy VM-compressor churn) but does not jetsam. Functional proof-of-concept; not snappy. The clear
next optimization is pre-scaling the skin PNGs to 1024×768 once (or a lighter skin) to cut the boot.

**BLE** is bundled (Ble ext + de1app stack) but was not interactively confirmed: CoreBluetooth's
first-use permission prompt needs a human tap and no DE1 is paired in this setup.

Device debugging notes: the device lacks `head`/`tail`/`wc`/`du`/`syslog`; use `spindump <pid>
<secs> <ms> -stdout` then pull and symbolicate with `atos -arch armv7`. de1app's `log.txt` is
64KB-buffered (stays 0 until flush) — on iOS it logs via `borg log`→NSLog. The unbuffered
`~/Documents/Decent/de1_exit.log` and the launcher's `/var/mobile/Documents/de1_launch.log` are
the reliable traces. The app runs as user `mobile` (HOME=/var/mobile).

## M3 — on-device de1app polish (brightness, status bar, BLE)

Subsequent builds tightened three rough edges found while running de1app on the jailbroken
iPad mini 1. All changes are in `src-ios/borg-ios/tclBorgios.m`, `src-ios/ble-ios/tclBLEios.m`,
`patches/sdl2-ios9/`, and the `Info.plist` emitted by `build-de1app-armv7.sh` /
`build-app-armv7.sh`.

1. **Toast grey-rectangle artifact — fixed.** The iOS `borg toast` SDL-layer geometry was re-synced
to the C present-layer blit (see `tclBorgios.m` `_toast_sdl`).

2. **Brightness "randomly" changing — fixed.** `borg systemui` already set
`UIApplication.idleTimerDisabled=YES`, but de1app's call path may be Android-gated on iOS. Added
an unconditional `application.idleTimerDisabled = YES` in SDL's
`application:didFinishLaunchingWithOptions:` and a redundant set in `Borg_Init` so the screen
stays awake regardless of whether `borg systemui` is reached.

3. **Status bar (wifi/time) showing — fixed.** The previous `UIStatusBarHidden=true` +
`UIViewControllerBasedStatusBarAppearance=false` combination did not hide the bar because SDL only
sets `UIApplication.statusBarHidden` when a launch storyboard is present. Added an explicit
`[application setStatusBarHidden:YES animated:NO]` in SDL's app delegate and again in SDL's view
controller `viewDidLayoutSubviews`, and flipped `UIViewControllerBasedStatusBarAppearance` to
`true` so SDL's `prefersStatusBarHidden=YES` also governs.

4. **BLE discovery — improved diagnostics, still hardware-limited.** The BLE shim was made
portable (TARGET_OS guards + log-path macro) and the `CBCentralManager` is now created synchronously
on the calling thread with a dedicated delegate queue (the previous "create on delegate queue"
pattern left XPC half-wired). Scan now passes
`CBCentralManagerScanOptionAllowDuplicatesKey=@YES` and a `ble state` subcommand was added for
cleaner bootstrap. On the iPad mini 1 the scan reaches `poweredOn` and `isScanning=1` but still
receives zero advertisements; this points to the iOS 9 Bluetooth stack / radio on that specific
device and is best verified by completing the macOS reference test (host with
`NSBluetoothAlwaysUsageDescription`).

**To deploy the M3 fixes:** rebuild the foundation (`build-device-armv7.sh`), rebuild the
shims (`build-shims-armv7.sh`), rebuild the app bundles (`build-app-armv7.sh` and/or
`build-de1app-armv7.sh`), re-sign with `ldid`, push to the device, and run `uicache -p` before
cold-launching. Verify dylib freshness by md5-comparing the on-device dylib to the freshly-built
one.


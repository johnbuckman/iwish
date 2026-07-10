# AGENTS.md — start here if you're an AI agent

This file orients an AI coding agent (Claude Code, etc.) working on **iWish**.
Read it first, then jump to the specific doc you need. Humans: see
[`README.md`](README.md).

## What iWish is, in three sentences

iWish is **AndroWish's `undroidwish`** — a batteries-included, SDL2-rendered
Tcl 8.6 / Tk 8.6 `wish` — **cross-compiled for iOS/iPadOS (`arm64-apple-ios`)**.
Tk is drawn through AndroWish's **SdlTk** (an X11-on-SDL2 emulation layer, `SdlTkX`)
onto an SDL2 Metal surface — there is **no UIKit widget bridge**; the actual Tk
canvas/widgets render natively. This repo is a **recipe** (build scripts +
patches against upstream + iOS-native glue), not a redistribution of AndroWish/
SDL2/Tcl/Tk sources.

## The map — where everything is

| Path | What it is |
|------|-----------|
| [`README.md`](README.md) | Human overview: what works, how it's built, the patch list, the build outline, the built-in Unix commands. **The authoritative build reference.** |
| [`INSTALL.md`](INSTALL.md) | How end users install the `.ipa` (Sideloadly / AltStore / from source / EU notarized), with the Sideloadly-vs-AltStore comparison. |
| [`scripts/`](scripts) | The build recipe. `build-device.sh` (foundation), `build-ext-dev.sh` (extension stack), `build-tkblt-dev.sh` (TkBLT plotting), `build-blt-dev.sh` (BLT 2.4), `build-device-batteries.sh` (stage the full battery set), `build-utf6.sh`, `sign-and-install-device.sh`, `unix-commands.tcl`. |
| [`launcher/main.tcl`](launcher/main.tcl) | The iWish app launcher: boots the Tk console (titled "iWish"), loads `borg`, registers the **File ▸ Demos** menu, positions windows on launch. This is the app's entry point (auto-run by the patched `tkAppInit.c`). |
| [`demos/`](demos) | The custom Tk demos wired into the Demos menu: `bltgraph.tcl` (TkBLT plotting), `bledemo.tcl` (LightBlue-style BLE debugger), `borgdemo.tcl` (the iOS `borg` bridge), `paint.tcl`. |
| [`src-ios/`](src-ios) | iOS-native shims (`.m`): `borg-ios` (device bridge), `ble-ios` (CoreBluetooth), `hardexit` (clean `_exit`), `ble-diag` (BLE diagnostics). Each file's header has the exact `clang` line. |
| [`patches/`](patches) | Patches against AndroWish's `jni/sdl2tk` and stock **SDL 2.30.11**. Applied via [`apply-patches.sh`](apply-patches.sh). Changes are also marked inline with `iwish:` comments. |
| [`BUGS.md`](BUGS.md), [`TODO.md`](TODO.md) | Known issues and roadmap. |
| `IOS9-*.md` | The **separate 32-bit armv7 / iOS 9** port (jailbroken A5/A6 devices, e.g. iPad mini 1). Different target — don't conflate with the arm64 build. Full-source sibling repo: [`iwish-ios9`](https://github.com/johnbuckman/iwish-ios9). |

Sibling repo for the macOS Apple-Silicon build:
[`undroidwish-arm64-batteries-included`](https://github.com/johnbuckman/undroidwish-arm64-batteries-included).

## Current state (v0.2-alpha)

Runs the full battery set on a physical iPad: **~114 bundled packages, 64 of them
native `arm64-apple-ios` dylibs** (tkimg, tls/LibreSSL, TclCurl, sqlite3, itcl,
itk, thread, tdom, Tktable, tktreectrl, zint, Img, tkpath, tkvnc, **TkBLT**, Tix,
vectcl, …), plus the `borg`/`ble` iOS shims. A **File ▸ Demos** menu in the
console launches the bundled demo apps; extensions that can't exist on iOS appear
greyed-out.

## Gotchas an agent must know before building extensions

These are hard-won; violating them wastes hours:

- **Load-time symbol resolution.** Extensions are linked `-Wl,-undefined,dynamic_lookup`
  against Tcl/Tk **stubs** (`build/awtcl-dev` + `sdl2tk/sdl`). Undefined `Tcl_*`/
  `Tk_*`/`SdlTkX*` symbols resolve at load against the `sdl2wish` binary (which
  exports them as `T`). Use [`scripts/build-ext-dev.sh`](scripts/build-ext-dev.sh)
  as the harness; don't hand-roll link lines.
- **`-DTCL_UTF_MAX=6`** everywhere. The runtime is UCS-4; an extension built at
  the stock UTF_MAX=3 refuses to load ("different Tcl_UniChar types" — tdom is
  strict about this).
- **"Deep" extensions** (those that `#include` `tkInt.h` → `tkPort.h`: Tix, BLT,
  TkBLT, …) need **`-DPLATFORM_SDL -I <sdl2tk>/sdl`** so Tk uses sdl2tk's port
  instead of the real X11 one, and you must **strip `-lX11`/`-L/opt/X11`** from
  the generated Makefile (else it links macOS XQuartz).
- **No `fork`/`exec`/`system()`.** iOS sandboxes them. `exec ls` etc. never work
  — pure-Tcl replacements live in `scripts/unix-commands.tcl`. Extensions that
  shell out (Expect, some f2c code) must be patched or dropped.
- **No desktop OpenGL/GLU, no fixed-function GL.** iOS has GLES2 shaders only, so
  Canvas3d/Tkzinc are infeasible.
- **`pkgIndex.tcl` bare-load bug** (recurring in AndroWish exts): pkgIndexes often
  do `load libX[info sharedlibextension]` — a bare name with no `$dir` and the
  wrong version → fix to `load [file join $dir libX-version.dylib] Init`.
- **Verify on-device by log, not screenshot.** Append a temp self-test to
  `launcher/main.tcl` that writes `Documents/*.log`, deploy, launch, then pull it
  with `xcrun devicectl device copy from --domain-type appDataContainer`. Beware
  the **log-read race**: read only after the self-test's `after` delay elapses,
  and grep for a *fresh* marker (you can otherwise grab the previous launch's log).

## Signing / install, in one line

`scripts/sign-and-install-device.sh <app> <identity> <profile.mobileprovision> <udid> <entitlements.plist>`
then `xcrun devicectl device process launch --terminate-existing --device <udid> <bundle-id>`.
Free Apple ID → 7-day signing; paid ($99/yr) → 1 year. See [`INSTALL.md`](INSTALL.md).

## License

Tcl/Tk (BSD-style) license — see [`LICENSE`](LICENSE). Upstream AndroWish/SDL2/
Tcl/Tk and bundled third-party libraries keep their own licenses.

# `borg osbuildinfo` — platform identification

The iWish borg (`tclBorgios.m`) implements `borg osbuildinfo`, which returns a
flat Tcl dict modeled on Android's `android.os.Build.*`. **Every AndroWish-family
build fills these standard keys with real values for its platform**, so callers
can identify the platform from the existing keys alone — no extra or custom key
is added.

This file documents the contract across all builds so the iWish, undroidwish
(macOS desktop), and Android implementations stay consistent.

## Keys, per platform

| key | Android (e.g. Teclast) | macOS desktop (undroidwish) | iWish — iOS device | iWish — iOS simulator | iWish — Mac Catalyst |
|---|---|---|---|---|---|
| `manufacturer` | device maker (`Teclast`) | `Apple` | `Apple` | `Apple` | `Apple` |
| `brand` | device brand | `Apple` | `Apple` | `Apple` | `Apple` |
| `product` | build product (`M50Mini`) | `MacBook Air` (`system_profiler`) | `iPad` / `iPhone` | `iPad` / `iPhone` | `Mac` |
| `model` | `M50Mini` | `Mac16,12` (`hw.model`) | `iPad13,1` (`hw.machine`) | `iPad13,1` (`SIMULATOR_MODEL_IDENTIFIER`) | `Mac16,12` (`hw.model`) |
| `device` | `M50Mini` | = model | = model | = model | = model |
| `cpu_abi` | `arm64-v8a` | `arm64` (`hw.machine`) | `arm64` | `arm64` | `arm64` |
| `version.release` | `14` (Android) | `26.2` (`kern.osproductversion`) | iOS version (`UIDevice.systemVersion`) | iOS version | iOS-compat version |
| `version.sdk` | `34` (API level) | `0` (n/a) | `0` | `0` | `0` |
| `board` | `mt6771` | `hw.target` | = model | = model | = model |
| `hardware` | `mt8788` | `Apple M4` (cpu brand) | = model | = model | = model |
| `fingerprint` | Android format | `Apple/undroidwish/<model>:<rel>/<darwin>/0:user/release-keys` | `Apple/iWish/<model>:<rel>/0:user/release-keys` | same form | same form |
| `serial` | `unknown` | `unknown` | `unknown` | `unknown` | `unknown` |
| `tags` / `type` | `release-keys` / `user` | same | same | same | same |

## How a caller identifies the platform

```tcl
set bi [borg osbuildinfo]
set apple [expr {[dict exists $bi manufacturer] && [dict get $bi manufacturer] eq "Apple"}]

# iWish (iOS-only) = Apple manufacturer + an iPad/iPhone/iPod model.
set ios   [expr {$apple && [dict exists $bi model] \
                 && [regexp {^(iPad|iPhone|iPod)} [dict get $bi model]]}]
set iwish $ios
```

Resulting matrix:

| platform | `manufacturer` | `product` | `model` | apple | iwish | ios |
|---|---|---|---|:--:|:--:|:--:|
| Android | device maker | build product | device model | 0 | 0 | 0 |
| macOS desktop (undroidwish) | `Apple` | `MacBook Air` (etc.) | `Mac…` | 1 | 0 | 0 |
| iWish iOS device / simulator | `Apple` | `iPad` / `iPhone` | `iPad…`/`iPhone…` | 1 | 1 | 1 |
| iWish Mac Catalyst | `Apple` | `Mac` | `Mac…` | 1 | 0 | 0 |

## Rationale / gotchas

- **Standard `osbuildinfo` keys only** — no extra/custom key is added; the
  platform is read entirely from the values above.
- **`model` is the discriminator** (`iPad`/`iPhone`/`iPod` ⇒ iOS/iWish; `Mac..`
  ⇒ desktop/Catalyst). **`product` is the friendly Apple product name**
  (`iPad`/`iPhone` on iOS, `MacBook Air` etc. on macOS) — informational. iWish is
  treated as iOS-only, so a Mac (Catalyst or undroidwish) is never `::iwish`.
- **`model` is read from `sysctl`, NOT `[UIDevice model]`.** On Mac Catalyst
  `[UIDevice currentDevice].model` returns `"iPad"`, which would make Catalyst
  look like iOS. `tclBorgios.m` therefore uses, at compile time (one dylib per
  target): `hw.machine` on iOS, `SIMULATOR_MODEL_IDENTIFIER` in the simulator,
  and `hw.model` on Mac Catalyst.
- **`version.sdk` is Android-only** — the API level (e.g. `34` = Android 14).
  There is no Apple equivalent, so it is `0` on Apple builds. Likewise the
  strongest "this is Android" tells in the table are `version.sdk` (a real API
  level), the Android-format `fingerprint`, and `cpu_abi arm64-v8a`.
- **Android itself is not necessarily detected via osbuildinfo** — a caller can
  instead key off the presence of the real `ble`/`BLT` packages. osbuildinfo's
  job here is to split the Apple builds (iOS vs Catalyst vs desktop).

## Where this is implemented

- iWish (iOS/iPadOS/Catalyst): [`tclBorgios.m`](tclBorgios.m), `osbuildinfo` case.
- macOS desktop (undroidwish): `jni/src/tkBorgOSX.c` `BorgOSBuildInfo()` — see
  [`undroidwish-arm64-batteries-included` / `BORG-OSX.md`](https://github.com/johnbuckman/undroidwish-arm64-batteries-included/blob/main/BORG-OSX.md).

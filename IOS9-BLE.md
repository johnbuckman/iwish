# iWish / de1app on a jailbroken iOS 9.3.5 device (32-bit / armv7)

This document explains how to run the iWish port of the Decent Espresso **de1app**
on an old **32-bit** Apple device, why it **requires a jailbreak**, how to jailbreak
the device, and how the **Bluetooth (BLE)** support works. For the low-level build
toolchain (compiler, SDK, batteries) see [IOS9-ARMV7.md](IOS9-ARMV7.md); this doc is
the device-setup + deployment + Bluetooth guide.

Target device: **32-bit A5/A5X devices on iOS 9.3.5** — the last iOS these devices
can run. Verified on an **iPad mini 1 (iPad2,5)**.

---

## 1. Why this needs a jailbreak

iWish/de1app is an unsigned Tcl/Tk application (an `sdl2wish` binary plus a large
Tcl code + assets tree). Running it on iOS requires things Apple does not allow on a
stock device:

- **Run unsigned/ad-hoc-signed native code** — the app is signed with `ldid`, not a
  paid Apple Developer certificate, and it loads unsigned battery dylibs at runtime.
- **Install to `/Applications` and write to the filesystem** — the app bundle and its
  433 MB `de1plus` data tree live outside the normal sandbox.
- **Deploy and debug over SSH** — pushing builds, signing on-device, and reading logs.
- **Launch by URL scheme** (`uiopen iwish://run`) since there is no App Store listing.

None of that is possible on a stock, non-jailbroken device. These are also
end-of-life 32-bit devices with no modern App Store path, so a jailbreak is the only
way to run the app at all.

---

## 2. Jailbreaking iOS 9.3.5 (Phoenix)

**[Phoenix](https://phoenixpwn.com/)** is the jailbreak for **iOS 9.3.5 / 9.3.6 on
32-bit devices** (iPhone 4S/5/5c, iPad 2/3/4, iPad mini 1). It is **semi-untethered**.

### Steps
1. **Sideload the Phoenix `.ipa`** onto the device (Cydia Impactor, AltStore, or any
   sideloading method that signs with your Apple ID).
2. On the device, **trust the developer certificate**:
   *Settings → General → Profiles & Device Management → trust your Apple ID*.
3. Open **Phoenix** and tap **Jailbreak**. It installs **Cydia**.
4. From Cydia, install **OpenSSH** (for deployment) — and change the default root
   password (`alpine`).

### ⚠️ Semi-untethered — you must re-jailbreak after every reboot
The jailbreak **does not survive a reboot**. After any reboot (or power-off), the
device boots into a normal, un-jailbroken state — **SSH, Cydia, and unsigned apps stop
working** until you re-open **Phoenix** and tap **Jailbreak** again. This is an
**on-device** action (no computer needed), but it must be repeated every boot.

There is **no untethered jailbreak for iOS 9.3.5**. The untethered option
(Home Depot / the *daibutsu* untether) only covers **iOS 9.1–9.3.4**, which would
require downgrading — only possible with **saved SHSH blobs** for ≤9.3.4 (Apple signing
has long closed, and the A5 has no bootrom exploit like checkm8). So plan on
re-jailbreaking after each reboot.

### ⚠️ "Jailbreak finishes, then the device reboots"
Phoenix's exploit is a userland exploit and is **not 100% reliable** on the A5.
Occasionally it reports success and then the device reboots a few seconds later — this
is a **boot watchdog reset** (`Boot faults: wdog`, stage 16), because the exploit left
the activation/respring in an inconsistent state. It is **intermittent** — just
**re-run Phoenix**; it succeeds within a couple of attempts. Keeping the device's
storage/RAM as free as possible (these are 512 MB devices with a nearly-full system
partition) makes a clean activation more likely, but retrying is the practical fix.

---

## 3. Deploying over SSH (USB)

Use [libimobiledevice](https://libimobiledevice.org/)'s `iproxy` to tunnel SSH over the
USB cable (no Wi-Fi needed, and it works while the device is un-networked):

```bash
iproxy 2222 22 &                    # forward local :2222 -> device :22
ssh -p 2222 root@localhost          # default password: alpine  (change it!)
```

Deploy pattern: `scp` the files, sign on-device with `ldid -S`, launch with
`uiopen <scheme>://run` (the app registers a URL scheme because `uiopen` cannot launch
by bundle id). Handy wrappers are in [`src-ios/ble-diag/`](src-ios/ble-diag/)
(`dssh.sh`, `dscp.sh`, `essh` — an `expect` wrapper for the first password login).

---

## 4. Building

The armv7 toolchain (NDK clang for Tcl, Apple clang + `-Wl,-ld_classic` for linking,
theos iPhoneOS 9.3 SDK) is documented in [IOS9-ARMV7.md](IOS9-ARMV7.md).

The Bluetooth + borg shims are built by
[`scripts/build-shims-armv7.sh`](scripts/build-shims-armv7.sh), which compiles
`src-ios/ble-ios/tclble.m` → `libble1.0.dylib` (Foundation + CoreBluetooth) and
`src-ios/borg-ios/tclBorgios.m` → `libborg1.0.dylib`.

---

## 5. Bluetooth (the hard part)

iOS has no AndroWish `ble` command, so BLE-based apps like de1app can't talk to a DE1
or scale out of the box. **`src-ios/ble-ios/tclble.m`** is an **in-process
CoreBluetooth backend** that implements the AndroWish / `tcl-ble-osx` `ble` API, so
de1app runs unmodified. (It is the macOS `tcl-ble-osx` `native/tclble.m` ported to
armv7/iOS9; the older `tclBLEios.m` is kept in the tree for reference but is
superseded.)

### iOS behaviours you must know (these cost real debugging time)

1. **Advertisements are only delivered to a FOREGROUND app with the screen ON.**
   iOS gates BLE scan results on the display/foreground state. A scan from a headless
   `tclsh` over SSH, or from a GUI app while the **screen is locked/asleep**, reports
   `state=poweredOn` and `isScanning=1` but delivers **zero** `didDiscoverPeripheral`
   callbacks. Launch the app via SpringBoard (`uiopen`) **and keep the screen on**.
   Do **not** trust `UIApplication.applicationState == active` alone — a locked screen
   can still report active momentarily while adverts are suppressed. *(This is the #1
   source of "the radio looks dead but isn't.")*

2. **Create the `CBCentralManager` on the calling thread**, using the serial dispatch
   queue only as the *delegate* queue. On iOS, creating the manager from **inside** a
   block already running on its own delegate queue leaves the XPC event source
   half-wired: the initial `centralManagerDidUpdateState` fires, but
   `didDiscoverPeripheral` **never** does (scan says `isScanning=YES`, returns nothing).
   `tclble.m` does this correctly under `#if TARGET_OS_IPHONE`. (macOS is fine either
   way.)

3. **iOS 9 SDK naming**: `CBManagerState*` did not exist yet (it was
   `CBCentralManagerState*`). `tclble.m` has a compat `#if __IPHONE_OS_VERSION_MAX_ALLOWED
   < 100000` shim mapping the type + all six constants.

### Radio can wedge — power-cycle to self-heal
The aging A5 combo-chip BLE radio can get stuck in a "reports `poweredOn` but receives
zero adverts" state that survives BTServer restarts and even a warm/watchdog reboot.
A full Bluetooth **chip power-cycle** clears it: `src-ios/ble-diag/bttoggle.m` toggles
`setPowered:NO → YES` via the private **BluetoothManager** framework (honored from the
app's `mobile` uid). The IwishDE1 launcher runs it at startup. If a warm reboot doesn't
revive the radio, a **full cold power-off** (slide to power off, wait, power on) does —
a watchdog/warm reboot does not fully de-power the chip.

### `ble` API implemented
`scanner` · `start` · `stop` · `connect` · `reconnect` · `close`/`disconnect` ·
`info` (no-arg → list of open handles; with handle → its info) · `enable` · `disable` ·
`read` · `write` · `mtu` · `userdata` · `state` · `probe`, plus `abort`/`unpair`/`pair`
as no-ops. Events use the `tcl-ble-osx` dict format
(`scan {address name rssi}`, `connection {... state ...}`,
`characteristic {... suuid sinstance cuuid cinstance ...}`).

---

## 6. de1app-side changes required on iOS 9

These live in the de1app `de1plus` tree (not this repo). Apply them so de1app works on
iOS:

1. **Load the armv7 ble shim, not the bundled macOS `ble` package.**
   `de1plus/ble/` is the **macOS** `tcl-ble-osx` package: its `pkgIndex.tcl` provides
   `package require ble 1.0`, but its native `libtclble.dylib` is **x86_64** and its
   `bin/ble_helper` is a Mac binary — neither works on armv7. On iOS `package require ble`
   picks *that* up and de1app ends up with a dead `ble` command (a fake DE1). **Fix:**
   in the IwishDE1 launcher, `load .../lib-batteries/ble1.0/libble1.0.dylib Ble` (which
   auto-`package provide`s `ble 1.0`) **before** sourcing `de1plus.tcl`, so the later
   `package require ble` is already satisfied and the macOS package is never sourced.
   *(This same x86_64-only `de1plus/ble/lib/libtclble.dylib` likely also breaks the
   arm64 Mac-Catalyst build — worth checking there.)*

2. **Enable scale auto-connect at startup.** In `bluetooth.tcl`
   `bluetooth_connect_to_devices`, the scale connect was commented out
   (`#ble_connect_to_scale`). Uncomment it (mirror the DE1 path,
   `after 3000 ble_connect_to_scale`) so a paired scale reconnects on launch. The DE1
   itself already auto-connects (a direct `ble connect <saved-addr> ...`, which works
   by-UUID via CoreBluetooth without a scan). Note de1app only *scans* from the
   Bluetooth **SEARCH** button (`scanning_restart`); at startup it only *connects* to
   already-paired addresses.

3. **Brightness flicker (optional).** On iOS, `get_set_tablet_brightness` reads the
   live `UIScreen.brightness`, and when that drifts (e.g. iOS auto-brightness) it
   re-sets brightness on every UI update → visible flicker. The simple fix is to make
   `get_set_tablet_brightness` a no-op (let iOS/the user own brightness). A cleaner fix
   is to have the app track the value it last set (so `actual != setting` stops being
   perpetually true) rather than reading the live screen value.

---

## 7. Diagnostics ([`src-ios/ble-diag/`](src-ios/ble-diag/))

- **`bttoggle.m`** — power-cycle BT via BluetoothManager (`setPowered NO→YES`); armv7.
- **`btoff90.m`** — hold BT off ~90 s then on (deeper reset attempt).
- **`ble_test_branch.tcl`** — a `/tmp/iwish_bletest`-gated branch to prepend to
  `iWish.app/main.tcl`; runs a **foreground** GUI scan under SpringBoard (the one that
  actually discovers devices) and logs to `/var/mobile/Documents/ble_gui.log`.
- **`devscan.tcl`** — headless scan harness. Loads the shim and reaches `poweredOn`, but
  will show **0 discoveries** because it is headless — that's expected (see §5.1).
- **`dssh.sh` / `dscp.sh` / `essh` / `askpass.sh`** — SSH-over-`iproxy` helpers.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Scan says `poweredOn`, `isScanning=1`, **0 devices** | App not truly foreground / screen locked (§5.1), **or** radio wedged (power-cycle with `bttoggle`, or cold power-off). Cross-check with a Mac scan (e.g. [tcl-ble-osx](https://github.com/johnbuckman/tcl-ble-osx)) to confirm devices are advertising. |
| `ble: unsupported subcommand` / `wrong # args … "ble subcommand conn …"` on exit | Old `tclBLEios.m` lacked no-arg `ble info` / `reconnect` / `abort` / `unpair`. Use `tclble.m`. |
| de1app shows a fake DE1 / `has_bluetooth=0` | The macOS `de1plus/ble/` package shadowed the armv7 shim — preload the shim in the launcher (§6.1). |
| SSH `Connection reset by peer` | The jailbreak isn't active — re-run Phoenix (§2). Restart `iproxy` if it cached a stale session. |
| Jailbreak "finishes" then reboots | Phoenix exploit reliability — just retry (§2). |
| Screen brightness flickers during use | de1app re-setting brightness each UI update (§6.3). |

---

*Built for the Decent Espresso de1app on a jailbroken iPad mini 1. BLE backend adapted
from [tcl-ble-osx](https://github.com/johnbuckman/tcl-ble-osx). Tcl/Tk license.*

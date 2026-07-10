# iWish — Tcl/Tk 8.6 with batteries, on a jailbroken iOS 9.3.5 device (32-bit / armv7)

**iWish** is a full **Tcl/Tk 8.6** interpreter (the AndroWish-derived `sdl2wish`, rendering
through SDL2/OpenGL ES 2 + AGG) with a large set of **batteries** —
**[~400 loadable extension packages](IOS9-BATTERIES-LIST.md)** — built for **32-bit
A5/A5X devices on iOS 9.3.5**, the last iOS these
devices can run. It lets you run Tcl scripts and Tk GUIs directly on the device.

This document is the **device-setup + deployment + usage** guide: why it needs a
jailbreak, how to jailbreak, how to deploy, how to run Tcl/Tk, and what batteries are
included (including the Bluetooth LE one). For the low-level **build toolchain**
(compiler, SDK, how each battery is compiled) see [IOS9-ARMV7.md](IOS9-ARMV7.md).

Verified on an **iPad mini 1 (iPad2,5)**.

---

## 1. Why this needs a jailbreak

iWish is an unsigned Tcl/Tk application deployed outside the App Store. Running it on iOS
requires things Apple does not allow on a stock device:

- **Run unsigned / ad-hoc-signed native code** — the interpreter is signed with `ldid`,
  not a paid Apple Developer certificate, and it `load`s unsigned battery dylibs at
  runtime.
- **Install to `/Applications` and write to the filesystem** — the app bundle and any
  data you work with live outside the normal sandbox.
- **Deploy and debug over SSH** — pushing builds, signing on-device, reading output.
- **Launch by URL scheme** (`uiopen iwish://run`) since there is no App Store listing.

None of that is possible on a stock device, and these are end-of-life 32-bit devices
with no modern App Store path — so a jailbreak is the only way to run iWish at all.

---

## 2. Supported devices

**32-bit A5/A5X devices on iOS 9.3.5** (the terminal iOS for these devices): iPhone 4S,
iPhone 5/5c, iPad 2/3/4, iPad mini 1. Built and tested on an **iPad mini 1 (iPad2,5)** —
an A5 with 512 MB RAM, OpenGL ES 2 (no Metal).

---

## 3. Jailbreaking iOS 9.3.5 (Phoenix)

**[Phoenix](https://phoenixpwn.com/)** is the jailbreak for **iOS 9.3.5 / 9.3.6 on 32-bit
devices**. It is **semi-untethered**.

### Steps
1. **Sideload the Phoenix `.ipa`** onto the device (Cydia Impactor, AltStore, or any
   method that signs with your Apple ID).
2. On the device, **trust the developer certificate**:
   *Settings → General → Profiles & Device Management → trust your Apple ID*.
3. Open **Phoenix** and tap **Jailbreak**. It installs **Cydia**.
4. From Cydia, install **OpenSSH** (for deployment) and change the default root password
   (`alpine`).

### ⚠️ Semi-untethered — re-jailbreak after every reboot
The jailbreak **does not survive a reboot**. After any reboot or power-off the device
boots into a normal, un-jailbroken state — **SSH, Cydia, and unsigned apps stop working**
until you re-open **Phoenix** and tap **Jailbreak** again. This is an **on-device** action
(no computer needed) but must be repeated every boot.

There is **no untethered jailbreak for iOS 9.3.5**. The untethered option (Home Depot /
the *daibutsu* untether) only covers **iOS 9.1–9.3.4**, which would require downgrading —
only possible with **saved SHSH blobs** for ≤9.3.4 (Apple signing closed years ago, and
the A5 has no bootrom exploit like checkm8). So plan on re-jailbreaking after each reboot.

### ⚠️ "Jailbreak finishes, then the device reboots"
Phoenix's exploit is a userland exploit and is **not 100% reliable** on the A5.
Occasionally it reports success and then the device reboots a few seconds later — a
**boot watchdog reset** (`Boot faults: wdog`), because the exploit left the
activation/respring inconsistent. It is **intermittent** — just **re-run Phoenix**; it
succeeds within a couple of attempts.

---

## 4. Deploying over SSH (USB)

Use [libimobiledevice](https://libimobiledevice.org/)'s `iproxy` to tunnel SSH over the
USB cable (no Wi-Fi needed):

```bash
iproxy 2222 22 &                    # forward local :2222 -> device :22
ssh -p 2222 root@localhost          # default password: alpine  (change it!)
```

Deploy pattern: `scp` files to the device, sign native binaries/dylibs on-device with
`ldid -S`, and launch the GUI with `uiopen iwish://run` (the app registers a URL scheme
because `uiopen` cannot launch by bundle id). Convenience wrappers are in
[`src-ios/ble-diag/`](src-ios/ble-diag/) (`dssh.sh`, `dscp.sh`, `essh`).

> The device's userland is minimal (busybox-ish): some tools you'd expect are missing
> (`head`, `tail`, `wc`, `sort`, `uniq`, `awk` on some builds). Do text processing on the
> Mac side of the pipe.

---

## 5. Building

The armv7 toolchain (NDK clang to compile Tcl, Apple clang + `-Wl,-ld_classic` to link,
the theos iPhoneOS 9.3 SDK, the 32-bit ABI autoconf cache, GLES2/no-Metal SDL2) is
documented in [IOS9-ARMV7.md](IOS9-ARMV7.md). The relevant scripts:

| Script | Builds |
|---|---|
| `scripts/build-device-armv7.sh` | the foundation: FreeType, SDL2 (GLES2), Tcl 8.6.10, sdl2tk+AGG, `sdl2wish` |
| `scripts/build-app-armv7.sh` | `iWish.app` — the interpreter + Tcl/Tk libraries + tests + launcher |
| `scripts/build-batteries-armv7.sh` (+ `build-ext-armv7.sh`, `build-allexts-armv7.sh`, `build-blt-armv7.sh`, `build-tls-armv7.sh`, …) | the ~400 battery packages |
| `scripts/build-shims-armv7.sh` | the `ble` and `borg` iOS shims (see §8–9) |

---

## 6. Running Tcl/Tk on the device

`iWish.app` (bundle id `org.iwish.tk`) contains the `sdl2wish` interpreter, the Tcl 8.6
and Tk 8.6 script libraries, and the batteries.

- **GUI (Tk):** launch under SpringBoard with `uiopen iwish://run`. The bundle's
  `main.tcl` dispatcher runs your script and enters the Tk event loop. Tk **must** run
  under SpringBoard (a real GUI surface) — you cannot render Tk from a plain SSH shell.
- **Console (Tcl only):** the bundled `tclsh` runs fine straight over SSH for non-GUI
  scripts and the Tcl regression suite.
- **`package require`:** the launcher puts the bundled `lib-batteries` tree on
  `auto_path` (recursively, since tcllib modules nest), so `package require <name>` finds
  the batteries with no extra setup.
- **Regression suites:** the Tcl suite (46 k tests) and the Tk suite (~7900 tests) both
  run on-device — see [IOS9-ARMV7.md](IOS9-ARMV7.md) for how they're driven and the small
  number of sdl2tk-backend-specific failures.

A minimal script:

```tcl
package require Tk
package require sqlite3        ;# a battery
label .l -text "Tcl [info patchlevel] on [lindex $tcl_platform(machine) 0]"
pack .l
```

---

## 7. Batteries included

**[~400 loadable packages](IOS9-BATTERIES-LIST.md)** load on-device — see the
[full grouped list](IOS9-BATTERIES-LIST.md) for every one. Highlights:

- **GUI / graphics:** Tk 8.6, **BLT / tkblt** (graphs), **Img / tkimg** (all image
  formats: JPEG, PNG, GIF, TIFF, BMP, …), **tksvg**, **Tktable**, **treectrl**, **vu**,
  **tkpath**, **tkvnc**.
- **Data / DB:** **sqlite3**, **tdom** (XML/DOM), **tdbc**, **json**, **Tcl-ral**.
- **Crypto / net:** **tls** (LibreSSL), sockets, http.
- **Language / structure:** **Itcl / itk**, **snit**, **Thread**, tcllib modules
  (struct, math, …).
- **Misc:** **zint** (barcodes), **borg** (platform services — see §9), **ble**
  (Bluetooth LE — see §8), imgjp2, tcl-stbimage.

(Not built: TclCurl, tdbcsqlite3, tkhtml, and a few niche/optional natives.)

---

## 8. The `ble` battery — Bluetooth LE

iOS has no native Tcl `ble` command, so **`src-ios/ble-ios/tclble.m`** provides one: an
**in-process CoreBluetooth backend** implementing the AndroWish /
[tcl-ble-osx](https://github.com/johnbuckman/tcl-ble-osx) `ble` API. Build it with
`scripts/build-shims-armv7.sh` → `libble1.0.dylib`.

A scan for nearby BLE devices:

```tcl
package require ble
proc cb {event data} {
    if {$event eq "scan"} {
        puts "[dict get $data rssi] dBm  [dict get $data name]  [dict get $data address]"
    }
}
ble scanner cb        ;# start scanning; cb fires per advertisement
after 15000 {exit}
vwait forever         ;# run the event loop so cb fires
```

### iOS behaviours you must know (they cost real debugging time)

1. **Advertisements are only delivered to a FOREGROUND app with the screen ON.** iOS
   gates BLE scan results on the display/foreground state. A scan from a headless `tclsh`
   over SSH, or from a GUI app while the **screen is locked/asleep**, reports
   `state=poweredOn` and `isScanning=1` but delivers **zero** `didDiscoverPeripheral`
   callbacks. Launch via SpringBoard **and keep the screen on**. Do not trust
   `UIApplication.applicationState == active` alone.

2. **Create the `CBCentralManager` on the calling thread**, using the serial dispatch
   queue only as the *delegate* queue. On iOS, creating the manager from inside a block
   already running on its own delegate queue leaves the XPC event source half-wired: the
   initial `centralManagerDidUpdateState` fires but `didDiscoverPeripheral` never does.
   `tclble.m` handles this under `#if TARGET_OS_IPHONE`.

3. **iOS 9 SDK naming:** `CBManagerState*` did not exist yet (it was
   `CBCentralManagerState*`) — `tclble.m` has a compat shim.

4. **The aging radio can wedge** (reports `poweredOn` but receives zero adverts, even
   across a warm/watchdog reboot). A full Bluetooth chip **power-cycle** clears it:
   `src-ios/ble-diag/bttoggle.m` toggles `setPowered:NO → YES` via the private
   BluetoothManager framework. A full **cold power-off** resets the chip if a warm reboot
   doesn't.

**API:** `scanner` · `start` · `stop` · `connect` · `reconnect` · `close` · `info`
(no-arg → open handles) · `enable` · `disable` · `read` · `write` · `mtu` · `userdata` ·
`state` · `probe`, plus `abort`/`unpair`/`pair` no-ops.

---

## 9. The `borg` battery — platform services

AndroWish's `borg` command exposes platform services; **`src-ios/borg-ios/tclBorgios.m`**
provides an iOS implementation. Notable subcommands: `toast` (on-screen message),
`brightness` (get/set screen brightness, percent), `systemui` (fullscreen +
`idleTimerDisabled` keep-screen-awake), `speak` (AVSpeechSynthesizer), and the usual
Android-shaped calls returned as safe no-ops where iOS has no equivalent.

---

## 10. Diagnostics ([`src-ios/ble-diag/`](src-ios/ble-diag/))

Tools used to bring up and debug the `ble` battery: `bttoggle` / `btoff90` (BT
power-cycle), foreground and headless scan harnesses, and SSH-over-`iproxy` helpers. See
its [README](src-ios/ble-diag/README.md).

---

## 11. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| SSH `Connection reset by peer` | The jailbreak isn't active — re-run Phoenix (§3). Restart `iproxy` if it cached a stale session. |
| Jailbreak "finishes" then reboots | Phoenix exploit reliability — just retry (§3). |
| Tk script does nothing over SSH | Tk needs a real GUI surface — launch with `uiopen iwish://run`, not from a shell (§6). |
| `package require X` fails | Confirm `lib-batteries` is on `auto_path`; a few optional natives aren't built (§7). |
| BLE scan: `poweredOn`, `isScanning=1`, **0 devices** | App not truly foreground / screen locked, **or** radio wedged — power-cycle with `bttoggle`, or a cold power-off (§8). |

---

*Tcl/Tk license. BLE backend adapted from
[tcl-ble-osx](https://github.com/johnbuckman/tcl-ble-osx).*

# BLE diagnostics (armv7 / iOS 9)

Tools used to bring up and debug the in-process CoreBluetooth backend
(`../ble-ios/tclble.m`) on a jailbroken iPad mini 1. See
[../../IOS9-BATTERIES.md](../../IOS9-BATTERIES.md) for the full story.

| File | What it is |
|---|---|
| `bttoggle.m` | armv7 tool: power-cycle Bluetooth via the private BluetoothManager framework (`setPowered:NO → YES`) to un-wedge the radio. Build: `clang -arch armv7 -isysroot $SDK -miphoneos-version-min=9.0 -fobjc-arc -Wl,-ld_classic -o bttoggle bttoggle.m -framework Foundation`, then `ldid -Sbt.entitlements bttoggle`. |
| `btoff90.m` | Same, but holds BT **off ~90 s** before turning it back on (deeper reset attempt). |
| `bt.entitlements` | Entitlements for the two tools above (`platform-application`). |
| `ble_test_branch.tcl` | Prepend to `iWish.app/main.tcl`; gated by `/tmp/iwish_bletest`. Runs a **foreground** GUI scan under SpringBoard — the configuration that actually receives advertisements — and logs to `/var/mobile/Documents/ble_gui.log`. |
| `ble_toggletest_branch.tcl` | Same, but `exec`s `bttoggle` first (power-cycle + scan). |
| `blescan_branch.tcl` | Older foreground-scan branch (logs `appState` via the legacy `tclBLEios.m`). |
| `devscan.tcl` | Headless scan harness (`tclsh devscan.tcl <dylib> ?secs? ?svcuuid...?`). Reaches `poweredOn` but shows **0 discoveries** — expected, because headless (see IOS9-BATTERIES.md §5.1). |
| `dssh.sh` / `dscp.sh` | Key-based SSH/SCP over `iproxy 2222` to `root@localhost`. |
| `essh` | `expect` wrapper for the first password login (pw `alpine`); use it once to install your pubkey, then use `dssh.sh`. |
| `askpass.sh` | `SSH_ASKPASS` helper. |

**Expected results:** a foreground scan (`ble_test_branch.tcl` via `uiopen iwish://run`,
screen on) discovers the DE1 + scale + nearby devices. A headless scan (`devscan.tcl`)
loads the shim and reaches `poweredOn` but discovers nothing — that is normal (iOS only
delivers adverts to a foreground, screen-on app).

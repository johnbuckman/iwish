# iWish TODO

Roughly priority-ordered. This is an alpha; the list is aspirational, not a
commitment.

## Build / packaging
- [ ] Single top-level build script that runs the whole device pipeline
      (foundation → extensions → BLT → app assembly) from clean.
- [ ] Generate proper unified patches for **all** modified SDL2 files straight
      from a pristine 2.30.11 tarball in CI, instead of hand-curating.
- [ ] Reproducible builds: pin the exact AndroWish revision and document it.
- [ ] Simulator (`-simulator`) and Mac Catalyst (`-macabi`) build scripts
      alongside the device one (the logic exists as `build-*-sim.sh`/
      `build-catalyst*.sh`; fold them in and de-duplicate).
- [ ] An Xcode project (or `xcodebuild`/Fastlane lane) so signing, the
      provisioning profile, and the archive/IPA step are turnkey.
- [ ] TestFlight-distributable signed build.

## Runtime
- [ ] Trim the bundled extension set / make it configurable (the full battery
      set is large; most apps need a subset).
- [ ] Confirm/clean the auto-screen-size path across iPhone + every iPad size
      class and on rotation.
- [ ] `borg`: round out the subcommand coverage (notifications, sensors,
      orientation lock) where an iOS equivalent exists; the rest stay no-ops.
- [ ] `ble`: surface attribute/sgid info that AndroWish exposes on Android.
- [ ] Audio (snack / `borg beep` / AVAudio) — verify on device.
- [ ] Keyboard: software-keyboard show/hide + text-input geometry.

## Quality
- [ ] Run the Tcl + Tk regression suites on-device / in the simulator and record
      the diff vs the desktop baseline (desktop UTF6 baseline is already clean).
- [ ] A small sample-app gallery beyond `demo.tcl`.
- [ ] Document the on-device debugging recipe (devicectl install/launch, pulling
      logs from the app's Documents container).

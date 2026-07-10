# iWish known bugs / limitations

Alpha. Known rough edges:

## Packaging / distribution
- The `0.2-alpha` release ships a prebuilt **`iWish.ipa`** (a development build).
  iOS will not launch it until it is **re-signed** with your own Apple ID —
  Sideloadly/AltStore do this automatically; from source you use
  `sign-and-install-device.sh`. Enable Developer Mode on the device first. See
  [`INSTALL.md`](INSTALL.md) for every path.
- **Cannot** ship on the App Store (it's an interpreter that `dlopen`s C
  extensions — guideline 2.5.2). Distribution is sideloading, or, in the EU, a
  notarized web/marketplace install (no expiry). No TestFlight.
- The build scripts have absolute paths and assumptions baked in (developed on
  one machine); they are a recipe to adapt, not a turnkey `make`.

## Runtime
- **GCD main-thread rule:** the Tcl interpreter runs off the main thread while the
  main thread is busy in the SDL/Tk loop, so any UIKit call from Tcl must be
  inline or `dispatch_async` — a `dispatch_sync` to the main queue **deadlocks**
  and the watchdog kills the app. The `borg` shim follows this; new native glue
  must too.
- Screen brightness set via `UIScreen.brightness` only holds while the app is
  foregrounded; iOS may re-assert auto-brightness after backgrounding.
- Status-bar hiding relies on a forced `setNeedsStatusBarAppearanceUpdate` after
  the window is up (iOS 26 ignores the Info.plist `UIStatusBarHidden` key alone).
- Non-standard screen sizes (e.g. 1194×834) have no matching skin/image dir in
  apps that ship per-resolution art; they rescale from a base resolution at
  runtime, which is slower on first paint.
- Mac Catalyst on a multi-monitor Mac had display-scale-mismatch quadrant-render
  issues; fixed by positioning the scene on `CGMainDisplayID()`, but multi-display
  setups are under-tested.

## Not yet verified on device
- Audio output (snack / beep).
- Software keyboard / text entry geometry.
- The full Tcl/Tk regression suite (only the desktop UTF6 baseline is recorded).

Found something? Please open an issue with the device model, iOS version, and the
`log.txt` from the app's `Documents` container.

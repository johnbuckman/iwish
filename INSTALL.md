# Installing iWish

iWish is distributed as an **`.ipa`** (an iOS app package). It is **not on the
App Store** and never can be: it's a Tcl interpreter that loads compiled C
extensions (`dlopen`) and runs full third-party Tk GUIs — squarely against App
Store guideline 2.5.2. So every install path is a form of **sideloading**.

There are four ways to get it onto a device. Pick by what you have:

| You have… | Use | Expiry | Needs a computer? |
|-----------|-----|--------|-------------------|
| A Mac + Apple ID, want to build it yourself | **[Build from source](#4-build-from-source-any-mac)** | 7 days (free) / 1 yr (paid) | Yes (to build) |
| Any Mac/Windows PC + the prebuilt `.ipa` | **[Sideloadly](#2-sideloadly-simplest)** | 7 days (free) / 1 yr (paid) | Yes |
| Same, but want set-and-forget | **[AltStore](#3-altstore-auto-refresh)** | auto-refreshed | Yes (kept on Wi-Fi) |
| An **EU** device | **[EU notarized install](#5-eu-web-distribution--altstore-pal)** | **none** | **No** |

The short version: **anyone with a computer and an Apple ID can install iWish.**
A *free* Apple ID means the app stops launching after **7 days** and you can have
at most **3** sideloaded apps at once; a *paid* Apple Developer ID ($99/yr) makes
it **1 year** with no app limit. Only the EU route avoids both the computer and
the expiry.

---

## 1. Sideloadly vs AltStore — which to use

Both re-sign the `.ipa` with *your own* Apple ID and install it. The difference
is what happens after:

| | **Sideloadly** | **AltStore (classic)** |
|---|---|---|
| What it is | A desktop app that signs + installs an `.ipa` one time | A desktop "server" that installs an on-device app *store*, which then installs `.ipa`s |
| Best for | Quick one-off installs | Set-and-forget; **auto-refreshes** the 7-day signature over Wi-Fi |
| Ongoing hassle | Manually re-run every 7 days (free account) | None, if you leave the computer on the same Wi-Fi |
| Complexity | Simpler | A bit more setup |

**Rule of thumb:** trying iWish once → **Sideloadly**. Keeping it around
long-term without thinking about the weekly expiry → **AltStore**.

---

## 2. Sideloadly (simplest)

1. **Install Sideloadly** from [sideloadly.io](https://sideloadly.io) (macOS or Windows).
2. **Windows only:** also install **iTunes** and **iCloud** — the versions
   downloaded directly from Apple's website, *not* the Microsoft Store versions
   (Sideloadly needs Apple's device drivers). macOS needs nothing extra.
3. **Connect the iPhone/iPad by USB** and tap **Trust** on the device.
4. **Drag `iWish.ipa` into Sideloadly.**
5. Enter the **Apple ID** you want to sign with. (Tip: many people use a
   secondary/burner Apple ID for sideloading, and generate an *app-specific
   password* if the account has two-factor auth.)
6. Click **Start.** It signs and installs.
7. On the device: **Settings → General → VPN & Device Management → tap your
   Apple ID → Trust.**
8. Launch **iWish**.
9. **Repeat steps 4–6 every 7 days** (free account) or once a year (paid).

---

## 3. AltStore (auto-refresh)

1. **Install AltServer** on the computer from [altstore.io](https://altstore.io)
   (macOS or Windows; Windows needs the same iTunes + iCloud from Apple as above).
2. **Connect the device by USB** and **Trust** it.
3. From **AltServer** (menu-bar icon on macOS / system-tray on Windows):
   **Install AltStore → pick your device → sign in with your Apple ID.** This
   puts the **AltStore** app on the device.
4. On the device: **Settings → General → VPN & Device Management → Trust** your
   Apple ID certificate.
5. Open **AltStore** on the device → **My Apps → "+"** → pick **`iWish.ipa`**.
   It installs.
6. **To get auto-refresh:** keep AltServer running on the computer, on the **same
   Wi-Fi** as the device, and enable Background App Refresh. AltStore re-signs
   the app before the 7 days lapse — in practice you just open your laptop on
   your home network once a week and never think about the expiry.

---

## 4. Build from source (any Mac)

The most honest path, aimed at developers. Full instructions are in
[`README.md`](README.md) → *Build (outline)*. In brief: apply the patches to an
AndroWish + SDL2 checkout, run `scripts/build-device.sh` +
`scripts/build-ext-dev.sh` + `scripts/build-tkblt-dev.sh` +
`scripts/build-device-batteries.sh`, assemble the `.app`, then:

```sh
scripts/sign-and-install-device.sh <your.app> <identity> <profile> <udid> [entitlements]
```

Signing tier is the same as sideloading: a **free** Apple ID → 7-day / 3-app;
a **paid** ($99/yr) Apple Developer account → 1-year, no limit.

---

## 5. EU: web distribution / AltStore PAL

Since 2024, the EU **Digital Markets Act (DMA)** lets EU-region devices install
apps from outside the App Store, and this is by far the nicest path:

- **Web distribution** — a *notarized* `.ipa` hosted on the developer's own site;
  EU users tap to install and it stays installed **permanently — no 7-day
  expiry, no per-device UDID, no re-signing, no computer.**
- **Alternative marketplaces** — e.g. **AltStore PAL**, a DMA-sanctioned store;
  same permanent-install benefit.

Caveats:

- The device must be **region-set to an EU country and physically in the EU** —
  Apple geofences this.
- The developer must enroll in Apple's **Alternative Business Terms** and
  **notarize** each build (an automated malware/baseline scan — **not** full App
  Review, and it does *not* reject interpreters the way App Review would, which
  is exactly why this route works for iWish).
- The **Core Technology Fee** only applies above **1 million** first-installs per
  year, so a niche app pays nothing beyond the €99 membership. (Apple has revised
  these terms repeatedly — verify the current ones.)

This is the only path that gives real users a clean, permanent, no-Mac install.

---

## Notes specific to iWish

- **Producing the `.ipa`.** Package the built `.app` into a `Payload/` folder,
  zip it, and rename `.zip` → `.ipa`:
  ```sh
  mkdir -p Payload && cp -R iWish.app Payload/
  zip -r iWish.ipa Payload
  ```
  (The `v0.2-alpha` GitHub release ships a ready-made `iWish.ipa`.)
- **Re-signing just works.** When a user signs with *their own* Apple ID,
  Sideloadly/AltStore rewrite the bundle ID and provisioning to fit their
  account — the original team/profile is irrelevant.
- **Bluetooth is fine under a free account.** iWish's only special capability is
  BLE, which needs only the `NSBluetoothAlwaysUsageDescription` usage string
  already in `Info.plist` — no entitlement a free Apple ID can't grant.
- **Free-account throttle.** A free Apple ID can register only ~10 new app IDs
  per 7 days and run 3 sideloaded apps at once; iWish counts as one.
- **The 7-day wall is why the EU route matters.** Outside the EU, the weekly
  refresh (or a paid dev account) is the price of admission.

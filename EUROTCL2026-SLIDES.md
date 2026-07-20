# EUROTCL2026-SLIDES.md — the talk deck, and how to edit it

Working notes for whoever (human or AI) next touches **`iWish-for-iOS.pptx`**, the
EuroTcl 2026 talk deck. Written 2026-07-20, after the sideloading section was
rewritten. Read this before opening the file — it records the design system, the
slide↔file mapping, the toolchain gotchas, and *why* the sideloading story says
what it says.

> **John hand-edits this deck.** It was originally generated with Claude and then
> edited by hand. Never regenerate it from scratch — always unpack, patch the
> specific slide XML, and repack. Losing his edits is the one unrecoverable mistake here.

## Where the deck lives

| Copy | Status |
|------|--------|
| `iWish-for-iOS.pptx` (this repo) | **Canonical.** Tracked in git, on `main`. |
| `iWish-for-iOS.pdf` (this repo) | Tracked. Regenerate from the PPTX on every deck commit — the two previous deck commits are both titled "PPTX + PDF". |
| `/Users/john/eurotcl2026/iWish-for-iOS.pptx` | Second working copy, **not under version control**. John keeps both in sync — update it by hand whenever you change the repo copy. |

Both `.pptx` copies were byte-identical before the 2026-07-20 edit and must be kept so.

## Toolchain — exact commands that work on this Mac

A `.pptx` is a zip of XML. Unpack → edit `ppt/slides/slideN.xml` → repack.

```bash
python3 -c "import zipfile; zipfile.ZipFile('iWish-for-iOS.pptx').extractall('unpacked')"
# ... edit ppt/slides/slideN.xml ...
rm -f out.pptx && (cd unpacked && zip -Xrq ../out.pptx .)   # zip from INSIDE the dir
python3 "$SKILL/scripts/office/validate.py" out.pptx --original iWish-for-iOS.pptx
```

`$SKILL` = the bundled `pptx` skill directory (`.../skills/pptx`). Its
`add_slide.py` is the only correct way to duplicate a slide — it does the
`sldIdLst` / rels / content-type bookkeeping:

```bash
python3 "$SKILL/scripts/add_slide.py" unpacked/ slide18.xml --after slide17.xml
```

### Gotchas that cost time

- **LibreOffice is not on `PATH`.** `export PATH="/Applications/LibreOffice.app/Contents/MacOS:$PATH"`.
- **The skill's `scripts/office/soffice.py` does not work here** — it shells out to a
  bare `soffice`, and `python` is Python 2 (syntax-errors on its type hints). Call
  `soffice` directly, and always use `python3`.
- **Render for visual QA:**
  `soffice --headless --convert-to pdf out.pptx && pdftoppm -jpeg -r 110 -f 17 -l 26 out.pdf slide`
- **Edit XML by exact-substring `str.replace` only.** Round-tripping OOXML through
  `xml.etree.ElementTree` rewrites namespace prefixes and corrupts the deck.
  Assert a match count of exactly 1 on every replacement.
- **Do all structural work (add/delete/reorder) before editing slide content** —
  `add_slide.py` copies a slide file verbatim.
- Apostrophes in the deck are typographic `’` (U+2019); dashes are em `—`; the
  separator in tables is `·` (U+00B7). Match them or the text looks off.

## Design system (measured from the XML — reuse these exactly)

Slide size **9144000 × 5143500 EMU** (10 × 5.625 in, 16:9). Background solid `000000`.
Left margin `x=502920`, content width `8138160`.

| Element | Spec |
|---|---|
| Kicker ("METHOD 1 · …") | `y=384048`, Calibri, `sz=1200`, `b=1`, `spc=250`, `E8552D` |
| Title | `y=658368 cy=777240`, **Cambria**, `sz=3000`, `b=1`, `ECEFF4`, `lnSpc 98%` |
| Step title | Calibri `sz=1500` (5-step) / `1550` (3-step), `b=1`, `ECEFF4` |
| Step subtitle | Calibri `sz=1250`, `9AA6B5` |
| Numbered circle | ellipse; number text **Cambria** `b=1` `FFFFFF` |
| Italic takeaway | Calibri `sz=1250 i=1`, `F2B233` |
| Footer left | `x=502920 y=4736592`; "EuroTcl 2026" `sz=900 b=1 E8552D` + "   iWish for iOS" `sz=900 9AA6B5` |
| Footer page no. | `x=8229600 y=4736592 cx=411480`, `algn=r`, `sz=900`, `9AA6B5` |

**Palette:** orange `E8552D` (accent/kicker/lead) · table-header red `C43E1C` ·
caution red `C0392B` · teal `1FB3A6` · amber `F2B233` · near-white `ECEFF4` ·
muted grey `9AA6B5` / `9AA8B8` · panel `141A24` · table row `0F141D` · border `2A3341`.

### Layout A — 5 numbered steps (`slide18.xml`, `slide25.xml`)

Circles `402336²` at `x=502920`, `y = 1527048 + n·548640`. Step title at
`x=1069848 cx=7589520 cy=274320`, `y = circleY − 36576`. Subtitle at
`y = circleY + 246888`, `cy=237744`. Italic takeaway below.
Subtitles have the full slide width — up to ~90 chars fit on one line.

### Layout B — 3 numbered steps + callout card (`slide19.xml`, `slide26.xml`)

Circles `420624²` at `y = 1600200 + n·777240`. Title `x=1106424 cx=4480560 cy=292608`,
`y = circleY − 18288`; subtitle `y = circleY + 292608`, `cy=256032`.
**Keep left-column subtitles ≤ ~45 chars** — the column is only 4480560 EMU wide and
the box is one line tall.

Callout card: `roundRect` (`adj 3273`) at `x=5669280 y=1600200 cx=2971800 cy=2514600`,
fill `141A24`, line `2A3341`. Icon circle `566928²` fill `F2B233` at `5943600,1856232`
with a small PNG glyph inside (`rId1`). Card header `sz=1600 b=1 EAEFF5`; body
`sz=1250 9AA8B8 lnSpc 105%` at `cx=2377440 cy=1097280` — **~6 lines / ~125 chars max**.

### Table (`slide17.xml`)

At `x=502920 y=1618488`; grid cols `2743200 / 3108960 / 2286000`; row `h=438912`
(reduced from the original `512064` so six rows clear the caption at `y=4370832`).
Header cells fill `C43E1C`, bold white; data cells fill `0F141D`, text `ECEFF4`;
all borders `2A3341 w=12700`; cell margins `marL/R=88900 marT/B=38100 anchor=ctr`.

## Slide inventory — display order vs. file name

**These diverge.** `add_slide.py` appends new files (`slide25`, `slide26`) and inserts
them into `<p:sldIdLst>`; order comes from `presentation.xml`, not the filename.

| Display | File | Footer | Slide |
|---:|---|---:|---|
| 17 | `slide17.xml` | 14 | Five ways onto your iPad (table) |
| 18 | **`slide25.xml`** | 15 | Method 1 · iSideload — "The one-click installer I built" |
| 19 | **`slide26.xml`** | 16 | iSideload · Roadmap — "Toward a cable-free install" |
| 20 | `slide18.xml` | 17 | Method 2 · Sideloadly |
| 21 | `slide19.xml` | 18 | Caution · AltStore — "AltStore can't sign for modern iOS" |
| 22 | `slide20.xml` | 19 | Method 3 · From source |
| 23 | `slide21.xml` | 20 | European Union / DMA |
| 24 | `slide22.xml` | 21 | Caution · AltStore — "How AltStore used to install it" |
| 25 | `slide23.xml` | 22 | Call for collaborators (EU company) |
| 26 | `slide24.xml` | — | Closing |

Deck is **26 slides**. To list the true order:

```bash
python3 -c "
import re
xml=open('unpacked/ppt/presentation.xml').read()
rels=open('unpacked/ppt/_rels/presentation.xml.rels').read()
m=dict(re.findall(r'Id=\"(rId\d+)\"[^>]*Target=\"(slides/slide\d+\.xml)\"',rels))
for i,rid in enumerate(re.findall(r'<p:sldId[^>]*r:id=\"(rId\d+)\"',xml),1): print(i,m[rid])"
```

### Page numbers are MANUAL — renumber after any insert

There is no auto page-number field. Each slide carries a literal number in a
text box, and it is always **the last `<a:t>digits</a:t>` run in the file**
(step numbers appear earlier). The section runs 14→22 consecutively.
Slides 1–3 are intro and `slide14.xml` is a section divider with a big "02" and
no footer, so *footer ≠ index* — never compute it, always shift existing values.

## The sideloading story — content and rationale (2026-07-20)

John's findings, which drove this rewrite:

- **AltStore no longer works.** Its signer relies on an Apple ID flow Apple retired,
  so it can't sign for modern iOS at all.
- **Sideloadly** should work, but he could not get its **VPN config** working.
- **SideStore** should work, but its **VPN config defeated him too**
  (he confirmed: VPN trouble on *both* Sideloadly and SideStore).
- **iSideload** — his own tool — is the path that works today.

Decisions he made explicitly, so don't silently revisit them:

1. Edit **both** copies of the deck.
2. **Keep AltStore as a caution**, reframed — do not delete its slides.
3. iSideload is the **lead method plus a roadmap slide**.

There is a second, iWish-specific reason AltStore fails, kept on the caution slide:
iWish ships **~64 native `.dylib`s under `lib-batteries/` — outside `Frameworks/`**.
AltStore re-signs the wrapper and main executable but leaves those signed by the
original team (`XLS3XF57J8`), so `installd` sees mismatched team signatures and
rejects the bundle with **`0xe8008001` "failed to verify code signature."**
iSideload signs every nested dylib **inside-out**, which is why it installs.
(Deeper detail lives in the `johnbuckman/iSideload` repo, incl. `docs/wireless/`.)

### iSideload status as presented

- **Works today:** free-Apple-ID login → `zsign` signs inside-out → bundled
  `libimobiledevice` installs over **USB** (no Xcode, no Python) → re-signs every 7 days.
- **Works today:** QR install for **already-registered** devices (OTA via
  `itms-services://` over trusted HTTPS).
- **In progress:** QR that reports the device's **UDID** back to the server so it can
  be registered for **ad-hoc** signing.
- **The goal:** a **NaviServer-hosted** signer using `zsign` — nothing installed on
  the Mac, just scan a QR.
- **Caveat on the slide:** OTA/ad-hoc needs **Developer Mode** enabled once per device.

Repo: `github.com/johnbuckman/iSideload` (AGPL-3.0) — now the link on display slide 24,
which previously pointed at the AltStore FAQ.

## Open follow-ups

- **`INSTALL.md` is now stale.** It still walks through AltStore as a live option and
  frames the choice as "Sideloadly vs AltStore". It should match the deck: iSideload
  first, AltStore as a caution, SideStore noted, Sideloadly's VPN caveat. Not done —
  the 2026-07-20 task was scoped to the slides only.
- `altstore.json` and `scripts/relocate-frameworks.sh` are AltStore-era artifacts
  (the `.framework`-wrapping workaround for exactly the nested-dylib bug above).
  Decide whether they still earn their place.
- The `/Users/john/eurotcl2026/` copy is untracked — keep it in sync by hand.

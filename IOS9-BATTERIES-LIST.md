# iWish batteries — the bundled Tcl/Tk extension packages

The iWish Tcl/Tk build for jailbroken iOS 9.3.5 (32-bit / armv7) bundles **494**
loadable packages. Load any with `package require <name>`. Back to the main guide:
[IOS9-BATTERIES.md](IOS9-BATTERIES.md).

## tcllib & tklib

The complete **[tcllib](https://core.tcl-lang.org/tcllib) 1.21** and **[tklib](https://core.tcl-lang.org/tklib) 0.7** are bundled — **all of their modules work, except** these known cases from the on-device load test:

- **`struct`** and **`report`** — a newer copy is already present, so the tcllib version conflicts.
- a few tcllib **plugin-internal** modules (certain `doctools` / `page` / `pt` / `grammar` plugin
  sub-packages) that their plugin managers load internally, not via a direct `package require`.

*(From the last on-device battery-load test; the exact pass/fail set is reproducible on-device.
Everything else in tcllib/tklib loads.)*


The rest of this list is the **non-tcllib/tklib** extensions, grouped by function
(sub-module-heavy families are collapsed to one row):


## Bluetooth & platform

| Package | Version | Notes |
|---|---|---|
| `Ble` | 1.0 |  |
| `Borg` | 1.0 |  |

## Tk widgets & themes

| Package | Version | Notes |
|---|---|---|
| `awthemes` | 10.4.0 | themed ttk styles: awdark, awlight, awarc, awblack, awbreeze(dark), awclearlooks, awtemplate, awwinxpblue |
| `BWidget` | 1.9.16 |  |
| `flexmenu` | 1.52 |  |
| `fsdialog` | 1.15 |  |
| `gridplus` | 2.11 |  |
| `icons` | 2.0 |  |
| `Iwidgets` | 4.0 |  |
| `keynav` | 1.0 |  |
| `MaterialIcons` | 0.2 |  |
| `music` | 0.1 |  |
| `photoframe` | 1.0 |  |
| `QuickTimeTcl` | 3.1 |  |
| `scrolldata` | 2.12 |  |
| `tkled` | 0.1 |  |
| `tknotebook` | 0.1 |  |
| `Tktable` | 2.11 |  |
| `touchcal` | 0.1 |  |
| `treectrl` | 2.4.2 |  |
| `ttk::dialog` | 0.8 |  |
| `ttk::icons` | 0 |  |
| `vu` | 2.3 |  |

## Graphics, plotting & canvas

| Package | Version | Notes |
|---|---|---|
| `BLT` | 2.4 |  |
| `can2svg` | 0.3 |  |
| `colorutils` | 4.8 |  |
| `pikchr` | 1.0 |  |
| `svg2can` | 1.0 |  |
| `tkpath` | 0.3.3 |  |
| `tksvg` | 0.14 |  |
| `ukaz` | 2.1 |  |

## Image formats

| Package | Version | Notes |
|---|---|---|
| `Img` | 1.4.11 | all image formats (BMP/GIF/JPEG/PNG/PPM/PS/SGI/SUN/TGA/TIFF/XBM/XPM/ICO/PCX/pixmap/raw/window) |
| `imgjp2` | 0.1 |  |
| `jpegtcl` | 9.2 |  |
| `pngtcl` | 1.6.35 |  |
| `stbimage` | 0.8 |  |
| `tifftcl` | 3.9.7 |  |
| `zlibtcl` | 1.2.11 |  |

## PDF & office documents

| Package | Version | Notes |
|---|---|---|
| `ooxml` | 1.7 |  |
| `pdf4tcl` | 0.9.4 | PDF generation (+ graph/stdmetrics/glyph2unicode) |

## Databases & data stores

| Package | Version | Notes |
|---|---|---|
| `lmdb` | 0.4.3 |  |
| `ral` | 0.12.2 |  |
| `raloo` | 0.2 |  |
| `ralutil` | 0.12.2 |  |
| `retcl` | 0.4.0 |  |
| `sqlite3` | 3.45.1 |  |
| `tdbc` | 1.1.1 | Tcl DataBase Connectivity (+ sqlite3/jdbc drivers) |

## Data formats & serialization

| Package | Version | Notes |
|---|---|---|
| `didl` | 0.2 |  |
| `JSONRPC` | 0.1 |  |
| `msgpack` | 2.0.0 |  |
| `rl_json` | 0.15.1 |  |
| `tclcsv` | 2.3 |  |
| `tdom` | 0.9.3 |  |
| `tinydom` | 0.2 |  |
| `vcd` | 0.1 |  |
| `vcdnooo` | 0.1 |  |
| `XMLRPC` | 1.0.1 |  |

## Cryptography & TLS

| Package | Version | Notes |
|---|---|---|
| `tls` | 1.6.9 |  |

## Networking & protocols

| Package | Version | Notes |
|---|---|---|
| `broker` | 2.1 |  |
| `http` | 2.6.9 |  |
| `Memchan` | 2.4 |  |
| `modbus` | 0.1 |  |
| `mqtt` | 3.1.1 |  |
| `nats` | 3.0 |  |
| `pty` | 0.1 |  |
| `rmq` | 1.4.5 |  |
| `rpcvar` | 1.2 |  |
| `snap7` | 0.1 |  |
| `SOAP` | 1.6.8.1 | SOAP client/server (+ CGI/Domain/Service/http(s)/smtp/ftp/xpath, soapinterop) |
| `ssdp` | 0.2 |  |
| `tfirmata` | 2.5 |  |
| `tomato` | 1.2.3 |  |
| `topcua` | 0.5 | OPC-UA client (+ cgen/filesystem/prdict/sqlmodel) |
| `udp` | 1.0.11 |  |
| `upnp` | 0.2 |  |
| `vnc` | 0.5 |  |
| `WS::*` | 2.6.3 | Web Services framework (Client/Server/Utils/Channel/Embeded/AOLserver) |
| `www` | 2.4 | WWW client (+ http2/websocket/socks/proxypac/digest) |
| `XOTcl` | 2.4.0 | XOTcl 2 OO system (+ comm/serializer/metadata/htmllib/… submodules) |

## Object systems (OO)

| Package | Version | Notes |
|---|---|---|
| `Itcl` | 4.2.0 |  |
| `Itk` | 4.1.0 |  |
| `nsf` | 2.4.0 | Next Scripting Framework core (+ mongo) |
| `nx` | 2.4.0 | the Next Scripting Framework OO system (+ mongo/serializer/traits/… submodules) |

## Concurrency & threads

| Package | Version | Notes |
|---|---|---|
| `csp` | 0.1.0 |  |
| `promise` | 1.1.0 |  |
| `Thread` | 2.8.5 |  |
| `Ttrace` | 2.8.5 |  |

## Filesystems & packaging

| Package | Version | Notes |
|---|---|---|
| `fileutil::globfind` | 1.5 |  |
| `starkit` | 1.3.3 |  |
| `tbcload` | 1.7 |  |
| `tcllibc` | 1.21 |  |
| `tinyfileutils` | 1.0 |  |
| `trofs` | 0.4.9 |  |
| `trsync` | 1.0 |  |
| `vfs` | 1.4.2 | TclVFS virtual filesystems (+ template/*, opcua, urltype) |

## Parsing

| Package | Version | Notes |
|---|---|---|
| `parser` | 1.8 |  |
| `yeti` | 0.4.2 |  |
| `ylex` | 0.4.2 |  |

## Barcodes

| Package | Version | Notes |
|---|---|---|
| `zint` | 2.13.0 |  |

## Dev, docs & debugging

| Package | Version | Notes |
|---|---|---|
| `autoopts` | 0.6.1 |  |
| `classview` | 0.1 |  |
| `parse_args` | 0.5.1 |  |
| `tkcon` | 2.7 |  |
| `tkconclient` | 1.0 |  |
| `twDebugInspector` | 0.1 |  |
| `uriencode` | 1.0 |  |
| `wibble` | 0.4 |  |

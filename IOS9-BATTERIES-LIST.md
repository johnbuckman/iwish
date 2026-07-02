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
(sub-module-heavy families are collapsed to one row). **Each name links to its
documentation** — a project site or [Tcler's Wiki](https://wiki.tcl-lang.org/) page where
one exists, otherwise a wiki search for niche packages.


## Bluetooth & platform

| Package | Version | Notes |
|---|---|---|
| [`Ble`](https://wiki.tcl-lang.org/search?q=Ble) | 1.0 |  |
| [`Borg`](https://wiki.tcl-lang.org/search?q=Borg) | 1.0 |  |

## Tk widgets & themes

| Package | Version | Notes |
|---|---|---|
| [`awthemes`](https://wiki.tcl-lang.org/search?q=awthemes) | 10.4.0 | themed ttk styles: awdark, awlight, awarc, awblack, awbreeze(dark), awclearlooks, awtemplate, awwinxpblue |
| [`BWidget`](https://wiki.tcl-lang.org/page/BWidget) | 1.9.16 |  |
| [`flexmenu`](https://wiki.tcl-lang.org/search?q=flexmenu) | 1.52 |  |
| [`fsdialog`](https://wiki.tcl-lang.org/search?q=fsdialog) | 1.15 |  |
| [`gridplus`](https://wiki.tcl-lang.org/search?q=gridplus) | 2.11 |  |
| [`icons`](https://wiki.tcl-lang.org/search?q=icons) | 2.0 |  |
| [`Iwidgets`](https://wiki.tcl-lang.org/page/Iwidgets) | 4.0 |  |
| [`keynav`](https://wiki.tcl-lang.org/search?q=keynav) | 1.0 |  |
| [`MaterialIcons`](https://wiki.tcl-lang.org/search?q=MaterialIcons) | 0.2 |  |
| [`music`](https://wiki.tcl-lang.org/search?q=music) | 0.1 |  |
| [`photoframe`](https://wiki.tcl-lang.org/search?q=photoframe) | 1.0 |  |
| [`QuickTimeTcl`](https://wiki.tcl-lang.org/search?q=QuickTimeTcl) | 3.1 |  |
| [`scrolldata`](https://wiki.tcl-lang.org/search?q=scrolldata) | 2.12 |  |
| [`tkled`](https://wiki.tcl-lang.org/search?q=tkled) | 0.1 |  |
| [`tknotebook`](https://wiki.tcl-lang.org/search?q=tknotebook) | 0.1 |  |
| [`Tktable`](https://wiki.tcl-lang.org/page/Tktable) | 2.11 |  |
| [`touchcal`](https://wiki.tcl-lang.org/search?q=touchcal) | 0.1 |  |
| [`treectrl`](https://wiki.tcl-lang.org/page/treectrl) | 2.4.2 |  |
| [`ttk::dialog`](https://wiki.tcl-lang.org/search?q=ttk%20dialog) | 0.8 |  |
| [`ttk::icons`](https://wiki.tcl-lang.org/search?q=ttk%20icons) | 0 |  |
| [`vu`](https://wiki.tcl-lang.org/page/vu) | 2.3 |  |

## Graphics, plotting & canvas

| Package | Version | Notes |
|---|---|---|
| [`BLT`](https://wiki.tcl-lang.org/page/BLT) | 2.4 |  |
| [`can2svg`](https://wiki.tcl-lang.org/search?q=can2svg) | 0.3 |  |
| [`colorutils`](https://wiki.tcl-lang.org/search?q=colorutils) | 4.8 |  |
| [`pikchr`](https://wiki.tcl-lang.org/search?q=pikchr) | 1.0 |  |
| [`svg2can`](https://wiki.tcl-lang.org/search?q=svg2can) | 1.0 |  |
| [`tkpath`](https://wiki.tcl-lang.org/page/tkpath) | 0.3.3 |  |
| [`tksvg`](https://wiki.tcl-lang.org/page/tksvg) | 0.14 |  |
| [`ukaz`](https://wiki.tcl-lang.org/search?q=ukaz) | 2.1 |  |

## Image formats

| Package | Version | Notes |
|---|---|---|
| [`Img`](https://sourceforge.net/projects/tkimg/) | 1.4.11 | all image formats (BMP/GIF/JPEG/PNG/PPM/PS/SGI/SUN/TGA/TIFF/XBM/XPM/ICO/PCX/pixmap/raw/window) |
| [`imgjp2`](https://wiki.tcl-lang.org/search?q=imgjp2) | 0.1 |  |
| [`jpegtcl`](https://wiki.tcl-lang.org/page/jpegtcl) | 9.2 |  |
| [`pngtcl`](https://wiki.tcl-lang.org/page/pngtcl) | 1.6.35 |  |
| [`stbimage`](https://wiki.tcl-lang.org/search?q=stbimage) | 0.8 |  |
| [`tifftcl`](https://wiki.tcl-lang.org/page/tifftcl) | 3.9.7 |  |
| [`zlibtcl`](https://wiki.tcl-lang.org/page/zlibtcl) | 1.2.11 |  |

## PDF & office documents

| Package | Version | Notes |
|---|---|---|
| [`ooxml`](https://wiki.tcl-lang.org/page/ooxml) | 1.7 |  |
| [`pdf4tcl`](https://wiki.tcl-lang.org/page/pdf4tcl) | 0.9.4 | PDF generation (+ graph/stdmetrics/glyph2unicode) |

## Databases & data stores

| Package | Version | Notes |
|---|---|---|
| [`lmdb`](https://wiki.tcl-lang.org/search?q=lmdb) | 0.4.3 |  |
| [`ral`](https://wiki.tcl-lang.org/search?q=ral) | 0.12.2 |  |
| [`raloo`](https://wiki.tcl-lang.org/search?q=raloo) | 0.2 |  |
| [`ralutil`](https://wiki.tcl-lang.org/search?q=ralutil) | 0.12.2 |  |
| [`retcl`](https://wiki.tcl-lang.org/search?q=retcl) | 0.4.0 |  |
| [`sqlite3`](https://sqlite.org/tclsqlite.html) | 3.45.1 |  |
| [`tdbc`](https://www.tcl-lang.org/man/tcl/TdbcCmd/tdbc.html) | 1.1.1 | Tcl DataBase Connectivity (+ sqlite3/jdbc drivers) |

## Data formats & serialization

| Package | Version | Notes |
|---|---|---|
| [`didl`](https://wiki.tcl-lang.org/search?q=didl) | 0.2 |  |
| [`JSONRPC`](https://wiki.tcl-lang.org/page/JSONRPC) | 0.1 |  |
| [`msgpack`](https://wiki.tcl-lang.org/page/msgpack) | 2.0.0 |  |
| [`rl_json`](https://wiki.tcl-lang.org/page/rl_json) | 0.15.1 |  |
| [`tclcsv`](https://wiki.tcl-lang.org/page/tclcsv) | 2.3 |  |
| [`tdom`](https://www.tdom.org/) | 0.9.3 |  |
| [`tinydom`](https://wiki.tcl-lang.org/page/tinydom) | 0.2 |  |
| [`vcd`](https://wiki.tcl-lang.org/search?q=vcd) | 0.1 |  |
| [`vcdnooo`](https://wiki.tcl-lang.org/search?q=vcdnooo) | 0.1 |  |
| [`XMLRPC`](https://wiki.tcl-lang.org/page/XMLRPC) | 1.0.1 |  |

## Cryptography & TLS

| Package | Version | Notes |
|---|---|---|
| [`tls`](https://core.tcl-lang.org/tcltls/) | 1.6.9 |  |

## Networking & protocols

| Package | Version | Notes |
|---|---|---|
| [`broker`](https://wiki.tcl-lang.org/page/broker) | 2.1 |  |
| [`http`](https://wiki.tcl-lang.org/page/http) | 2.6.9 |  |
| [`Memchan`](https://wiki.tcl-lang.org/page/Memchan) | 2.4 |  |
| [`modbus`](https://wiki.tcl-lang.org/page/modbus) | 0.1 |  |
| [`mqtt`](https://wiki.tcl-lang.org/page/mqtt) | 3.1.1 |  |
| [`nats`](https://wiki.tcl-lang.org/page/nats) | 3.0 |  |
| [`pty`](https://wiki.tcl-lang.org/page/pty) | 0.1 |  |
| [`rmq`](https://wiki.tcl-lang.org/page/rmq) | 1.4.5 |  |
| [`rpcvar`](https://wiki.tcl-lang.org/search?q=rpcvar) | 1.2 |  |
| [`snap7`](https://wiki.tcl-lang.org/search?q=snap7) | 0.1 |  |
| [`SOAP`](https://wiki.tcl-lang.org/page/SOAP) | 1.6.8.1 | SOAP client/server (+ CGI/Domain/Service/http(s)/smtp/ftp/xpath, soapinterop) |
| [`ssdp`](https://wiki.tcl-lang.org/page/ssdp) | 0.2 |  |
| [`tfirmata`](https://wiki.tcl-lang.org/search?q=tfirmata) | 2.5 |  |
| [`tomato`](https://wiki.tcl-lang.org/search?q=tomato) | 1.2.3 |  |
| [`topcua`](https://wiki.tcl-lang.org/search?q=topcua) | 0.5 | OPC-UA client (+ cgen/filesystem/prdict/sqlmodel) |
| [`udp`](https://wiki.tcl-lang.org/page/udp) | 1.0.11 |  |
| [`upnp`](https://wiki.tcl-lang.org/page/upnp) | 0.2 |  |
| [`vnc`](https://wiki.tcl-lang.org/page/vnc) | 0.5 |  |
| [`WS::*`](https://wiki.tcl-lang.org/search?q=WS) | 2.6.3 | Web Services framework (Client/Server/Utils/Channel/Embeded/AOLserver) |
| [`www`](https://wiki.tcl-lang.org/page/www) | 2.4 | WWW client (+ http2/websocket/socks/proxypac/digest) |
| [`XOTcl`](https://next-scripting.org/) | 2.4.0 | XOTcl 2 OO system (+ comm/serializer/metadata/htmllib/… submodules) |

## Object systems (OO)

| Package | Version | Notes |
|---|---|---|
| [`Itcl`](https://www.tcl-lang.org/man/tcl/ItclCmd/contents.html) | 4.2.0 |  |
| [`Itk`](https://wiki.tcl-lang.org/page/Itk) | 4.1.0 |  |
| [`nsf`](https://next-scripting.org/) | 2.4.0 | Next Scripting Framework core (+ mongo) |
| [`nx`](https://next-scripting.org/) | 2.4.0 | the Next Scripting Framework OO system (+ mongo/serializer/traits/… submodules) |

## Concurrency & threads

| Package | Version | Notes |
|---|---|---|
| [`csp`](https://wiki.tcl-lang.org/page/csp) | 0.1.0 |  |
| [`promise`](https://wiki.tcl-lang.org/page/promise) | 1.1.0 |  |
| [`Thread`](https://www.tcl-lang.org/man/tcl/ThreadCmd/thread.html) | 2.8.5 |  |
| [`Ttrace`](https://wiki.tcl-lang.org/page/Ttrace) | 2.8.5 |  |

## Filesystems & packaging

| Package | Version | Notes |
|---|---|---|
| [`fileutil::globfind`](https://wiki.tcl-lang.org/search?q=fileutil%20globfind) | 1.5 |  |
| [`starkit`](https://wiki.tcl-lang.org/page/starkit) | 1.3.3 |  |
| [`tbcload`](https://wiki.tcl-lang.org/page/tbcload) | 1.7 |  |
| [`tcllibc`](https://wiki.tcl-lang.org/search?q=tcllibc) | 1.21 |  |
| [`tinyfileutils`](https://wiki.tcl-lang.org/search?q=tinyfileutils) | 1.0 |  |
| [`trofs`](https://wiki.tcl-lang.org/page/trofs) | 0.4.9 |  |
| [`trsync`](https://wiki.tcl-lang.org/search?q=trsync) | 1.0 |  |
| [`vfs`](https://wiki.tcl-lang.org/page/vfs) | 1.4.2 | TclVFS virtual filesystems (+ template/*, opcua, urltype) |

## Parsing

| Package | Version | Notes |
|---|---|---|
| [`parser`](https://wiki.tcl-lang.org/page/parser) | 1.8 |  |
| [`yeti`](https://wiki.tcl-lang.org/page/yeti) | 0.4.2 |  |
| [`ylex`](https://wiki.tcl-lang.org/page/ylex) | 0.4.2 |  |

## Barcodes

| Package | Version | Notes |
|---|---|---|
| [`zint`](https://sourceforge.net/projects/zint/) | 2.13.0 |  |

## Dev, docs & debugging

| Package | Version | Notes |
|---|---|---|
| [`autoopts`](https://wiki.tcl-lang.org/search?q=autoopts) | 0.6.1 |  |
| [`classview`](https://wiki.tcl-lang.org/search?q=classview) | 0.1 |  |
| [`parse_args`](https://wiki.tcl-lang.org/search?q=parse_args) | 0.5.1 |  |
| [`tkcon`](https://wiki.tcl-lang.org/page/tkcon) | 2.7 |  |
| [`tkconclient`](https://wiki.tcl-lang.org/search?q=tkconclient) | 1.0 |  |
| [`twDebugInspector`](https://wiki.tcl-lang.org/search?q=twDebugInspector) | 0.1 |  |
| [`uriencode`](https://wiki.tcl-lang.org/search?q=uriencode) | 1.0 |  |
| [`wibble`](https://wiki.tcl-lang.org/search?q=wibble) | 0.4 |  |

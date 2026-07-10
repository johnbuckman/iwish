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
| [`Ble`](https://wiki.tcl-lang.org/search?q=Ble) | 1.0 | Bluetooth Low Energy central: scan for peripherals, connect, and read/write GATT characteristics (iWish's iOS CoreBluetooth shim) |
| [`Borg`](https://wiki.tcl-lang.org/search?q=Borg) | 1.0 | native OS bridge: toast notifications, screen brightness, keep-awake, share sheet, system UI, sensors, device info (the AndroWish `borg` command, iOS build) |

## Tk widgets & themes

| Package | Version | Notes |
|---|---|---|
| [`awthemes`](https://wiki.tcl-lang.org/search?q=awthemes) | 10.4.0 | scalable ttk theme collection: awdark, awlight, awarc, awblack, awbreeze(dark), awclearlooks, awtemplate, awwinxpblue |
| [`BWidget`](https://wiki.tcl-lang.org/page/BWidget) | 1.9.16 | pure-Tcl mega-widget toolkit: trees, notebooks, comboboxes, dialogs, progress bars, scrollable frames |
| [`flexmenu`](https://wiki.tcl-lang.org/search?q=flexmenu) | 1.52 | menu widget that can lay items out horizontally or vertically |
| [`fsdialog`](https://wiki.tcl-lang.org/search?q=fsdialog) | 1.15 | themed (ttk) replacement for the file/directory selection dialogs |
| [`gridplus`](https://wiki.tcl-lang.org/search?q=gridplus) | 2.11 | compact form-building megawidget — labelled entries, layouts and dialogs from a short syntax |
| [`icons`](https://wiki.tcl-lang.org/search?q=icons) | 2.0 | library of ready-to-use named icons for buttons and toolbars |
| [`Iwidgets`](https://wiki.tcl-lang.org/page/Iwidgets) | 4.0 | [incr Widgets] — the classic Itcl/Itk mega-widget set (comboboxes, dialogs, notebooks, panedwindows, …) |
| [`keynav`](https://wiki.tcl-lang.org/search?q=keynav) | 1.0 | keyboard focus-traversal / navigation helper for Tk UIs |
| [`MaterialIcons`](https://wiki.tcl-lang.org/search?q=MaterialIcons) | 0.2 | Google Material Design icon set as Tk images |
| [`music`](https://wiki.tcl-lang.org/search?q=music) | 0.1 | play musical notes / simple tones |
| [`photoframe`](https://wiki.tcl-lang.org/search?q=photoframe) | 1.0 | widget that displays a photo image scaled and framed to fit |
| [`QuickTimeTcl`](https://wiki.tcl-lang.org/search?q=QuickTimeTcl) | 3.1 | embed and control QuickTime movies/audio in Tk (legacy macOS API — inert on iOS) |
| [`scrolldata`](https://wiki.tcl-lang.org/search?q=scrolldata) | 2.12 | scrollable tabular data display widget |
| [`tkled`](https://wiki.tcl-lang.org/search?q=tkled) | 0.1 | LED-style status indicator widget |
| [`tknotebook`](https://wiki.tcl-lang.org/search?q=tknotebook) | 0.1 | tabbed notebook (page-turner) widget |
| [`Tktable`](https://wiki.tcl-lang.org/page/Tktable) | 2.11 | 2-D table/spreadsheet grid widget with embedded windows and editing |
| [`touchcal`](https://wiki.tcl-lang.org/search?q=touchcal) | 0.1 | touch-friendly calendar / date-picker widget |
| [`treectrl`](https://wiki.tcl-lang.org/page/treectrl) | 2.4.2 | powerful multi-column tree/list widget with icons, styles and in-place editing |
| [`ttk::dialog`](https://wiki.tcl-lang.org/search?q=ttk%20dialog) | 0.8 | themed (ttk) standard message/confirmation dialogs |
| [`ttk::icons`](https://wiki.tcl-lang.org/search?q=ttk%20icons) | 0 | themed icon set for ttk widgets |
| [`vu`](https://wiki.tcl-lang.org/page/vu) | 2.3 | extra widgets: dial, pie slice, spinbox, bargraph and more |

## Graphics, plotting & canvas

| Package | Version | Notes |
|---|---|---|
| [`BLT`](https://wiki.tcl-lang.org/page/BLT) | 2.4 | graph/barchart/vector/spline + table layout toolkit (real-time line graphs, plots) |
| [`can2svg`](https://wiki.tcl-lang.org/search?q=can2svg) | 0.3 | export a Tk canvas to an SVG file |
| [`colorutils`](https://wiki.tcl-lang.org/search?q=colorutils) | 4.8 | colour-space conversions and colour manipulation helpers |
| [`pikchr`](https://wiki.tcl-lang.org/search?q=pikchr) | 1.0 | render PIC-style "pikchr" diagram markup to SVG |
| [`svg2can`](https://wiki.tcl-lang.org/search?q=svg2can) | 1.0 | render/import an SVG document onto a Tk canvas |
| [`tkpath`](https://wiki.tcl-lang.org/page/tkpath) | 0.3.3 | advanced canvas with path items, gradients and antialiased 2-D vector graphics |
| [`tksvg`](https://wiki.tcl-lang.org/page/tksvg) | 0.14 | load SVG files as Tk photo images |
| [`ukaz`](https://wiki.tcl-lang.org/search?q=ukaz) | 2.1 | 2-D data plotting/graphing (gnuplot-style) on a Tk canvas |

## Image formats

| Package | Version | Notes |
|---|---|---|
| [`Img`](https://sourceforge.net/projects/tkimg/) | 1.4.11 | Tk image-format handlers — all formats: BMP/GIF/JPEG/PNG/PPM/PS/SGI/SUN/TGA/TIFF/XBM/XPM/ICO/PCX/pixmap/raw/window |
| [`imgjp2`](https://wiki.tcl-lang.org/search?q=imgjp2) | 0.1 | JPEG 2000 (.jp2) image-format handler for Tk |
| [`jpegtcl`](https://wiki.tcl-lang.org/page/jpegtcl) | 9.2 | bundled libjpeg backing the Img JPEG handler |
| [`pngtcl`](https://wiki.tcl-lang.org/page/pngtcl) | 1.6.35 | bundled libpng backing the Img PNG handler |
| [`stbimage`](https://wiki.tcl-lang.org/search?q=stbimage) | 0.8 | load images via the stb_image single-file decoder (PNG/JPG/BMP/GIF/…) |
| [`tifftcl`](https://wiki.tcl-lang.org/page/tifftcl) | 3.9.7 | bundled libtiff backing the Img TIFF handler |
| [`zlibtcl`](https://wiki.tcl-lang.org/page/zlibtcl) | 1.2.11 | bundled zlib compression used by the png/tiff handlers |

## PDF & office documents

| Package | Version | Notes |
|---|---|---|
| [`ooxml`](https://wiki.tcl-lang.org/page/ooxml) | 1.7 | read and write Office Open XML (.xlsx) spreadsheets |
| [`pdf4tcl`](https://wiki.tcl-lang.org/page/pdf4tcl) | 0.9.4 | generate PDF documents from Tcl (+ graph/stdmetrics/glyph2unicode) |

## Databases & data stores

| Package | Version | Notes |
|---|---|---|
| [`lmdb`](https://wiki.tcl-lang.org/search?q=lmdb) | 0.4.3 | Lightning Memory-Mapped Database — fast embedded key-value store |
| [`ral`](https://wiki.tcl-lang.org/search?q=ral) | 0.12.2 | Tcl Relational Algebra: in-memory relations/relvars with full relational operators |
| [`raloo`](https://wiki.tcl-lang.org/search?q=raloo) | 0.2 | object-relational OO layer built on ral |
| [`ralutil`](https://wiki.tcl-lang.org/search?q=ralutil) | 0.12.2 | utility procs for ral (relvar helpers, CSV/SQL import, sequences) |
| [`retcl`](https://wiki.tcl-lang.org/search?q=retcl) | 0.4.0 | asynchronous Redis client |
| [`sqlite3`](https://sqlite.org/tclsqlite.html) | 3.45.1 | the SQLite embedded SQL database engine |
| [`tdbc`](https://www.tcl-lang.org/man/tcl/TdbcCmd/tdbc.html) | 1.1.1 | Tcl DataBase Connectivity — uniform database access API (+ sqlite3/jdbc drivers) |

## Data formats & serialization

| Package | Version | Notes |
|---|---|---|
| [`didl`](https://wiki.tcl-lang.org/search?q=didl) | 0.2 | structured-data interchange (DIDL) encode/decode |
| [`JSONRPC`](https://wiki.tcl-lang.org/page/JSONRPC) | 0.1 | JSON-RPC client/server over HTTP |
| [`msgpack`](https://wiki.tcl-lang.org/page/msgpack) | 2.0.0 | MessagePack binary serialization (pack/unpack) |
| [`rl_json`](https://wiki.tcl-lang.org/page/rl_json) | 0.15.1 | fast JSON parse/generate with a native JSON value type and path access |
| [`tclcsv`](https://wiki.tcl-lang.org/page/tclcsv) | 2.3 | read and write CSV / delimited files (+ a CSV table widget) |
| [`tdom`](https://www.tdom.org/) | 0.9.3 | high-performance XML/HTML/DOM parser with XPath and XSLT |
| [`tinydom`](https://wiki.tcl-lang.org/page/tinydom) | 0.2 | small, pure-Tcl XML DOM parser |
| [`vcd`](https://wiki.tcl-lang.org/search?q=vcd) | 0.1 | read/write VCD (Value Change Dump) digital-waveform files |
| [`vcdnooo`](https://wiki.tcl-lang.org/search?q=vcdnooo) | 0.1 | object-oriented interface to VCD waveform data |
| [`XMLRPC`](https://wiki.tcl-lang.org/page/XMLRPC) | 1.0.1 | XML-RPC client/server (part of TclSOAP) |

## Cryptography & TLS

| Package | Version | Notes |
|---|---|---|
| [`tls`](https://core.tcl-lang.org/tcltls/) | 1.6.9 | OpenSSL/LibreSSL-backed SSL/TLS channels for secure sockets (https, etc.) |

## Networking & protocols

| Package | Version | Notes |
|---|---|---|
| [`broker`](https://wiki.tcl-lang.org/page/broker) | 2.1 | message broker / publish-subscribe dispatch |
| [`http`](https://wiki.tcl-lang.org/page/http) | 2.6.9 | HTTP/1.1 client for GET/POST and REST calls |
| [`Memchan`](https://wiki.tcl-lang.org/page/Memchan) | 2.4 | in-memory Tcl channels (fifo, fifo2, memchan, null) |
| [`modbus`](https://wiki.tcl-lang.org/page/modbus) | 0.1 | Modbus industrial-protocol client (RTU/TCP) |
| [`mqtt`](https://wiki.tcl-lang.org/page/mqtt) | 3.1.1 | MQTT publish/subscribe messaging client |
| [`nats`](https://wiki.tcl-lang.org/page/nats) | 3.0 | client for the NATS messaging system |
| [`pty`](https://wiki.tcl-lang.org/page/pty) | 0.1 | pseudo-terminal support to spawn and drive terminal programs |
| [`rmq`](https://wiki.tcl-lang.org/page/rmq) | 1.4.5 | RabbitMQ / AMQP 0-9-1 messaging client |
| [`rpcvar`](https://wiki.tcl-lang.org/search?q=rpcvar) | 1.2 | typed-variable support for SOAP/XML-RPC (part of TclSOAP) |
| [`snap7`](https://wiki.tcl-lang.org/search?q=snap7) | 0.1 | Snap7 communication with Siemens S7 PLCs |
| [`SOAP`](https://wiki.tcl-lang.org/page/SOAP) | 1.6.8.1 | SOAP web-service client/server (+ CGI/Domain/Service/http(s)/smtp/ftp/xpath, soapinterop) |
| [`ssdp`](https://wiki.tcl-lang.org/page/ssdp) | 0.2 | SSDP service discovery (UPnP device/service announcements) |
| [`tfirmata`](https://wiki.tcl-lang.org/search?q=tfirmata) | 2.5 | Firmata client to control Arduino boards over serial |
| [`tomato`](https://wiki.tcl-lang.org/search?q=tomato) | 1.2.3 | iCalendar (RFC 5545) parser/generator |
| [`topcua`](https://wiki.tcl-lang.org/search?q=topcua) | 0.5 | OPC-UA industrial client (+ cgen/filesystem/prdict/sqlmodel) |
| [`udp`](https://wiki.tcl-lang.org/page/udp) | 1.0.11 | UDP datagram socket support |
| [`upnp`](https://wiki.tcl-lang.org/page/upnp) | 0.2 | UPnP device discovery and control |
| [`vnc`](https://wiki.tcl-lang.org/page/vnc) | 0.5 | VNC/RFB client to view and control a remote desktop |
| [`WS::*`](https://wiki.tcl-lang.org/search?q=WS) | 2.6.3 | Web Services framework (Client/Server/Utils/Channel/Embeded/AOLserver) |
| [`www`](https://wiki.tcl-lang.org/page/www) | 2.4 | WWW client (+ http2/websocket/socks/proxypac/digest) |
| [`XOTcl`](https://next-scripting.org/) | 2.4.0 | XOTcl 2 object system (+ comm/serializer/metadata/htmllib/… submodules) |

## Object systems (OO)

| Package | Version | Notes |
|---|---|---|
| [`Itcl`](https://www.tcl-lang.org/man/tcl/ItclCmd/contents.html) | 4.2.0 | [incr Tcl] — class-based OO with inheritance, methods and namespaces |
| [`Itk`](https://wiki.tcl-lang.org/page/Itk) | 4.1.0 | [incr Tk] — mega-widget framework built on Itcl (the base for Iwidgets) |
| [`nsf`](https://next-scripting.org/) | 2.4.0 | Next Scripting Framework core (+ mongo) |
| [`nx`](https://next-scripting.org/) | 2.4.0 | the Next Scripting Framework OO language (+ mongo/serializer/traits/… submodules) |

## Concurrency & threads

| Package | Version | Notes |
|---|---|---|
| [`csp`](https://wiki.tcl-lang.org/page/csp) | 0.1.0 | Communicating Sequential Processes — channels + goroutine-style concurrency |
| [`promise`](https://wiki.tcl-lang.org/page/promise) | 1.1.0 | promises/futures for composing asynchronous code |
| [`Thread`](https://www.tcl-lang.org/man/tcl/ThreadCmd/thread.html) | 2.8.5 | real OS threads with shared-nothing message passing and thread-shared variables |
| [`Ttrace`](https://wiki.tcl-lang.org/page/Ttrace) | 2.8.5 | propagate procs/code into new threads (script caching for Thread) |

## Filesystems & packaging

| Package | Version | Notes |
|---|---|---|
| [`fileutil::globfind`](https://wiki.tcl-lang.org/search?q=fileutil%20globfind) | 1.5 | recursive file finding via glob-based directory traversal |
| [`starkit`](https://wiki.tcl-lang.org/page/starkit) | 1.3.3 | Starkit/Starpack single-file wrapped-application support (VFS-based) |
| [`tbcload`](https://wiki.tcl-lang.org/page/tbcload) | 1.7 | loader for pre-compiled Tcl bytecode (.tbc) files |
| [`tcllibc`](https://wiki.tcl-lang.org/search?q=tcllibc) | 1.21 | optional C-accelerated implementations of some tcllib modules |
| [`tinyfileutils`](https://wiki.tcl-lang.org/search?q=tinyfileutils) | 1.0 | small file-manipulation utility procs |
| [`trofs`](https://wiki.tcl-lang.org/page/trofs) | 0.4.9 | read-only filesystem archive mountable via VFS (append to a script) |
| [`trsync`](https://wiki.tcl-lang.org/search?q=trsync) | 1.0 | rsync-style tree delta/synchronisation helper |
| [`vfs`](https://wiki.tcl-lang.org/page/vfs) | 1.4.2 | TclVFS virtual filesystems — mount zip/tar/ftp/http/mk4 as directories (+ template/*, opcua, urltype) |

## Parsing

| Package | Version | Notes |
|---|---|---|
| [`parser`](https://wiki.tcl-lang.org/page/parser) | 1.8 | parse Tcl scripts into token trees (the Tcl parser exposed as a command) |
| [`yeti`](https://wiki.tcl-lang.org/page/yeti) | 0.4.2 | YACC-like LALR parser generator for Tcl |
| [`ylex`](https://wiki.tcl-lang.org/page/ylex) | 0.4.2 | lex-like lexical-analyzer generator (companion to yeti) |

## Barcodes

| Package | Version | Notes |
|---|---|---|
| [`zint`](https://sourceforge.net/projects/zint/) | 2.13.0 | generate 50+ barcode & 2-D symbologies (QR, Code128, EAN, DataMatrix, …) |

## Dev, docs & debugging

| Package | Version | Notes |
|---|---|---|
| [`autoopts`](https://wiki.tcl-lang.org/search?q=autoopts) | 0.6.1 | declarative command-line option parsing |
| [`classview`](https://wiki.tcl-lang.org/search?q=classview) | 0.1 | GUI class/namespace browser for Itcl/OO code |
| [`parse_args`](https://wiki.tcl-lang.org/search?q=parse_args) | 0.5.1 | fast declarative named-argument parser for Tcl procs |
| [`tkcon`](https://wiki.tcl-lang.org/page/tkcon) | 2.7 | enhanced Tk console / interactive REPL |
| [`tkconclient`](https://wiki.tcl-lang.org/search?q=tkconclient) | 1.0 | connect to a remote tkcon console |
| [`twDebugInspector`](https://wiki.tcl-lang.org/search?q=twDebugInspector) | 0.1 | GUI variable/data inspector for debugging |
| [`uriencode`](https://wiki.tcl-lang.org/search?q=uriencode) | 1.0 | URI percent-encoding and decoding helpers |
| [`wibble`](https://wiki.tcl-lang.org/search?q=wibble) | 0.4 | small pure-Tcl web server |

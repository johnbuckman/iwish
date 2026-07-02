# iWish batteries — the included Tcl/Tk extension packages

These are the loadable **battery** packages bundled with the iWish Tcl/Tk build for
jailbroken iOS 9.3.5 (32-bit / armv7) — **494 packages** in total, grouped by what
they do. Load any of them with `package require <name>`. Back to the main guide:
[IOS9-BATTERIES.md](IOS9-BATTERIES.md).

> Most of these come from **tcllib** / **tklib** / **AndroWish**; a few (the `ble` and
> `borg` shims) are specific to this iOS port. A handful of declared packages may not
> load on-device (missing optional native deps) — see IOS9-ARMV7.md.


## Bluetooth & platform services  ·  2

*Bluetooth LE and Android-style platform services (the two iOS shims built for this port).*

| Package | Version |
|---|---|
| `Ble` | 1.0 |
| `Borg` | 1.0 |

## Ttk themes & styling  ·  24

*Ttk (themed Tk) themes and style helpers.*

| Package | Version |
|---|---|
| `awarc` | 1.6.1 |
| `awblack` | 7.8.1 |
| `awbreeze` | 1.9.1 |
| `awbreezedark` | 1.0.1 |
| `awclearlooks` | 1.3.1 |
| `awdark` | 7.12 |
| `awlight` | 7.10 |
| `awtemplate` | 1.5.1 |
| `awthemes` | 10.4.0 |
| `awwinxpblue` | 7.9.1 |
| `scaleutilmisc` | 1.5 |
| `style` | 0.3 |
| `style::as` | 1.4.1 |
| `style::lobster` | 0.2 |
| `themepatch` | 1.5 |
| `ttk::theme::awarc` | 1.6.1 |
| `ttk::theme::awblack` | 7.8.1 |
| `ttk::theme::awbreeze` | 1.9.1 |
| `ttk::theme::awbreezedark` | 1.0.1 |
| `ttk::theme::awclearlooks` | 1.3.1 |
| `ttk::theme::awdark` | 7.12 |
| `ttk::theme::awlight` | 7.10 |
| `ttk::theme::awtemplate` | 1.5.1 |
| `ttk::theme::awwinxpblue` | 7.9.1 |

## Tk widgets & megawidgets  ·  62

*Extra widgets and widget frameworks for Tk GUIs.*

| Package | Version |
|---|---|
| `autoscroll` | 1.1 |
| `BWidget` | 1.9.16 |
| `chatwidget` | 1.1.4 |
| `controlwidget` | 0.1 |
| `ctext` | 3.3 |
| `cursor` | 0.3.1 |
| `datefield` | 0.3 |
| `flexmenu` | 1.52 |
| `fsdialog` | 1.15 |
| `getstring` | 0.1 |
| `gridplus` | 2.11 |
| `icons` | 2.0 |
| `ipentry` | 0.3 |
| `Iwidgets` | 4.0 |
| `keynav` | 1.0 |
| `khim` | 1.0.1 |
| `MaterialIcons` | 0.2 |
| `mentry::common` | 4.1 |
| `menubar` | 0.5 |
| `menubar::debug` | 0.5 |
| `menubar::node` | 0.5 |
| `menubar::tree` | 0.5 |
| `music` | 0.1 |
| `mwutil` | 2.22 |
| `notifywindow` | 1.0 |
| `ntext` | 1.0b6 |
| `photoframe` | 1.0 |
| `QuickTimeTcl` | 3.1 |
| `scrolldata` | 2.12 |
| `scrollutil::common` | 2.1 |
| `shtmlview::shtmlview` | 1.1.0 |
| `swaplist` | 0.2 |
| `tablelist::common` | 7.1 |
| `tipstack` | 1.0.1 |
| `tkled` | 0.1 |
| `tknotebook` | 0.1 |
| `tkpiechart` | 6.6 |
| `Tktable` | 2.11 |
| `touchcal` | 0.1 |
| `treectrl` | 2.4.2 |
| `ttk::dialog` | 0.8 |
| `ttk::icons` | 0 |
| `vu` | 2.3 |
| `Wcb` | 4.0 |
| `wcb` | 4.0 |
| `widget::all` | 1.2.4 |
| `widget::arrowbutton` | 1.0 |
| `widget::calendar` | 1.0.1 |
| `widget::dateentry` | 0.96 |
| `widget::dialog` | 1.3.1 |
| `widget::listsimple` | 0.1.2 |
| `widget::menuentry` | 1.0.1 |
| `widget::panelframe` | 1.1 |
| `widget::ruler` | 1.1 |
| `widget::screenruler` | 1.2 |
| `widget::scrolledtext` | 1.0 |
| `widget::scrolledwindow` | 1.2.1 |
| `widget::statusbar` | 1.2.1 |
| `widget::superframe` | 1.0.1 |
| `widget::toolbar` | 1.2.1 |
| `widget::validator` | 0.1 |
| `widgetPlus` | 1.0b2 |

## 2-D graphics, plotting & canvas  ·  13

*Plotting, vector/SVG drawing and canvas helpers.*

| Package | Version |
|---|---|
| `BLT` | 2.4 |
| `can2svg` | 0.3 |
| `canvas::edit::quadrilateral` | 0.1 |
| `canvas::sqmap` | 0.3.1 |
| `colorutils` | 4.8 |
| `crosshair` | 1.2.1 |
| `diagram::application` | 1.2 |
| `pikchr` | 1.0 |
| `Plotchart` | 2.6.1 |
| `svg2can` | 1.0 |
| `tkpath` | 0.3.3 |
| `tksvg` | 0.14 |
| `ukaz` | 2.1 |

## Image formats & codecs  ·  32

*Image reading/writing (all Img formats) and codecs.*

| Package | Version |
|---|---|
| `ico` | 0.3.2 |
| `ico` | 1.1 |
| `Img` | 1.4.11 |
| `img::base` | 1.4.11 |
| `img::bmp` | 1.4.11 |
| `img::dted` | 1.4.11 |
| `img::flir` | 1.4.11 |
| `img::gif` | 1.4.11 |
| `img::ico` | 1.4.11 |
| `img::jpeg` | 1.4.11 |
| `img::pcx` | 1.4.11 |
| `img::pixmap` | 1.4.11 |
| `img::png` | 1.4.11 |
| `img::ppm` | 1.4.11 |
| `img::ps` | 1.4.11 |
| `img::raw` | 1.4.11 |
| `img::sgi` | 1.4.11 |
| `img::sun` | 1.4.11 |
| `img::tga` | 1.4.11 |
| `img::tiff` | 1.4.11 |
| `img::window` | 1.4.11 |
| `img::xbm` | 1.4.11 |
| `img::xpm` | 1.4.11 |
| `imgjp2` | 0.1 |
| `jpeg` | 0.6 |
| `jpegtcl` | 9.2 |
| `png` | 0.4 |
| `pngtcl` | 1.6.35 |
| `stbimage` | 0.8 |
| `tiff` | 0.2.2 |
| `tifftcl` | 3.9.7 |
| `zlibtcl` | 1.2.11 |

## PDF & documents  ·  18

*PDF generation, office documents and documentation tooling.*

| Package | Version |
|---|---|
| `bibtex` | 0.8 |
| `docstrip` | 1.3 |
| `docstrip::util` | 1.3.2 |
| `doctools::changelog` | 1.2 |
| `doctools::config` | 0.2 |
| `doctools::html::cssdefaults` | 0.2 |
| `doctools::idx::export::docidx` | 0.2 |
| `doctools::idx::import::docidx` | 0.2 |
| `doctools::nroff::man_macros` | 0.2 |
| `doctools::toc::export::doctoc` | 0.2 |
| `doctools::toc::import::doctoc` | 0.2 |
| `dtplite` | 1.3.2 |
| `mkdoc` | 0.7.2 |
| `ooxml` | 1.7 |
| `pdf4tcl` | 0.9.4 |
| `pdf4tcl::glyph2unicode` | 0.1 |
| `pdf4tcl::graph` | 1.0 |
| `pdf4tcl::stdmetrics` | 0.1 |

## Databases & data stores  ·  9

*SQL/NoSQL databases and relational/data stores.*

| Package | Version |
|---|---|
| `lmdb` | 0.4.3 |
| `ral` | 0.12.2 |
| `raloo` | 0.2 |
| `ralutil` | 0.12.2 |
| `retcl` | 0.4.0 |
| `sqlite3` | 3.45.1 |
| `tdbc` | 1.1.1 |
| `tdbc::jdbc` | 0.2.0 |
| `tdbc::sqlite3` | 1.1.1 |

## Data formats, JSON/XML & serialization  ·  18

*Parsing and emitting structured data formats.*

| Package | Version |
|---|---|
| `asn` | 0.8.5 |
| `base32::core` | 0.2 |
| `bee` | 0.2 |
| `csv` | 0.10 |
| `didl` | 0.2 |
| `huddle::json` | 0.2 |
| `inifile` | 0.3.3 |
| `json` | 1.3.5 |
| `json::write` | 1.0.5 |
| `msgpack` | 2.0.0 |
| `report` | 0.5 |
| `rl_json` | 0.15.1 |
| `tclcsv` | 2.3 |
| `tdom` | 0.9.3 |
| `tinydom` | 0.2 |
| `vcd` | 0.1 |
| `vcdnooo` | 0.1 |
| `xsxp` | 1.1 |

## Archives & compression  ·  4

*tar/zip archives and compression.*

| Package | Version |
|---|---|
| `tar` | 0.12 |
| `zipfile::decode` | 0.10 |
| `zipfile::encode` | 0.5 |
| `zipfile::mkzip` | 1.2.3 |

## Cryptography, hashing & auth  ·  26

*TLS, ciphers, digests, and authentication.*

| Package | Version |
|---|---|
| `aes` | 1.2.2 |
| `blowfish` | 1.0.6 |
| `cksum` | 1.1.5 |
| `crc16` | 1.1.5 |
| `crc32` | 1.3.4 |
| `des` | 1.2 |
| `md4` | 1.0.8 |
| `md5` | 1.4.6 |
| `md5` | 2.0.9 |
| `md5crypt` | 1.2.0 |
| `oauth` | 1.0.4 |
| `otp` | 1.1.0 |
| `pki` | 0.22 |
| `rc4` | 1.2.0 |
| `ripemd128` | 1.0.6 |
| `ripemd160` | 1.0.6 |
| `SASL::XGoogleToken` | 1.0.2 |
| `sha256` | 1.0.5 |
| `stringprep` | 1.0.2 |
| `stringprep::data` | 1.0.2 |
| `tclDES` | 1.1 |
| `tclDESjr` | 1.1 |
| `tls` | 1.6.9 |
| `uuencode` | 1.1.6 |
| `uuid` | 1.0.8 |
| `valtype::creditcard::mastercard` | 1.1 |

## Networking & internet protocols  ·  83

*HTTP, mail, messaging, RPC/SOAP, sockets and more.*

| Package | Version |
|---|---|
| `autoopts` | 0.6.1 |
| `autoproxy` | 1.8.1 |
| `broker` | 1.0 |
| `broker` | 2.1 |
| `cache::async` | 0.3.2 |
| `comm` | 4.7.2 |
| `ftp::geturl` | 0.2.3 |
| `ftpd` | 1.4 |
| `http` | 2.6 |
| `http` | 2.6.9 |
| `http::wget` | 0.2.1 |
| `httpd` | 4.3.6 |
| `ident` | 0.43 |
| `imap4` | 0.5.4 |
| `JSONRPC` | 0.1 |
| `ldap` | 1.10.2 |
| `ldapx` | 1.3 |
| `mime` | 1.7.2 |
| `mqtt` | 2.0 |
| `mqtt` | 3.1.1 |
| `multiplexer` | 0.3 |
| `nameserv::cluster` | 0.2.6 |
| `nameserv::common` | 0.2 |
| `nameserv::server` | 0.3.3 |
| `nats` | 3.0 |
| `ncgi` | 1.4.5 |
| `nettool` | 0.5.3 |
| `nettool::available_ports` | 0.2 |
| `nntp` | 0.2.2 |
| `picoirc` | 0.14.0 |
| `pop3` | 1.11 |
| `pop3d::dbox` | 1.0.3 |
| `resolv` | 1.0.4 |
| `rest` | 1.6 |
| `rmq` | 1.4.5 |
| `rpcvar` | 1.2 |
| `smtp` | 1.5.2 |
| `smtpd` | 1.6 |
| `SOAP` | 1.6.8.1 |
| `SOAP::CGI` | 1.0.1 |
| `SOAP::Domain` | 1.4.1 |
| `SOAP::ftp` | 1.0 |
| `SOAP::http` | 1.0 |
| `SOAP::https` | 1.0 |
| `SOAP::Service` | 0.5 |
| `SOAP::smtp` | 1.0 |
| `SOAP::Utils` | 1.1 |
| `SOAP::xpath` | 0.2 |
| `soapinterop::B` | 1.0 |
| `soapinterop::base` | 1.0 |
| `soapinterop::C` | 1.0 |
| `ssdp` | 0.2 |
| `tomato` | 1.2.3 |
| `transfer::data::destination` | 0.3 |
| `udp` | 1.0.11 |
| `upnp` | 0.2 |
| `uri::urn` | 1.0.4 |
| `uriencode` | 1.0 |
| `vnc` | 0.5 |
| `websocket` | 1.6 |
| `WS::AOLserver` | 2.4.0 |
| `WS::Channel` | 2.4.0 |
| `WS::Client` | 2.6.3 |
| `WS::Embeded` | 2.7.2 |
| `WS::Server` | 2.7.0 |
| `WS::Utils` | 2.6.2 |
| `www` | 2.4 |
| `www::digest` | 1.0 |
| `www::http2` | 1.0 |
| `www::proxypac` | 2.1 |
| `www::socks` | 1.0 |
| `www::websocket` | 1.0.1 |
| `XMLRPC` | 1.0.1 |
| `XOTcl` | 2.4.0 |
| `xotcl::comm::connection` | 2.0 |
| `xotcl::comm::dav` | 2.0 |
| `xotcl::comm::ftp` | 2.0 |
| `xotcl::comm::httpAccess` | 2.0 |
| `xotcl::comm::httpd` | 2.0 |
| `xotcl::comm::imap` | 2.0 |
| `xotcl::comm::ldap` | 2.0 |
| `xotcl::comm::mime` | 2.0 |
| `xotcl::comm::pcache` | 2.0 |

## Industrial / IoT / instrumentation  ·  10

*Fieldbus/PLC, Firmata, OPC-UA, GPS/NMEA.*

| Package | Version |
|---|---|
| `modbus` | 0.1 |
| `nmea` | 1.1.0 |
| `snap7` | 0.1 |
| `tfirmata` | 2.5 |
| `topcua` | 0.5 |
| `topcua::cgen` | 0.1 |
| `topcua::filesystem` | 0.1 |
| `topcua::prdict` | 0.1 |
| `topcua::sqlmodel` | 0.1 |
| `vfs::opcua` | 0.1 |

## Maps & geospatial  ·  7

*Map projections, tiles and GPS tracks.*

| Package | Version |
|---|---|
| `gpx` | 1.1 |
| `map::geocode::nominatim` | 0.3 |
| `map::point::store::memory` | 0.1 |
| `map::point::table-display` | 0.1 |
| `map::track::store::memory` | 0.1 |
| `map::track::table-display` | 0.1 |
| `mapproj` | 1.1 |

## Text, HTML & markup  ·  11

*Text utilities, HTML parsing, Markdown, terminals.*

| Package | Version |
|---|---|
| `html` | 1.6 |
| `htmlparse` | 1.2.3 |
| `javascript` | 1.0.3 |
| `Markdown` | 1.2.4 |
| `soundex` | 1.1 |
| `string::token::shell` | 1.3 |
| `term::ansi::code::macros` | 0.2 |
| `textutil::expander` | 1.3.2 |
| `textutil::wcswidth` | 35.3 |
| `unicode` | 1.1.0 |
| `unicode::data` | 1.1.0 |

## Parsing & grammars  ·  25

*Parser generators and grammar/PEG tooling.*

| Package | Version |
|---|---|
| `grammar::aycock` | 1.1 |
| `grammar::aycock::debug` | 1.1 |
| `grammar::aycock::runtime` | 1.1 |
| `grammar::fa::dacceptor` | 0.1.2 |
| `grammar::me::cpu::core` | 0.3 |
| `grammar::me::cpu::gasm` | 0.2 |
| `grammar::peg::interp` | 0.1.2 |
| `page::analysis::peg::realizable` | 0.2 |
| `page::gen::peg::canon` | 0.2 |
| `page::gen::peg::mecpu` | 0.2 |
| `page::gen::tree::text` | 0.2 |
| `page::pluginmgr` | 0.3 |
| `page::reader::treeser` | 0.2 |
| `page::transform::mecpu` | 0.2 |
| `page::transform::realizable` | 0.2 |
| `page::util::norm::lemon` | 0.2 |
| `page::util::quote` | 0.2 |
| `page::writer::identity` | 0.2 |
| `parser` | 1.8 |
| `pt::peg::container::peg` | 1.1.1 |
| `pt::peg::export::container` | 1.1 |
| `pt::pgen` | 1.4 |
| `pt::tclparam::configuration::tcloo` | 1.0.5 |
| `yeti` | 0.4.2 |
| `ylex` | 0.4.2 |

## Object systems (OO)  ·  42

*Object-orientation frameworks and helpers.*

| Package | Version |
|---|---|
| `clay` | 0.8.7 |
| `dicttool` | 1.2 |
| `Itcl` | 4.2.0 |
| `itcl` | 4.2.0 |
| `Itk` | 4.1.0 |
| `itk` | 4.1.0 |
| `nsf` | 2.4.0 |
| `nsf::mongo` | 2.4.0 |
| `nx` | 2.4.0 |
| `nx::class-method` | 1.0 |
| `nx::help` | 1.0 |
| `nx::mongo` | 2.4.0 |
| `nx::plain-object-method` | 1.0 |
| `nx::pp` | 1.0 |
| `nx::serializer` | 2.4.0 |
| `nx::shell` | 1.1 |
| `nx::test` | 1.0 |
| `nx::trait` | 0.4 |
| `nx::trait::callback` | 1.0 |
| `nx::volatile` | 1.0 |
| `nx::zip` | 1.3 |
| `oo::dialect` | 0.3.4 |
| `oo::option` | 0.3.2 |
| `oo::util` | 1.2.3 |
| `snit` | 1.4.2 |
| `snit` | 2.3.3 |
| `stooop` | 4.4.2 |
| `tool` | 0.8 |
| `XOTcl-langRef` | 2.0 |
| `xotcl::htmllib` | 2.0 |
| `xotcl::metadataAnalyzer` | 2.0 |
| `xotcl::mixinStrategy` | 2.0 |
| `xotcl::package` | 2.0 |
| `xotcl::script` | 2.0 |
| `xotcl::scriptCreation::recoveryPoint` | 2.0 |
| `xotcl::scriptCreation::scriptCreator` | 2.0 |
| `xotcl::serializer` | 2.4 |
| `xotcl::staticMetadataAnalyzer` | 2.0 |
| `xotcl::trace` | 2.0 |
| `xotcl::upvar-compat` | 2.0 |
| `xotcl::wafecompat` | 2.0 |
| `xotcl::xodoc` | 2.0 |

## Concurrency, channels & threads  ·  40

*Threads, reflected/transform channels, coroutines.*

| Package | Version |
|---|---|
| `coroutine::auto` | 1.2 |
| `cron` | 2.2 |
| `csp` | 0.1.0 |
| `Memchan` | 2.4 |
| `odie::processman` | 0.7 |
| `processman` | 0.7 |
| `promise` | 1.1.0 |
| `pty` | 0.1 |
| `tcl::chan::cat` | 1.0.4 |
| `tcl::chan::core` | 1.1 |
| `tcl::chan::events` | 1.1 |
| `tcl::chan::facade` | 1.0.2 |
| `tcl::chan::fifo` | 1.1 |
| `tcl::chan::fifo2` | 1.1 |
| `tcl::chan::halfpipe` | 1.0.3 |
| `tcl::chan::memchan` | 1.0.5 |
| `tcl::chan::null` | 1.1 |
| `tcl::chan::nullzero` | 1.1 |
| `tcl::chan::random` | 1.1 |
| `tcl::chan::std` | 1.0.2 |
| `tcl::chan::string` | 1.0.4 |
| `tcl::chan::textwindow` | 1.1 |
| `tcl::chan::variable` | 1.0.5 |
| `tcl::chan::zero` | 1.1 |
| `tcl::randomseed` | 1.1 |
| `tcl::transform::adler32` | 1.1 |
| `tcl::transform::base64` | 1.1 |
| `tcl::transform::core` | 1.1 |
| `tcl::transform::counter` | 1.1 |
| `tcl::transform::crc32` | 1.1 |
| `tcl::transform::hex` | 1.1 |
| `tcl::transform::identity` | 1.1 |
| `tcl::transform::limitsize` | 1.1 |
| `tcl::transform::observe` | 1.1 |
| `tcl::transform::otp` | 1.1 |
| `tcl::transform::rot` | 1.1 |
| `tcl::transform::spacer` | 1.1 |
| `tcl::transform::zlib` | 1.0.2 |
| `Thread` | 2.8.5 |
| `Ttrace` | 2.8.5 |

## Structures, algorithms & math  ·  30

*Data structures, math, simulation, units, timing.*

| Package | Version |
|---|---|
| `clock::iso8601` | 0.2 |
| `clock::rfc2822` | 0.2 |
| `control` | 0.1.4 |
| `counter` | 2.0.5 |
| `defer` | 1.1 |
| `generator` | 0.3 |
| `history` | 0.1 |
| `hook` | 0.3 |
| `interp::delegate::method` | 0.3 |
| `lambda` | 1.1 |
| `lazyset` | 1.1 |
| `math::calculus::symdiff` | 1.0.2 |
| `math::machineparameters` | 0.2 |
| `math::rationalfunctions` | 1.0.2 |
| `namespacex` | 0.4 |
| `simulation::annealing` | 0.3 |
| `simulation::montecarlo` | 0.2 |
| `simulation::random` | 0.5.0 |
| `struct::disjointset` | 1.2 |
| `struct::graph::op` | 0.11.4 |
| `struct::prioqueue` | 1.5 |
| `switched` | 2.2.2 |
| `throw` | 1.1 |
| `tie::std::growfile` | 1.2 |
| `time` | 1.2.2 |
| `treeql` | 1.3.2 |
| `uevent::onidle` | 0.2 |
| `units` | 2.2.2 |
| `wip` | 1.3 |
| `wip` | 2.3 |

## Virtual filesystems & files  ·  21

*VFS layers, file utilities, starkits, bytecode.*

| Package | Version |
|---|---|
| `fileutil` | 1.16.2 |
| `fileutil::globfind` | 1.5 |
| `fileutil::magic::cfront` | 1.3.1 |
| `fileutil::magic::filetype` | 2.0.2 |
| `fileutil::magic::rt` | 3.1 |
| `fileutil::multi::op` | 0.5.4 |
| `rcs` | 0.2 |
| `starkit` | 1.3.3 |
| `tbcload` | 1.7 |
| `tinyfileutils` | 1.0 |
| `trofs` | 0.4.9 |
| `trsync` | 1.0 |
| `vfs` | 1.4.2 |
| `vfs::template` | 1.5.5 |
| `vfs::template::chroot` | 1.5.2 |
| `vfs::template::collate` | 1.5.3 |
| `vfs::template::fish` | 1.5.2 |
| `vfs::template::quota` | 1.5.2 |
| `vfs::template::version` | 1.5.2 |
| `vfs::template::version::delta` | 1.5.2 |
| `vfs::urltype` | 1.0 |

## Barcodes  ·  1

*Barcode/QR generation.*

| Package | Version |
|---|---|
| `zint` | 2.13.0 |

## Development, docs & debugging  ·  16

*Console, logging, benchmarking, plugin/build tooling.*

| Package | Version |
|---|---|
| `bench::out::text` | 0.1.3 |
| `classview` | 0.1 |
| `cmdline` | 1.5.3 |
| `debug::heartbeat` | 1.0.2 |
| `debug::timestamp` | 1.1 |
| `logger::appender` | 1.4 |
| `parse_args` | 0.5.1 |
| `pluginmgr` | 0.4 |
| `practcl` | 0.16.5 |
| `profiler` | 0.7 |
| `tcllibc` | 1.21 |
| `tepam::doc_gen` | 0.1.2 |
| `tkcon` | 2.7 |
| `tkconclient` | 1.0 |
| `twDebugInspector` | 0.1 |
| `wibble` | 0.4 |

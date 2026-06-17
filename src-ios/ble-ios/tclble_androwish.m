/*
 * tclble.m -- in-process CoreBluetooth backend for the AndroWish-compatible
 * "ble" Tcl command on macOS / iOS.  This is the native (loadable extension)
 * alternative to the bin/ble_helper subprocess; ble.tcl loads it by default and
 * falls back to the helper when in-process Bluetooth isn't available (e.g. an
 * unsignable undroidwish, where TCC denies Bluetooth to the interpreter).
 *
 * It speaks the SAME API and event dictionaries as ble.tcl, so the de1app runs
 * unchanged:
 *
 *   ble scanner  <cb>                               -> token (registers cb)
 *   ble start    <token>                            -> begin scanning
 *   ble stop     <token>                            -> stop scanning
 *   ble connect  <address> <cb> ?<reconnect>?       -> handle
 *   ble close    <handle>
 *   ble info     ?<handle>?
 *   ble enable   <h> <suuid> <si> <cuuid> <ci>      -> 1
 *   ble disable  <h> <suuid> <si> <cuuid> <ci>      -> 1
 *   ble write    <h> <suuid> <si> <cuuid> <ci> ?<writetype>? <data>  -> 1
 *   ble read     <h> <suuid> <si> <cuuid> <ci>      -> 1
 *   ble mtu      <h> ?<value>?
 *   ble userdata <h> ?<value>?
 *   ble state                                       -> central manager state
 *
 * Callbacks are invoked on the Tcl thread as:  {*}$cb $event $datadict
 * matching ble.tcl (events: scan / connection / characteristic / descriptor).
 *
 * Adapted from John Buckman's iWish ble extension (iwish/ble-ios/tclBLEios.m).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <tcl.h>
#include <unistd.h>
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

/* ---- cross-thread event marshalling: run a script on the Tcl thread ----- */

static Tcl_Interp   *gInterp = NULL;
static Tcl_ThreadId  gTclThread = NULL;

typedef struct EvalEvent { Tcl_Event header; char *script; } EvalEvent;

static int EvalEventProc(Tcl_Event *evPtr, int flags) {
    EvalEvent *e = (EvalEvent *) evPtr;
    if (gInterp && e->script) {
        if (Tcl_EvalEx(gInterp, e->script, -1, TCL_EVAL_GLOBAL) != TCL_OK) {
            Tcl_BackgroundException(gInterp, TCL_ERROR);
        }
    }
    if (e->script) ckfree(e->script);
    return 1;
}

static void BLEEval(NSString *script) {
    if (gTclThread == NULL || script == NULL) return;
    const char *s = [script UTF8String];
    size_t n = strlen(s) + 1;
    EvalEvent *e = (EvalEvent *) ckalloc(sizeof(EvalEvent));
    e->header.proc = EvalEventProc;
    e->header.nextPtr = NULL;
    e->script = ckalloc((int)n);
    memcpy(e->script, s, n);
    Tcl_ThreadQueueEvent(gTclThread, (Tcl_Event *) e, TCL_QUEUE_TAIL);
    Tcl_ThreadAlert(gTclThread);
}

/* Tcl list-quote a string (safe inside a `dict create` script). */
static NSString *q(NSString *s) {
    if (s == nil) s = @"";
    Tcl_DString ds; Tcl_DStringInit(&ds);
    char *quoted = Tcl_DStringAppendElement(&ds, [s UTF8String]);
    NSString *r = [NSString stringWithUTF8String:quoted];
    Tcl_DStringFree(&ds);
    return r;
}

/* Binary data as a double-quoted "\xNN..." literal so it survives a script
 * round-trip and arrives as a Tcl byte array (used as the `value` dict key). */
static NSString *bytesLiteral(NSData *d) {
    if (d == nil || d.length == 0) return @"\"\"";
    const unsigned char *p = d.bytes;
    NSMutableString *m = [NSMutableString stringWithCapacity:d.length*4+2];
    [m appendString:@"\""];
    for (NSUInteger i = 0; i < d.length; i++) [m appendFormat:@"\\x%02x", p[i]];
    [m appendString:@"\""];
    return m;
}

static const char *stateName(CBManagerState st) {
    switch (st) {
        case CBManagerStatePoweredOn:    return "poweredOn";
        case CBManagerStatePoweredOff:   return "poweredOff";
        case CBManagerStateUnauthorized: return "unauthorized";
        case CBManagerStateUnsupported:  return "unsupported";
        case CBManagerStateResetting:    return "resetting";
        default:                         return "unknown";
    }
}

static NSString *longUUID(CBUUID *u) {
    NSString *s = [u.UUIDString uppercaseString];
    if (s.length == 4) return [NSString stringWithFormat:@"0000%@-0000-1000-8000-00805F9B34FB", s];
    if (s.length == 8) return [NSString stringWithFormat:@"%@-0000-1000-8000-00805F9B34FB", s];
    return s;
}
#define CCCD_UUID @"00002902-0000-1000-8000-00805F9B34FB"

/* ---- model objects ----------------------------------------------------- */

@class CharRef;

@interface BLEConn : NSObject
@property (strong) CBPeripheral *peripheral;
@property (copy)   NSString *handle;
@property (copy)   NSString *address;
@property (copy)   NSString *callback;
@property (copy)   NSString *userdata;
@property (assign) NSInteger pendingServices;
@property (assign) BOOL connectedEmitted;
@property (assign) NSUInteger mtu;
@end
@implementation BLEConn @end

@interface CharRef : NSObject
@property (weak)   BLEConn *conn;
@property (strong) CBCharacteristic *ch;
@property (copy)   NSString *suuid;
@property (assign) int sinstance;
@property (copy)   NSString *cuuid;
@property (assign) int cinstance;
@property (strong) NSData *lastWrite;
@property (assign) BOOL pendingRead;
@end
@implementation CharRef @end

@interface BLEManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong) CBCentralManager *central;
@property (strong) NSMutableDictionary<NSString*,BLEConn*> *conns;       /* handle -> conn */
@property (strong) NSMutableDictionary<NSString*,CBPeripheral*> *byUUID; /* address -> peripheral */
@property (strong) NSMutableDictionary<NSNumber*,CharRef*> *charsByInst; /* cinstance -> CharRef */
@property (strong) NSMapTable *charsByObj;                               /* CBCharacteristic -> CharRef */
@property (copy)   NSString *scanCallback;
@property (assign) int nextHandle;
@property (assign) int nextInstance;
@property (assign) BOOL wantScan;
@property (assign) CBManagerState lastState;
@end

static BLEManager *gMgr = nil;
static dispatch_queue_t gQueue = nil;

@implementation BLEManager

- (instancetype)init {
    if ((self = [super init])) {
        _conns = [NSMutableDictionary dictionary];
        _byUUID = [NSMutableDictionary dictionary];
        _charsByInst = [NSMutableDictionary dictionary];
        _charsByObj = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory
                                            valueOptions:NSPointerFunctionsStrongMemory];
        _nextHandle = 1;
        _nextInstance = 1;
        _lastState = CBManagerStateUnknown;
        /* Dedicated serial queue: GCD always services its own queues, so
         * CoreBluetooth works even though the Tcl event loop is not a CFRunLoop.
         * Delegate callbacks fire here and marshal to the Tcl thread. */
        gQueue = dispatch_queue_create("com.decentespresso.ble", DISPATCH_QUEUE_SERIAL);
        /* No ShowPowerAlert: a loadable library must not pop system UI, and the
         * alert machinery can wedge the host's run loop when TCC can't resolve. */
        dispatch_async(gQueue, ^{
            self->_central = [[CBCentralManager alloc] initWithDelegate:self queue:gQueue];
        });
    }
    return self;
}

- (BLEConn *)connFor:(CBPeripheral *)p {
    for (BLEConn *c in self.conns.allValues) if (c.peripheral == p) return c;
    return nil;
}

- (void)startScan {
    if (self.central.state == CBManagerStatePoweredOn) {
        [self.central scanForPeripheralsWithServices:nil
            options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
    } else {
        self.wantScan = YES;
    }
}

/* --- central delegate (runs on gQueue) --- */

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    self.lastState = central.state;
    if (self.scanCallback) {
        BLEEval([NSString stringWithFormat:@"%@ state [dict create state %s]",
                 self.scanCallback, stateName(central.state)]);
    }
    if (central.state == CBManagerStatePoweredOn && self.wantScan) {
        self.wantScan = NO;
        [self startScan];
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)p
     advertisementData:(NSDictionary *)adv RSSI:(NSNumber *)rssi {
    NSString *addr = [p.identifier.UUIDString uppercaseString];
    self.byUUID[addr] = p;
    NSString *name = adv[CBAdvertisementDataLocalNameKey];
    if (!name) name = p.name ? p.name : @"";
    if (self.scanCallback) {
        BLEEval([NSString stringWithFormat:
            @"%@ scan [dict create address %@ name %@ rssi %@]",
            self.scanCallback, q(addr), q(name), rssi]);
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)p {
    BLEConn *c = [self connFor:p];
    if (!c) return;
    p.delegate = self;
    c.connectedEmitted = NO;
    c.pendingServices = 0;
    [p discoverServices:nil];
}

- (void)emitDisconnect:(BLEConn *)c {
    if (c.callback)
        BLEEval([NSString stringWithFormat:
            @"%@ connection [dict create handle %@ address %@ state disconnected]",
            c.callback, q(c.handle), q(c.address)]);
}
- (void)cleanup:(BLEConn *)c {
    NSMutableArray *kill = [NSMutableArray array];
    for (NSNumber *k in self.charsByInst) if (self.charsByInst[k].conn == c) [kill addObject:k];
    for (NSNumber *k in kill) {
        CharRef *r = self.charsByInst[k];
        if (r.ch) [self.charsByObj removeObjectForKey:r.ch];
        [self.charsByInst removeObjectForKey:k];
    }
    [self.conns removeObjectForKey:c.handle];
    [self.byUUID removeObjectForKey:c.address];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)p error:(NSError *)error {
    BLEConn *c = [self connFor:p]; if (!c) return;
    [self emitDisconnect:c]; [self cleanup:c];
}
- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)p error:(NSError *)error {
    BLEConn *c = [self connFor:p]; if (!c) return;
    [self emitDisconnect:c]; [self cleanup:c];
}

/* --- peripheral delegate (runs on gQueue) --- */

- (void)peripheral:(CBPeripheral *)p didDiscoverServices:(NSError *)error {
    BLEConn *c = [self connFor:p]; if (!c) return;
    NSArray *svcs = p.services ? p.services : @[];
    c.pendingServices = svcs.count;
    if (svcs.count == 0) { [self finishDiscovery:c]; return; }
    for (CBService *s in svcs) [p discoverCharacteristics:nil forService:s];
}

- (void)peripheral:(CBPeripheral *)p
didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    BLEConn *c = [self connFor:p]; if (!c) return;
    NSString *suuid = longUUID(service.UUID);
    int sinst = self.nextInstance++;
    for (CBCharacteristic *ch in service.characteristics) {
        CharRef *r = [CharRef new];
        r.conn = c; r.ch = ch; r.suuid = suuid; r.sinstance = sinst;
        r.cuuid = longUUID(ch.UUID); r.cinstance = self.nextInstance++;
        self.charsByInst[@(r.cinstance)] = r;
        [self.charsByObj setObject:r forKey:ch];
        if (c.callback)
            BLEEval([NSString stringWithFormat:
                @"%@ characteristic [dict create handle %@ address %@ state discovery "
                 "suuid %@ sinstance %d cuuid %@ cinstance %d]",
                c.callback, q(c.handle), q(c.address),
                q(r.suuid), r.sinstance, q(r.cuuid), r.cinstance]);
    }
    if (--c.pendingServices <= 0) [self finishDiscovery:c];
}

- (void)finishDiscovery:(BLEConn *)c {
    if (c.connectedEmitted) return;
    c.connectedEmitted = YES;
    c.mtu = [c.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse] + 3;
    if (c.callback)
        BLEEval([NSString stringWithFormat:
            @"%@ connection [dict create handle %@ address %@ state connected mtu %lu]",
            c.callback, q(c.handle), q(c.address), (unsigned long)c.mtu]);
}

- (void)emitChar:(CharRef *)r access:(NSString *)acc value:(NSData *)v {
    if (!r.conn.callback) return;
    BLEEval([NSString stringWithFormat:
        @"%@ characteristic [dict create handle %@ address %@ state connected access %@ "
         "suuid %@ sinstance %d cuuid %@ cinstance %d value %@]",
        r.conn.callback, q(r.conn.handle), q(r.conn.address), acc,
        q(r.suuid), r.sinstance, q(r.cuuid), r.cinstance, bytesLiteral(v)]);
}

- (void)peripheral:(CBPeripheral *)p
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error {
    CharRef *r = [self.charsByObj objectForKey:ch]; if (!r) return;
    /* The de1app advances its write queue on the CCCD ("descriptor") write ack. */
    if (r.conn.callback)
        BLEEval([NSString stringWithFormat:
            @"%@ descriptor [dict create handle %@ address %@ state connected access w "
             "suuid %@ sinstance %d cuuid %@ cinstance %d duuid %@]",
            r.conn.callback, q(r.conn.handle), q(r.conn.address),
            q(r.suuid), r.sinstance, q(r.cuuid), r.cinstance, CCCD_UUID]);
}

- (void)peripheral:(CBPeripheral *)p
didWriteValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error {
    CharRef *r = [self.charsByObj objectForKey:ch]; if (!r) return;
    [self emitChar:r access:@"w" value:r.lastWrite];
}

- (void)peripheral:(CBPeripheral *)p
didUpdateValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error {
    CharRef *r = [self.charsByObj objectForKey:ch]; if (!r) return;
    NSString *acc; if (r.pendingRead) { r.pendingRead = NO; acc = @"r"; } else acc = @"c";
    [self emitChar:r access:acc value:(ch.value ? ch.value : [NSData data])];
}
@end

/* ---- the Tcl "ble" command (runs on the Tcl thread) -------------------- */

static int BleCmd(ClientData cd, Tcl_Interp *ip, int objc, Tcl_Obj *const objv[]) {
    if (objc < 2) { Tcl_WrongNumArgs(ip, 1, objv, "subcommand ?args?"); return TCL_ERROR; }
    const char *sub = Tcl_GetString(objv[1]);
    @autoreleasepool {

    if (strcmp(sub, "state") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewStringObj(stateName(gMgr.lastState), -1));
        return TCL_OK;
    }
    if (strcmp(sub, "probe") == 0) {
        /* ble probe ?ms? -- block (via plain usleep, NOT the Tcl event loop, so
         * it can never wedge the host) until the central settles, then return
         * its state.  ble.tcl uses this to decide native-vs-fallback. */
        int ms = 1500; if (objc >= 3) Tcl_GetIntFromObj(NULL, objv[2], &ms);
        int waited = 0;
        while (waited < ms && gMgr.lastState == CBManagerStateUnknown) {
            usleep(50000); waited += 50;   /* gQueue (a separate thread) advances */
        }
        Tcl_SetObjResult(ip, Tcl_NewStringObj(stateName(gMgr.lastState), -1));
        return TCL_OK;
    }
    if (strcmp(sub, "scanner") == 0) {
        gMgr.scanCallback = (objc >= 3) ? [NSString stringWithUTF8String:Tcl_GetString(objv[2])] : nil;
        [gMgr startScan];
        Tcl_SetObjResult(ip, Tcl_NewStringObj("blescanner1", -1));
        return TCL_OK;
    }
    if (strcmp(sub, "start") == 0) { [gMgr startScan]; return TCL_OK; }
    if (strcmp(sub, "stop") == 0) {
        gMgr.wantScan = NO;
        if (gMgr.central.state == CBManagerStatePoweredOn) [gMgr.central stopScan];
        return TCL_OK;
    }
    if (strcmp(sub, "connect") == 0) {
        /* ble connect <address> <callback> ?<reconnect>? */
        if (objc < 4) { Tcl_WrongNumArgs(ip, 2, objv, "address callback ?reconnect?"); return TCL_ERROR; }
        NSString *addr = [[NSString stringWithUTF8String:Tcl_GetString(objv[2])] uppercaseString];
        NSString *cbs  = [NSString stringWithUTF8String:Tcl_GetString(objv[3])];
        if (gMgr.lastState == CBManagerStatePoweredOff ||
            gMgr.lastState == CBManagerStateUnauthorized ||
            gMgr.lastState == CBManagerStateUnsupported) {
            Tcl_SetResult(ip, (char*)"unsupported", TCL_STATIC); return TCL_ERROR;
        }
        CBPeripheral *pp = gMgr.byUUID[addr];
        if (!pp) {
            NSUUID *nu = [[NSUUID alloc] initWithUUIDString:addr];
            pp = nu ? [gMgr.central retrievePeripheralsWithIdentifiers:@[nu]].firstObject : nil;
        }
        /* NOT "unsupported" -- de1app shows "Bluetooth is not on" for that exact
         * string. Peripheral-not-found (e.g. startup reconnect before the scan
         * has discovered it) is a different case; use a distinct error so de1app
         * just logs it and falls back to scanning. */
        if (!pp) { Tcl_SetResult(ip, (char*)"device not found", TCL_STATIC); return TCL_ERROR; }
        BLEConn *c = [BLEConn new];
        c.peripheral = pp; c.address = addr; c.callback = cbs;
        c.handle = [NSString stringWithFormat:@"ble%d", gMgr.nextHandle++];
        gMgr.conns[c.handle] = c;
        pp.delegate = gMgr;
        [gMgr.central connectPeripheral:pp options:nil];
        Tcl_SetObjResult(ip, Tcl_NewStringObj([c.handle UTF8String], -1));
        return TCL_OK;
    }
    if (strcmp(sub, "info") == 0) {
        if (objc < 3) {
            Tcl_Obj *l = Tcl_NewListObj(0, NULL);
            for (NSString *h in gMgr.conns) Tcl_ListObjAppendElement(ip, l, Tcl_NewStringObj([h UTF8String], -1));
            Tcl_SetObjResult(ip, l); return TCL_OK;
        }
        BLEConn *c = gMgr.conns[[NSString stringWithUTF8String:Tcl_GetString(objv[2])]];
        if (!c) { Tcl_SetObjResult(ip, Tcl_NewStringObj("", -1)); return TCL_OK; }
        Tcl_SetObjResult(ip, Tcl_NewStringObj([[NSString stringWithFormat:
            @"handle %@ address %@ mtu %lu", c.handle, c.address, (unsigned long)(c.mtu?c.mtu:23)] UTF8String], -1));
        return TCL_OK;
    }
    if (strcmp(sub, "abort") == 0 || strcmp(sub, "unpair") == 0 || strcmp(sub, "pair") == 0) return TCL_OK;

    /* remaining subcommands take a handle as objv[2] */
    if (objc < 3) { Tcl_WrongNumArgs(ip, 1, objv, "subcommand handle ?args?"); return TCL_ERROR; }
    NSString *h = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
    BLEConn *c = gMgr.conns[h];

    if (strcmp(sub, "close") == 0 || strcmp(sub, "disconnect") == 0) {
        if ([h hasPrefix:@"blescanner"]) { gMgr.wantScan = NO; if (gMgr.central.state==CBManagerStatePoweredOn) [gMgr.central stopScan]; return TCL_OK; }
        if (c && c.peripheral) [gMgr.central cancelPeripheralConnection:c.peripheral];
        return TCL_OK;
    }
    if (strcmp(sub, "reconnect") == 0) {
        /* ble reconnect <handle> -- de1app's ble_connect_to_scale nudges a
         * pending connection with this; re-issue the connect attempt. */
        if (c && c.peripheral) [gMgr.central connectPeripheral:c.peripheral options:nil];
        Tcl_SetObjResult(ip, Tcl_NewIntObj(1));
        return TCL_OK;
    }
    if (strcmp(sub, "mtu") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewIntObj((int)(c && c.mtu ? c.mtu : 23)));
        return TCL_OK;
    }
    if (strcmp(sub, "userdata") == 0) {
        if (c && objc >= 4) c.userdata = [NSString stringWithUTF8String:Tcl_GetString(objv[3])];
        Tcl_SetObjResult(ip, Tcl_NewStringObj((c && c.userdata) ? [c.userdata UTF8String] : "", -1));
        return TCL_OK;
    }

    /* ble enable/disable/read  <h> <suuid> <si> <cuuid> <ci>
     * ble write <h> <suuid> <si> <cuuid> <ci> ?<writetype>? <data>
     * We route by cinstance (objv[6]); suuid/cuuid are accepted but unused. */
    if (strcmp(sub,"enable")==0 || strcmp(sub,"disable")==0 ||
        strcmp(sub,"read")==0   || strcmp(sub,"write")==0) {
        if (objc < 7) { Tcl_WrongNumArgs(ip, 2, objv, "handle suuid si cuuid ci ..."); return TCL_ERROR; }
        int ci = 0; Tcl_GetIntFromObj(NULL, objv[6], &ci);
        CharRef *r = gMgr.charsByInst[@(ci)];
        if (!r) { Tcl_SetResult(ip, (char*)"characteristic not found", TCL_STATIC); return TCL_ERROR; }

        if (strcmp(sub, "enable") == 0) {
            [r.conn.peripheral setNotifyValue:YES forCharacteristic:r.ch];
        } else if (strcmp(sub, "disable") == 0) {
            [r.conn.peripheral setNotifyValue:NO forCharacteristic:r.ch];
        } else if (strcmp(sub, "read") == 0) {
            r.pendingRead = YES;
            [r.conn.peripheral readValueForCharacteristic:r.ch];
        } else { /* write: optional writetype before data */
            Tcl_Obj *dataObj; int wtype = 2;
            if (objc >= 9) { Tcl_GetIntFromObj(NULL, objv[7], &wtype); dataObj = objv[8]; }
            else if (objc >= 8) { dataObj = objv[7]; }
            else { Tcl_SetResult(ip, (char*)"missing data", TCL_STATIC); return TCL_ERROR; }
            int len = 0; unsigned char *b = Tcl_GetByteArrayFromObj(dataObj, &len);
            NSData *d = [NSData dataWithBytes:b length:len];
            r.lastWrite = d;
            CBCharacteristicWriteType wt = (wtype == 1) ? CBCharacteristicWriteWithoutResponse
                                                        : CBCharacteristicWriteWithResponse;
            [r.conn.peripheral writeValue:d forCharacteristic:r.ch type:wt];
            /* withResponse acks via didWriteValueForCharacteristic; without
             * response has no callback, so synthesise the write-ack now. */
            if (wt == CBCharacteristicWriteWithoutResponse)
                dispatch_async(gQueue, ^{ [gMgr emitChar:r access:@"w" value:d]; });
        }
        Tcl_SetObjResult(ip, Tcl_NewIntObj(1));
        return TCL_OK;
    }

    } /* @autoreleasepool */
    Tcl_SetObjResult(ip, Tcl_ObjPrintf("ble: unsupported subcommand \"%s\"", sub));
    return TCL_ERROR;
}

int Ble_Init(Tcl_Interp *ip) {
    if (Tcl_InitStubs(ip, "8.6", 0) == NULL) return TCL_ERROR;
    gInterp = ip;
    gTclThread = Tcl_GetCurrentThread();
    @autoreleasepool { gMgr = [BLEManager new]; }
    Tcl_CreateObjCommand(ip, "ble", BleCmd, NULL, NULL);
    return Tcl_PkgProvide(ip, "ble", "1.0");
}

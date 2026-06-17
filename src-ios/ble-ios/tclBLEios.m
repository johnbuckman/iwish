/*
 * tclBLEios.m -- a CoreBluetooth backend for AndroWish's "ble" Tcl command,
 * for iOS / Mac Catalyst (iWish). Implements the subset of the ble API the
 * Decent de1app actually uses:
 *
 *   ble scanner <callback>            -> start scanning; returns scanner handle
 *   ble stop <scanner>                -> stop scanning
 *   ble connect <callback> <uuid>     -> connect to a peripheral by identifier
 *   ble services <conn>               -> list discovered service UUIDs
 *   ble characteristics <conn> <svc>  -> list characteristic UUIDs of a service
 *   ble write <conn> <svc> <si> <chr> <ci> <data>   -> write (with response)
 *   ble read  <conn> <svc> <si> <chr> <ci>          -> read
 *   ble enable <conn> <svc> <si> <chr> <ci>         -> subscribe (notify)
 *   ble disable <conn> <svc> <si> <chr> <ci>        -> unsubscribe
 *   ble info <conn>                   -> {state ... mtu ...}
 *   ble mtu <conn>                    -> negotiated ATT MTU
 *   ble userdata <conn> ?value?       -> get/set opaque per-conn user data
 *   ble close <conn>                  -> disconnect
 *   ble callback <conn> ?script?      -> get/set per-conn callback
 *   ble expand/shorten/equal <uuid>   -> 16<->128-bit UUID helpers
 *
 * Events are delivered by evaluating the relevant callback script in the Tcl
 * interpreter's thread, with arguments compatible with AndroWish's ble events:
 *   <cb> <conn> scan    <uuid> <name> <rssi> <advdata>
 *   <cb> <conn> connection <state>            (e.g. "connected"/"disconnected")
 *   <cb> <conn> service     <uuid>
 *   <cb> <conn> characteristic <svc> <chr>
 *   <cb> <conn> read   <svc> <si> <chr> <ci> <data>
 *   <cb> <conn> write  <svc> <si> <chr> <ci> <status>
 *   <cb> <conn> notification <svc> <si> <chr> <ci> <data>
 */

#include <tcl.h>
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

/* ---- cross-thread event marshalling ------------------------------------ */

static Tcl_Interp   *gInterp = NULL;
static Tcl_ThreadId  gTclThread = NULL;

typedef struct EvalEvent {
    Tcl_Event header;
    char     *script;     /* malloc'd, freed after eval */
} EvalEvent;

static int
EvalEventProc(Tcl_Event *evPtr, int flags)
{
    EvalEvent *e = (EvalEvent *) evPtr;
    if (gInterp && e->script) {
        if (Tcl_EvalEx(gInterp, e->script, -1, TCL_EVAL_GLOBAL) != TCL_OK) {
            Tcl_BackgroundException(gInterp, TCL_ERROR);
        }
    }
    if (e->script) { ckfree(e->script); }
    return 1; /* handled */
}

/* Queue a Tcl script for evaluation on the interpreter thread. */
static void
BLEQueueScript(NSString *script)
{
    if (gTclThread == NULL || script == NULL) { return; }
    const char *s = [script UTF8String];
    size_t n = strlen(s) + 1;
    EvalEvent *e = (EvalEvent *) ckalloc(sizeof (EvalEvent));
    e->header.proc = EvalEventProc;
    e->header.nextPtr = NULL;
    e->script = ckalloc(n);
    memcpy(e->script, s, n);
    Tcl_ThreadQueueEvent(gTclThread, (Tcl_Event *) e, TCL_QUEUE_TAIL);
    Tcl_ThreadAlert(gTclThread);
}

/* Tcl list-quote a C string. */
static NSString *
q(NSString *s)
{
    if (s == nil) { return @"{}"; }
    Tcl_DString ds; Tcl_DStringInit(&ds);
    char *quoted = Tcl_DStringAppendElement(&ds, [s UTF8String]);
    NSString *r = [NSString stringWithUTF8String:quoted];
    Tcl_DStringFree(&ds);
    return r;
}

/* bytes -> a Tcl binary-ish hex/byte string the app can [binary scan]. We
 * deliver as a brace-quoted raw byte string (de1app uses binary data). */
static NSString *
bytesToTcl(NSData *d)
{
    if (d == nil || d.length == 0) { return @"{}"; }
    /* Represent as \xNN escapes inside double quotes so any byte survives. */
    const unsigned char *p = d.bytes;
    NSMutableString *m = [NSMutableString stringWithCapacity:d.length*4+2];
    [m appendString:@"\""];
    for (NSUInteger i = 0; i < d.length; i++) {
        [m appendFormat:@"\\x%02x", p[i]];
    }
    [m appendString:@"\""];
    return m;
}

/* ---- connection objects ------------------------------------------------- */

@class BLEManager;

@interface BLEConn : NSObject
@property (strong) CBPeripheral *peripheral;
@property (copy)   NSString *handle;       /* Tcl handle, e.g. "ble1" */
@property (copy)   NSString *callback;     /* Tcl callback script prefix */
@property (copy)   NSString *userdata;
@property (assign) BOOL connected;
@end
@implementation BLEConn @end

@interface BLEManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong) CBCentralManager *central;
@property (strong) NSMutableDictionary<NSString*,BLEConn*> *conns;     /* handle -> conn */
@property (strong) NSMutableDictionary<NSString*,CBPeripheral*> *byUUID;
@property (copy)   NSString *scanCallback;
@property (assign) int nextHandle;
@property (assign) BOOL pendingScan;       /* scan requested before poweredOn */
@end

static BLEManager *gMgr = nil;

@implementation BLEManager

- (instancetype)init {
    if ((self = [super init])) {
        _conns  = [NSMutableDictionary dictionary];
        _byUUID = [NSMutableDictionary dictionary];
        _nextHandle = 1;
        /* CoreBluetooth must run on a queue that is actually serviced.  On Mac
         * Catalyst the Tk interp runs on a background thread (no run loop) and
         * the main dispatch queue is NOT reliably serviced from console mode, so
         * a manager created on either left CBCentralManager stuck in state
         * 'unknown' forever.  Apple's robust off-main pattern: a dedicated
         * serial dispatch queue, with the manager CREATED ON that queue (GCD
         * always services its own queues).  Delegate callbacks fire on bleQueue
         * and are marshalled to the Tcl thread via BLEQueueScript. */
        static dispatch_queue_t bleQueue;
        static dispatch_once_t bleQueueOnce;
        dispatch_once(&bleQueueOnce, ^{
            bleQueue = dispatch_queue_create("org.iwish.ble", DISPATCH_QUEUE_SERIAL);
        });
        dispatch_async(bleQueue, ^{
            self->_central = [[CBCentralManager alloc] initWithDelegate:self queue:bleQueue];
        });
    }
    return self;
}

- (BLEConn *)connForPeripheral:(CBPeripheral *)p {
    for (BLEConn *c in self.conns.allValues) {
        if (c.peripheral == p) { return c; }
    }
    return nil;
}

/* --- central delegate --- */

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    /* states: 0 unknown,1 resetting,2 unsupported,3 unauthorized,4 off,5 on */
    if (self.scanCallback) {
        const char *names[] = {"unknown","resetting","unsupported","unauthorized","poweredOff","poweredOn"};
        int st = (int)central.state; if (st < 0 || st > 5) st = 0;
        BLEQueueScript([NSString stringWithFormat:@"%@ state [dict create state %s]", self.scanCallback, names[st]]);
    }
    if (central.state == CBManagerStatePoweredOn && self.pendingScan) {
        self.pendingScan = NO;
        [self.central scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)adv
                  RSSI:(NSNumber *)rssi {
    NSString *uuid = peripheral.identifier.UUIDString;
    self.byUUID[uuid] = peripheral;
    if (self.scanCallback) {
        NSString *name = adv[CBAdvertisementDataLocalNameKey];
        if (!name) name = peripheral.name ? peripheral.name : @"";
        /* AndroWish dict-event API: de1_ble_handler does `dict with data {}`,
           so emit `<cb> scan {address .. name .. rssi ..}` (NOT flat args). */
        NSString *script = [NSString stringWithFormat:@"%@ scan [dict create address %@ name %@ rssi %@]",
                            self.scanCallback, q(uuid), q(name), rssi];
        BLEQueueScript(script);
    }
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (!c) { return; }
    c.connected = YES;
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    if (c.callback) {
        BLEQueueScript([NSString stringWithFormat:@"%@ %@ connection connected",
                        c.callback, q(c.handle)]);
    }
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (!c) { return; }
    c.connected = NO;
    if (c.callback) {
        BLEQueueScript([NSString stringWithFormat:@"%@ %@ connection disconnected",
                        c.callback, q(c.handle)]);
    }
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (c && c.callback) {
        BLEQueueScript([NSString stringWithFormat:@"%@ %@ connection failed",
                        c.callback, q(c.handle)]);
    }
}

/* --- peripheral delegate --- */

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    for (CBService *s in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:s];
        if (c && c.callback) {
            BLEQueueScript([NSString stringWithFormat:@"%@ %@ service %@",
                            c.callback, q(c.handle), q(s.UUID.UUIDString)]);
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (c && c.callback) {
        for (CBCharacteristic *ch in service.characteristics) {
            BLEQueueScript([NSString stringWithFormat:@"%@ %@ characteristic %@ %@",
                            c.callback, q(c.handle), q(service.UUID.UUIDString),
                            q(ch.UUID.UUIDString)]);
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (!c || !c.callback) { return; }
    NSString *kind = ch.isNotifying ? @"notification" : @"read";
    NSString *script = [NSString stringWithFormat:@"%@ %@ %@ %@ 0 %@ 0 %@",
        c.callback, q(c.handle), kind,
        q(ch.service.UUID.UUIDString), q(ch.UUID.UUIDString), bytesToTcl(ch.value)];
    BLEQueueScript(script);
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error {
    BLEConn *c = [self connForPeripheral:peripheral];
    if (!c || !c.callback) { return; }
    BLEQueueScript([NSString stringWithFormat:@"%@ %@ write %@ 0 %@ 0 %d",
        c.callback, q(c.handle), q(ch.service.UUID.UUIDString),
        q(ch.UUID.UUIDString), (int)(error ? 1 : 0)]);
}

/* --- helpers to find a characteristic by UUID --- */

- (CBCharacteristic *)charOf:(BLEConn *)c service:(NSString *)svc chr:(NSString *)chr {
    CBUUID *su = [CBUUID UUIDWithString:svc];
    CBUUID *cu = [CBUUID UUIDWithString:chr];
    for (CBService *s in c.peripheral.services) {
        if (![s.UUID isEqual:su]) { continue; }
        for (CBCharacteristic *ch in s.characteristics) {
            if ([ch.UUID isEqual:cu]) { return ch; }
        }
    }
    return nil;
}
@end

/* ---- the Tcl "ble" command --------------------------------------------- */

static NSData *
tclBytesToData(Tcl_Obj *obj)
{
    int len = 0;
    unsigned char *b = Tcl_GetByteArrayFromObj(obj, &len);
    return [NSData dataWithBytes:b length:len];
}

static int
BleCmd(ClientData cd, Tcl_Interp *ip, int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) { Tcl_WrongNumArgs(ip, 1, objv, "subcommand ?args?"); return TCL_ERROR; }
    const char *sub = Tcl_GetString(objv[1]);

    @autoreleasepool {
    if (strcmp(sub, "scanner") == 0) {
        /* ble scanner <callback> ?uuids? -- defers until Bluetooth is poweredOn */
        gMgr.scanCallback = (objc >= 3) ? [NSString stringWithUTF8String:Tcl_GetString(objv[2])] : nil;
        if (gMgr.central.state == CBManagerStatePoweredOn) {
            [gMgr.central scanForPeripheralsWithServices:nil options:nil];
        } else {
            gMgr.pendingScan = YES;   /* started from centralManagerDidUpdateState */
        }
        Tcl_SetObjResult(ip, Tcl_NewStringObj("scanner0", -1));
        return TCL_OK;
    }
    if (strcmp(sub, "start") == 0) {
        /* ble start <scanner> -- de1app's scanning_restart calls this right
           after `ble scanner` (bluetooth.tcl:3110).  Our scanner already begins
           on creation; (re)start scanning so this is idempotent rather than an
           "unknown subcommand" error (matches the macOS ble package fix). */
        if (gMgr.central.state == CBManagerStatePoweredOn) {
            [gMgr.central scanForPeripheralsWithServices:nil options:nil];
        } else {
            gMgr.pendingScan = YES;
        }
        Tcl_SetObjResult(ip, Tcl_NewStringObj("scanner0", -1));
        return TCL_OK;
    }
    if (strcmp(sub, "powerstate") == 0) {
        const char *names[] = {"unknown","resetting","unsupported","unauthorized","poweredOff","poweredOn"};
        int st = (int)gMgr.central.state; if (st < 0 || st > 5) st = 0;
        Tcl_SetObjResult(ip, Tcl_NewStringObj(names[st], -1));
        return TCL_OK;
    }
    if (strcmp(sub, "stop") == 0) {
        [gMgr.central stopScan];
        return TCL_OK;
    }
    if (strcmp(sub, "connect") == 0) {
        /* ble connect <callback> <uuid> */
        if (objc < 4) { Tcl_WrongNumArgs(ip, 2, objv, "callback uuid"); return TCL_ERROR; }
        NSString *cbs  = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
        NSString *uuid = [NSString stringWithUTF8String:Tcl_GetString(objv[3])];
        CBPeripheral *p = gMgr.byUUID[uuid];
        if (!p) {
            NSUUID *nu = [[NSUUID alloc] initWithUUIDString:uuid];
            NSArray *got = nu ? [gMgr.central retrievePeripheralsWithIdentifiers:@[nu]] : nil;
            p = got.firstObject;
        }
        if (!p) { Tcl_SetResult(ip, (char*)"unknown peripheral", TCL_STATIC); return TCL_ERROR; }
        BLEConn *c = [BLEConn new];
        c.peripheral = p; c.callback = cbs;
        c.handle = [NSString stringWithFormat:@"ble%d", gMgr.nextHandle++];
        gMgr.conns[c.handle] = c;
        [gMgr.central connectPeripheral:p options:nil];
        Tcl_SetObjResult(ip, Tcl_NewStringObj([c.handle UTF8String], -1));
        return TCL_OK;
    }

    /* the rest take a connection handle as objv[2] */
    if (objc < 3) { Tcl_WrongNumArgs(ip, 1, objv, "subcommand conn ?args?"); return TCL_ERROR; }
    NSString *h = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
    BLEConn *c = gMgr.conns[h];
    if (!c && strcmp(sub,"expand")!=0 && strcmp(sub,"shorten")!=0 && strcmp(sub,"equal")!=0) {
        Tcl_SetResult(ip, (char*)"unknown connection handle", TCL_STATIC); return TCL_ERROR;
    }

    if (strcmp(sub, "close") == 0) {
        if (c.peripheral) { [gMgr.central cancelPeripheralConnection:c.peripheral]; }
        [gMgr.conns removeObjectForKey:h];
        return TCL_OK;
    }
    if (strcmp(sub, "info") == 0) {
        NSString *st = c.connected ? @"connected" : @"disconnected";
        NSUInteger mtu = [c.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        Tcl_SetObjResult(ip, Tcl_NewStringObj([[NSString stringWithFormat:
            @"state %@ mtu %lu", st, (unsigned long)(mtu+3)] UTF8String], -1));
        return TCL_OK;
    }
    if (strcmp(sub, "mtu") == 0) {
        NSUInteger mtu = [c.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        Tcl_SetObjResult(ip, Tcl_NewIntObj((int)(mtu + 3)));
        return TCL_OK;
    }
    if (strcmp(sub, "userdata") == 0) {
        if (objc >= 4) { c.userdata = [NSString stringWithUTF8String:Tcl_GetString(objv[3])]; }
        Tcl_SetObjResult(ip, Tcl_NewStringObj(c.userdata ? [c.userdata UTF8String] : "", -1));
        return TCL_OK;
    }
    if (strcmp(sub, "callback") == 0) {
        if (objc >= 4) { c.callback = [NSString stringWithUTF8String:Tcl_GetString(objv[3])]; }
        Tcl_SetObjResult(ip, Tcl_NewStringObj(c.callback ? [c.callback UTF8String] : "", -1));
        return TCL_OK;
    }
    if (strcmp(sub, "write") == 0 || strcmp(sub, "read") == 0 ||
        strcmp(sub, "enable") == 0 || strcmp(sub, "disable") == 0) {
        /* ble <op> conn svc si chr ci ?data? */
        if (objc < 7) { Tcl_WrongNumArgs(ip, 2, objv, "conn svc si chr ci ?data?"); return TCL_ERROR; }
        NSString *svc = [NSString stringWithUTF8String:Tcl_GetString(objv[3])];
        NSString *chr = [NSString stringWithUTF8String:Tcl_GetString(objv[5])];
        CBCharacteristic *ch = [gMgr charOf:c service:svc chr:chr];
        if (!ch) { Tcl_SetResult(ip, (char*)"characteristic not found", TCL_STATIC); return TCL_ERROR; }
        if (strcmp(sub, "write") == 0) {
            if (objc < 8) { Tcl_SetResult(ip,(char*)"missing data",TCL_STATIC); return TCL_ERROR; }
            NSData *d = tclBytesToData(objv[7]);
            CBCharacteristicWriteType wt =
                (ch.properties & CBCharacteristicPropertyWriteWithoutResponse)
                    ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse;
            [c.peripheral writeValue:d forCharacteristic:ch type:wt];
        } else if (strcmp(sub, "read") == 0) {
            [c.peripheral readValueForCharacteristic:ch];
        } else if (strcmp(sub, "enable") == 0) {
            [c.peripheral setNotifyValue:YES forCharacteristic:ch];
        } else {
            [c.peripheral setNotifyValue:NO forCharacteristic:ch];
        }
        return TCL_OK;
    }
    } /* autoreleasepool */

    Tcl_SetObjResult(ip, Tcl_ObjPrintf("ble: unsupported subcommand \"%s\"", sub));
    return TCL_ERROR;
}

int
Ble_Init(Tcl_Interp *ip)
{
    if (Tcl_InitStubs(ip, "8.6", 0) == NULL) { return TCL_ERROR; }
    gInterp = ip;
    gTclThread = Tcl_GetCurrentThread();
    @autoreleasepool { gMgr = [BLEManager new]; }
    Tcl_CreateObjCommand(ip, "ble", BleCmd, NULL, NULL);
    return Tcl_PkgProvide(ip, "ble", "1.0");
}

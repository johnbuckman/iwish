/*
 * tclBorgios.m -- an iOS / Mac Catalyst (iWish) implementation of the subset of
 * AndroWish's "borg" command that the Decent de1app uses. Android-only concepts
 * become safe no-ops (returning sensibly) so the app runs without errors;
 * everything with an iOS equivalent is wired to the real API.
 *
 *   borg beep                         -> system sound
 *   borg brightness ?0..100?          -> get/set screen brightness (percent)
 *   borg speak <text>                 -> AVSpeechSynthesizer
 *   borg screenorientation <o>        -> no-op (managed by iWish window) -> ok
 *   borg toast <msg> ?...?            -> NSLog (no transient UI) -> ok
 *   borg checkpermission <p>          -> 1 (Catalyst apps prompt at use)
 *   borg systemui ...                 -> no-op -> ok
 *   borg spinner on|off              -> no-op -> ok
 *   borg activity ...                 -> no-op -> ok
 *   borg sensor ...                  -> no-op / empty
 *   borg osbuildinfo                  -> iOS/Catalyst build dict
 *   borg displaymetrics               -> {w h density}
 *   borg networkinfo                  -> {} (stub)
 *   borg locale                       -> current locale id
 *   borg log <tag> <msg>              -> NSLog
 *   borg notification ...             -> no-op -> ok
 *   borg locale / osbuildinfo report real values.
 */

#include <tcl.h>
#include <string.h>
#include <sys/sysctl.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
/* scalessec/Toast (ObjC) -- UIView (Toast) category: -makeToast:. */
#import "UIView+Toast.h"

static AVSpeechSynthesizer *gSpeech = nil;

/* A dedicated transparent overlay window for toasts. A toast added directly to
 * SDL's window is hidden because SDL re-raises its Metal view every frame; a
 * separate window at a higher windowLevel composites reliably above it. */
static UIWindow *gToastWindow = nil;

/* The screen brightness present when we first touched it, used to restore the
 * "default" when de1app asks for a negative percentage (AndroWish convention). */
static CGFloat gDefaultBrightness = -1.0;

/* SDL-layer toast helpers, identical to the macOS desktop build (tkBorgOSX.c).
 * Render the rounded toast offscreen on a Tk canvas with a magenta chroma-key
 * background, then hand it to `sdltk borgtoast` which captures it and blits it
 * at the SDL present layer -- always foreground, above any Tk widget.  The
 * `sdltk borgtoast` command and the present-layer blit live in the shared
 * sdl2tk sources, so they are already compiled into the iOS build. */
static const char borgTkHelpers[] =
"namespace eval ::borg::ui {}\n"
"proc ::borg::ui::_roundrect {c x1 y1 x2 y2 r args} {\n"
"  set p [list $x1 [expr {$y1+$r}] $x1 $y1 [expr {$x1+$r}] $y1 [expr {$x2-$r}] $y1 $x2 $y1 $x2 [expr {$y1+$r}] $x2 [expr {$y2-$r}] $x2 $y2 [expr {$x2-$r}] $y2 [expr {$x1+$r}] $y2 $x1 $y2 $x1 [expr {$y2-$r}]]\n"
"  return [$c create polygon $p -smooth true {*}$args]\n"
"}\n"
"proc ::borg::ui::_toast_sdl {text ms} {\n"
"  set key #ff00ff\n"
"  set sw [winfo screenwidth .]\n"
"  set sh [winfo screenheight .]\n"
"  set fs [expr {int($sh/30.0)}]; if {$fs < 14} { set fs 14 }\n"
"  catch {destroy ._borgtoast}\n"
"  set rc [catch {\n"
"    set t [toplevel ._borgtoast -bg $key -bd 0 -highlightthickness 0]\n"
"    wm overrideredirect $t 1\n"
"    catch {wm attributes $t -topmost 1}\n"
"    set c [canvas $t.c -bg $key -highlightthickness 0 -bd 0]\n"
"    pack $c\n"
"    set padx $fs; set pady [expr {int($fs*0.7)}]; set r [expr {int($fs*1.4)}]\n"
"    set maxw [expr {int($sw*0.8)}]\n"
"    set tid [$c create text $padx $pady -text $text -fill white -anchor nw -justify center -font [list Helvetica $fs] -width $maxw -tags t]\n"
"    lassign [$c bbox $tid] bx1 by1 bx2 by2\n"
"    set tw [expr {$bx2-$bx1}]; set th [expr {$by2-$by1}]\n"
"    set W [expr {$tw+2*$padx}]; set H [expr {$th+2*$pady}]\n"
"    set rid [::borg::ui::_roundrect $c 0 0 $W $H $r -fill #444444 -outline {} -tags bg]\n"
"    $c lower $rid $tid\n"
"    $c configure -width $W -height $H\n"
/* The toast's on-screen position is set by the SDL present-layer blit in
 * SdlTkGfxDrawBorgToast() (dst.y = oh - dst.h - oh*0.02, i.e. ~2% above the
 * bottom). This offscreen-capture toplevel MUST be placed at that same spot:
 * for the one frame it exists before destroy, sdl2tk composites it un-chroma-
 * keyed, so any divergence shows a stray grey rectangle at the toplevel's
 * position (the bug seen when this was moved to 0.82). Keep it matched to the
 * C blit (identical to the macOS tkBorgOSX.c geometry). */
"    wm geometry $t ${W}x${H}+[expr {($sw-$W)/2}]+[expr {$sh-$H-int($sh*0.02)}]\n"
"    update idletasks\n"
"    sdltk borgtoast $c $ms\n"
"  } emsg]\n"
"  catch {destroy ._borgtoast}\n"
"  if {$rc} { return -code error $emsg }\n"
"}\n";

static int borgTkHelpersLoaded = 0;

static void
BorgEnsureTkHelpers(Tcl_Interp *ip)
{
    if (!borgTkHelpersLoaded) {
        if (Tcl_Eval(ip, borgTkHelpers) == TCL_OK) {
            borgTkHelpersLoaded = 1;
        }
    }
}

/* Run a fire-and-forget UIKit block on the main thread. Uses dispatch_ASYNC,
 * never dispatch_sync: under undroidwish the Tcl interpreter runs OFF the main
 * thread while the main thread is busy in the SDL/Tk loop and not servicing the
 * GCD main queue, so a dispatch_sync here DEADLOCKS (the watchdog then kills the
 * app -- this was the iPad boot "crash" in borg osbuildinfo). Only use this for
 * actions with no return value; value-returning subcommands read inline. */
static void onMain(dispatch_block_t b) {
    if ([NSThread isMainThread]) { b(); }
    else { dispatch_async(dispatch_get_main_queue(), b); }
}

static int
BorgCmd(ClientData cd, Tcl_Interp *ip, int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) { Tcl_WrongNumArgs(ip, 1, objv, "subcommand ?args?"); return TCL_ERROR; }
    const char *sub = Tcl_GetString(objv[1]);

    @autoreleasepool {

    if (strcmp(sub, "beep") == 0) {
        AudioServicesPlaySystemSound(1057); /* Tink */
        return TCL_OK;
    }

    if (strcmp(sub, "brightness") == 0) {
        /* de1app (like AndroWish's borg) speaks PERCENT 0..100, not 0..255.
         * UIScreen.brightness is a 0.0..1.0 CGFloat, app-settable while
         * foreground. A negative percent means "restore default". Reads are done
         * inline (UIScreen is safe to read off-main); the SET is dispatched async
         * to the main thread so it never blocks the Tcl thread. */
        if (gDefaultBrightness < 0) gDefaultBrightness = [UIScreen mainScreen].brightness;
        if (objc >= 3) {
            int v; if (Tcl_GetIntFromObj(ip, objv[2], &v) != TCL_OK) return TCL_ERROR;
            CGFloat b;
            if (v < 0) {
                b = gDefaultBrightness;
            } else {
                b = v / 100.0;
                if (b > 1) b = 1;
                if (b < 0) b = 0;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ [UIScreen mainScreen].brightness = b; });
            return TCL_OK;
        }
        Tcl_SetObjResult(ip, Tcl_NewIntObj((int)([UIScreen mainScreen].brightness * 100 + 0.5)));
        return TCL_OK;
    }

    if (strcmp(sub, "speak") == 0) {
        if (objc < 3) return TCL_OK;
        NSString *txt = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
        onMain(^{
            if (!gSpeech) { gSpeech = [AVSpeechSynthesizer new]; }
            AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:txt];
            [gSpeech speakUtterance:u];
        });
        return TCL_OK;
    }

    if (strcmp(sub, "checkpermission") == 0) {
        /* Catalyst prompts on first real use; report "granted" so app proceeds. */
        Tcl_SetObjResult(ip, Tcl_NewIntObj(1));
        return TCL_OK;
    }

    if (strcmp(sub, "openurl") == 0) {
        /* Open a URL in the system browser (Safari). de1app's web_browser uses
         * this on iWish, where `exec open`/Android intents are unavailable. */
        if (objc < 3) { Tcl_WrongNumArgs(ip, 2, objv, "url"); return TCL_ERROR; }
        NSString *u = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
        onMain(^{
            NSURL *url = [NSURL URLWithString:u];
            if (url) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
#else
                [[UIApplication sharedApplication] openURL:url];   /* iOS 9 */
#endif
            }
        });
        return TCL_OK;
    }

    if (strcmp(sub, "platform") == 0) {
        /* Distinguish the actual run target so Tcl can tell real iOS (iPad /
         * iOS simulator) apart from the Mac Catalyst build. Compile-time, since
         * a separate dylib is built per target. */
#if TARGET_OS_MACCATALYST
        Tcl_SetObjResult(ip, Tcl_NewStringObj("maccatalyst", -1));
#elif TARGET_OS_SIMULATOR
        Tcl_SetObjResult(ip, Tcl_NewStringObj("iossimulator", -1));
#else
        Tcl_SetObjResult(ip, Tcl_NewStringObj("ios", -1));
#endif
        return TCL_OK;
    }

    if (strcmp(sub, "osbuildinfo") == 0) {
        /* Read inline (UIDevice is safe off-main); do NOT dispatch_sync -- that
         * deadlocks the Tcl thread during boot. */
        NSString *rel = [UIDevice currentDevice].systemVersion;

        /* Real hardware model so callers can tell iOS (iPad../iPhone..) from Mac
         * Catalyst (Mac..). Compile-time per target -- one dylib is built each.
         * NB: [UIDevice model] LIES on Catalyst (returns "iPad"), so use sysctl. */
        char modbuf[256] = {0};
        size_t mlen = sizeof(modbuf);
#if TARGET_OS_MACCATALYST
        sysctlbyname("hw.model", modbuf, &mlen, NULL, 0);          /* Mac16,12 */
#elif TARGET_OS_SIMULATOR
        const char *simid = getenv("SIMULATOR_MODEL_IDENTIFIER");  /* iPad13,1 */
        if (simid) { strlcpy(modbuf, simid, sizeof(modbuf)); }
#else
        sysctlbyname("hw.machine", modbuf, &mlen, NULL, 0);        /* iPad13,1 */
#endif
        NSString *model = [NSString stringWithUTF8String:
                           (modbuf[0] ? modbuf : "Apple")];

        /* product = the friendly Apple product name, derived from the model. */
        NSString *product;
        if ([model hasPrefix:@"iPad"])        product = @"iPad";
        else if ([model hasPrefix:@"iPhone"]) product = @"iPhone";
        else if ([model hasPrefix:@"iPod"])   product = @"iPod";
        else                                  product = @"Mac";

        /* Fill the standard (Android-shaped) osbuildinfo keys with real Apple
         * values. de1app reads: manufacturer "Apple"; product the friendly name
         * (iPad/iPhone/iPod/Mac); model the real id (iPad14,3 -> iOS, Mac.. ->
         * Catalyst). Platform detection uses manufacturer + model. */
#if defined(__arm64__)
        NSString *cpuAbi = @"arm64";
#elif defined(__arm__)
        NSString *cpuAbi = @"armv7";
#elif defined(__x86_64__)
        NSString *cpuAbi = @"x86_64";
#elif defined(__i386__)
        NSString *cpuAbi = @"i386";
#else
        NSString *cpuAbi = @"unknown";
#endif
        NSString *result = [NSString stringWithFormat:
            @"manufacturer Apple brand Apple product %@ "
             "model %@ device %@ board %@ hardware %@ cpu_abi %@ cpu_abi2 {} "
             "version.codename REL version.release {%@} version.sdk 0 "
             "fingerprint {Apple/%@/%@:%@/0:user/release-keys} "
             "serial unknown tags release-keys type user radio {}",
            product, model, model, model, model, cpuAbi, rel, product, model, rel];
        Tcl_SetObjResult(ip, Tcl_NewStringObj([result UTF8String], -1));
        return TCL_OK;
    }

    if (strcmp(sub, "displaymetrics") == 0) {
        CGRect r = [UIScreen mainScreen].bounds;
        CGFloat sc = [UIScreen mainScreen].scale;
        Tcl_SetObjResult(ip, Tcl_NewStringObj([[NSString stringWithFormat:
            @"%d %d %g", (int)r.size.width, (int)r.size.height, sc] UTF8String], -1));
        return TCL_OK;
    }

    if (strcmp(sub, "locale") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewStringObj([[[NSLocale currentLocale] localeIdentifier] UTF8String], -1));
        return TCL_OK;
    }

    if (strcmp(sub, "log") == 0) {
        if (objc >= 4) { NSLog(@"borg[%s]: %s", Tcl_GetString(objv[2]), Tcl_GetString(objv[3])); }
        else if (objc >= 3) { NSLog(@"borg: %s", Tcl_GetString(objv[2])); }
        return TCL_OK;
    }

    if (strcmp(sub, "toast") == 0) {
        /* Same SDL-layer rounded toast as the macOS desktop build: render the
         * toast offscreen on a Tk canvas, capture it (`sdltk borgtoast`), and
         * blit it at the SDL present layer so it is always foreground.  de1app
         * calls `borg toast <msg> ?long? ?html?`.  Runs on the Tcl thread (no
         * dispatch); the present-layer blit handles cross-thread compositing.
         * Falls back to the native UIKit (scalessec) toast if the SDL path
         * errors, so a toast is never lost. */
        if (objc >= 3) {
            int lng = 0;
            if (objc >= 4) { (void) Tcl_GetBooleanFromObj(NULL, objv[3], &lng); }
            BorgEnsureTkHelpers(ip);
            Tcl_Obj *cmd = Tcl_NewListObj(0, NULL);
            Tcl_ListObjAppendElement(NULL, cmd,
                Tcl_NewStringObj("::borg::ui::_toast_sdl", -1));
            Tcl_ListObjAppendElement(NULL, cmd, objv[2]);
            Tcl_ListObjAppendElement(NULL, cmd, Tcl_NewIntObj(lng ? 3500 : 2000));
            Tcl_IncrRefCount(cmd);
            int rc = Tcl_EvalObjEx(ip, cmd, TCL_EVAL_DIRECT);
            Tcl_DecrRefCount(cmd);
            Tcl_ResetResult(ip);
            if (rc != TCL_OK) {
                /* fallback: native toast via scalessec/Toast (UIView+Toast).
                 * Dispatch async to the main thread (never sync -- Tcl runs
                 * off-main and a sync hop would deadlock the SDL/Tk loop). */
                NSString *m = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
                if (m) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        /* lazily create a transparent, non-interactive overlay
                         * window above SDL's so the toast composites on screen */
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
                        /* find the foreground window scene (iOS 13+) */
                        UIWindowScene *ws = nil;
                        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
                            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                            ws = (UIWindowScene *)sc;
                            if (sc.activationState == UISceneActivationStateForegroundActive) break;
                        }
                        if (!ws) return;
                        if (gToastWindow == nil) {
                            gToastWindow = [[UIWindow alloc] initWithWindowScene:ws];
                            gToastWindow.windowLevel = UIWindowLevelAlert + 1;
                            gToastWindow.backgroundColor = [UIColor clearColor];
                            gToastWindow.userInteractionEnabled = NO;
                            gToastWindow.rootViewController = [UIViewController new];
                            gToastWindow.hidden = NO;   /* show without becoming key (SDL keeps key) */
                        }
                        gToastWindow.frame = ws.coordinateSpace.bounds;
#else
                        /* iOS 9: no UIScene; overlay window from the main screen bounds */
                        if (gToastWindow == nil) {
                            gToastWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                            gToastWindow.windowLevel = UIWindowLevelAlert + 1;
                            gToastWindow.backgroundColor = [UIColor clearColor];
                            gToastWindow.userInteractionEnabled = NO;
                            gToastWindow.rootViewController = [UIViewController new];
                            gToastWindow.hidden = NO;
                        }
                        gToastWindow.frame = [UIScreen mainScreen].bounds;
#endif
                        gToastWindow.rootViewController.view.frame = gToastWindow.bounds;
                        [gToastWindow.rootViewController.view makeToast:m];
                    });
                }
            }
        }
        return TCL_OK;
    }

    /* ---- ported from the macOS borg (tkBorgOSX.c): native iOS impls ---- */

    if (strcmp(sub, "vibrate") == 0) {              /* duration arg ignored on iOS */
        onMain(^{ AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); });
        return TCL_OK;
    }

    if (strcmp(sub, "stopspeak") == 0 || strcmp(sub, "endspeak") == 0) {
        onMain(^{ if (gSpeech) { [gSpeech stopSpeakingAtBoundary:AVSpeechBoundaryImmediate]; } });
        return TCL_OK;
    }

    if (strcmp(sub, "isspeaking") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewIntObj((gSpeech && gSpeech.isSpeaking) ? 1 : 0));
        return TCL_OK;
    }

    if (strcmp(sub, "trace") == 0) {                /* borg trace message script */
        if (objc != 4) { Tcl_WrongNumArgs(ip, 2, objv, "message script"); return TCL_ERROR; }
        return Tcl_EvalObjEx(ip, objv[3], 0);
    }

    if (strcmp(sub, "keyboardinfo") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewStringObj("keyboard qwerty hidden 1 hardhidden 1", -1));
        return TCL_OK;
    }

    if (strcmp(sub, "tetherinfo") == 0) {
        Tcl_SetObjResult(ip, Tcl_NewStringObj("active {} available {} error {}", -1));
        return TCL_OK;
    }

    if (strcmp(sub, "usbpermission") == 0) {        /* no user USB on iOS -> granted */
        Tcl_SetObjResult(ip, Tcl_NewIntObj(1));
        return TCL_OK;
    }

    if (strcmp(sub, "systemproperties") == 0) {     /* borg systemproperties ?name? */
        if (objc >= 3) {
            char buf[1024]; size_t n = sizeof(buf);
            if (sysctlbyname(Tcl_GetString(objv[2]), buf, &n, NULL, 0) == 0) {
                Tcl_SetObjResult(ip, Tcl_NewStringObj(buf, -1));
            }
        } else {
            char buf[256]; size_t n;
            Tcl_Obj *l = Tcl_NewListObj(0, NULL);
            const char *names[] = { "kern.ostype", "kern.osrelease",
                                    "kern.osproductversion", "hw.machine", NULL };
            for (int i = 0; names[i]; i++) {
                n = sizeof(buf);
                if (sysctlbyname(names[i], buf, &n, NULL, 0) == 0) {
                    Tcl_ListObjAppendElement(NULL, l, Tcl_NewStringObj(names[i], -1));
                    Tcl_ListObjAppendElement(NULL, l, Tcl_NewStringObj(buf, -1));
                }
            }
            Tcl_SetObjResult(ip, l);
        }
        return TCL_OK;
    }

    if (strcmp(sub, "osenvironment") == 0) {        /* borg osenvironment op */
        if (objc < 3) return TCL_OK;
        const char *o = Tcl_GetString(objv[2]);
        NSString *home = NSHomeDirectory();
        NSString *docs = [home stringByAppendingPathComponent:@"Documents"];
        NSString *res = @"";
        if (!strcmp(o, "datadir") || !strcmp(o, "externalstoragedir") ||
            !strcmp(o, "externalstoragepublicdir")) res = docs;
        else if (!strcmp(o, "downloadcachedir")) res = [home stringByAppendingPathComponent:@"Library/Caches"];
        else if (!strcmp(o, "externalstoragestate")) res = @"mounted";
        else if (!strcmp(o, "rootdir")) res = @"/";
        else if (!strcmp(o, "isexternalstorageemulated") ||
                 !strcmp(o, "isexternalstorageremovable")) res = @"0";
        Tcl_SetObjResult(ip, Tcl_NewStringObj([res UTF8String], -1));
        return TCL_OK;
    }

    if (strcmp(sub, "networkinfo") == 0) {          /* wifi / none */
        struct ifaddrs *ifap = NULL; const char *r = "none";
        if (getifaddrs(&ifap) == 0) {
            for (struct ifaddrs *i = ifap; i; i = i->ifa_next) {
                if (!i->ifa_addr || i->ifa_addr->sa_family != AF_INET) continue;
                if (!(i->ifa_flags & IFF_UP) || !(i->ifa_flags & IFF_RUNNING) ||
                    (i->ifa_flags & IFF_LOOPBACK)) continue;
                r = "wifi"; break;
            }
            freeifaddrs(ifap);
        }
        Tcl_SetObjResult(ip, Tcl_NewStringObj(r, -1));
        return TCL_OK;
    }

    if (strcmp(sub, "sharedpreferences") == 0) {    /* file op ?key value? -> NSUserDefaults */
        if (objc < 4) { Tcl_WrongNumArgs(ip, 2, objv, "file op ?key value?"); return TCL_ERROR; }
        NSString *suite = [@"borg." stringByAppendingString:
            [NSString stringWithUTF8String:Tcl_GetString(objv[2])]];
        const char *op = Tcl_GetString(objv[3]);
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDictionary *cur = [ud persistentDomainForName:suite];
        NSMutableDictionary *dom = cur ? [cur mutableCopy] : [NSMutableDictionary dictionary];
        NSString *key = (objc > 4) ? [NSString stringWithUTF8String:Tcl_GetString(objv[4])] : nil;

        if (strncmp(op, "get", 3) == 0) {
            if (objc != 6) { Tcl_WrongNumArgs(ip, 2, objv, "file getX key default"); return TCL_ERROR; }
            id v = key ? dom[key] : nil;
            Tcl_SetObjResult(ip, v ? Tcl_NewStringObj([[v description] UTF8String], -1) : objv[5]);
        } else if (strncmp(op, "set", 3) == 0) {
            if (objc != 6) { Tcl_WrongNumArgs(ip, 2, objv, "file setX key value"); return TCL_ERROR; }
            dom[key] = [NSString stringWithUTF8String:Tcl_GetString(objv[5])];
            [ud setPersistentDomain:dom forName:suite];
            Tcl_SetObjResult(ip, objv[5]);
        } else if (strcmp(op, "remove") == 0) {
            if (key) { [dom removeObjectForKey:key]; [ud setPersistentDomain:dom forName:suite]; }
        } else if (strcmp(op, "clear") == 0) {
            [ud removePersistentDomainForName:suite];
        } else if (strcmp(op, "keys") == 0) {
            Tcl_Obj *l = Tcl_NewListObj(0, NULL);
            for (NSString *k in dom) {
                Tcl_ListObjAppendElement(NULL, l, Tcl_NewStringObj([k UTF8String], -1));
            }
            Tcl_SetObjResult(ip, l);
        } else if (strcmp(op, "all") == 0 || strcmp(op, "alltypes") == 0) {
            int types = (strcmp(op, "alltypes") == 0);
            Tcl_Obj *l = Tcl_NewListObj(0, NULL);
            for (NSString *k in dom) {
                Tcl_ListObjAppendElement(NULL, l, Tcl_NewStringObj([k UTF8String], -1));
                NSString *val = [dom[k] description];
                if (types) {
                    Tcl_Obj *p = Tcl_NewListObj(0, NULL);
                    Tcl_ListObjAppendElement(NULL, p, Tcl_NewStringObj("string", -1));
                    Tcl_ListObjAppendElement(NULL, p, Tcl_NewStringObj([val UTF8String], -1));
                    Tcl_ListObjAppendElement(NULL, l, p);
                } else {
                    Tcl_ListObjAppendElement(NULL, l, Tcl_NewStringObj([val UTF8String], -1));
                }
            }
            Tcl_SetObjResult(ip, l);
        }
        return TCL_OK;
    }

    if (strcmp(sub, "systemui") == 0) {
        /* On Android `borg systemui <flags>` carries the immersive/keep-awake
         * flags and de1app calls it on every page_onload (and the saver). The
         * iOS analogue of FLAG_KEEP_SCREEN_ON is UIApplication.idleTimerDisabled:
         * without it iOS runs its own Auto-Lock, dimming then locking the screen
         * on a timer -- which the user sees as the brightness "randomly" changing
         * mid-session. de1app drives its own screen saver, so keep the OS idle
         * timer disabled. Re-asserted on every call (cheap, idempotent). */
        onMain(^{ [UIApplication sharedApplication].idleTimerDisabled = YES; });
        return TCL_OK;
    }

    /* Android-only / not-applicable on iOS: accept and no-op (matches the macOS
     * borg's stubs) so the app keeps running. */
    if (strcmp(sub, "screenorientation") == 0 ||
        strcmp(sub, "spinner") == 0 || strcmp(sub, "activity") == 0 ||
        strcmp(sub, "sensor") == 0 || strcmp(sub, "notification") == 0 ||
        strcmp(sub, "shortcut") == 0 || strcmp(sub, "bluetooth") == 0 ||
        strcmp(sub, "alarm") == 0 || strcmp(sub, "broadcast") == 0 ||
        strcmp(sub, "camera") == 0 || strcmp(sub, "cancel") == 0 ||
        strcmp(sub, "content") == 0 || strcmp(sub, "location") == 0 ||
        strcmp(sub, "ndefformat") == 0 || strcmp(sub, "ndefread") == 0 ||
        strcmp(sub, "ndefwrite") == 0 || strcmp(sub, "onintent") == 0 ||
        strcmp(sub, "packageinfo") == 0 || strcmp(sub, "phoneinfo") == 0 ||
        strcmp(sub, "providerinfo") == 0 || strcmp(sub, "queryactivities") == 0 ||
        strcmp(sub, "querybroadcastreceivers") == 0 || strcmp(sub, "queryconsts") == 0 ||
        strcmp(sub, "queryfeatures") == 0 || strcmp(sub, "queryfields") == 0 ||
        strcmp(sub, "queryservices") == 0 || strcmp(sub, "sendsms") == 0 ||
        strcmp(sub, "speechrecognition") == 0 || strcmp(sub, "usbdevices") == 0 ||
        strcmp(sub, "withdraw") == 0) {
        return TCL_OK;
    }

    } /* autoreleasepool */

    /* Unknown subcommands: no-op rather than error, to maximise app compatibility. */
    return TCL_OK;
}

int
Borg_Init(Tcl_Interp *ip)
{
    if (Tcl_InitStubs(ip, "8.6", 0) == NULL) { return TCL_ERROR; }
    Tcl_CreateObjCommand(ip, "borg", BorgCmd, NULL, NULL);
    /* Keep the screen awake while the app is running. de1app calls `borg systemui`
     * on Android but may be gated on iOS, so set the OS idle timer disabled once
     * when borg loads. The SDL app delegate sets this even earlier; this is a
     * redundant, cheap fallback for interpreters that load borg later. */
    onMain(^{ [UIApplication sharedApplication].idleTimerDisabled = YES; });
    return Tcl_PkgProvide(ip, "borg", "1.0");
}

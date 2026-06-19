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
#include <sys/sysctl.h>
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
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
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
        NSString *result = [NSString stringWithFormat:
            @"manufacturer Apple brand Apple product %@ "
             "model %@ device %@ board %@ hardware %@ cpu_abi arm64 cpu_abi2 {} "
             "version.codename REL version.release {%@} version.sdk 0 "
             "fingerprint {Apple/%@/%@:%@/0:user/release-keys} "
             "serial unknown tags release-keys type user radio {}",
            product, model, model, model, model, rel, product, model, rel];
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
        /* Native toast via scalessec/Toast (UIView+Toast). de1app calls
         * `borg toast <msg> ?duration? ?html?`; we just show the message text.
         * Dispatch async to the main thread (never sync -- Tcl runs off-main and
         * a sync hop would deadlock the SDL/Tk loop). */
        if (objc >= 3) {
            NSString *m = [NSString stringWithUTF8String:Tcl_GetString(objv[2])];
            if (m) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    /* find the foreground window scene */
                    UIWindowScene *ws = nil;
                    for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
                        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                        ws = (UIWindowScene *)sc;
                        if (sc.activationState == UISceneActivationStateForegroundActive) break;
                    }
                    if (!ws) return;
                    /* lazily create a transparent, non-interactive overlay window
                     * above SDL's so the toast actually composites on screen */
                    if (gToastWindow == nil) {
                        gToastWindow = [[UIWindow alloc] initWithWindowScene:ws];
                        gToastWindow.windowLevel = UIWindowLevelAlert + 1;
                        gToastWindow.backgroundColor = [UIColor clearColor];
                        gToastWindow.userInteractionEnabled = NO;
                        gToastWindow.rootViewController = [UIViewController new];
                        gToastWindow.hidden = NO;   /* show without becoming key (SDL keeps key) */
                    }
                    gToastWindow.frame = ws.coordinateSpace.bounds;
                    gToastWindow.rootViewController.view.frame = gToastWindow.bounds;
                    [gToastWindow.rootViewController.view makeToast:m];
                });
            }
        }
        return TCL_OK;
    }

    /* Android-only concepts: accept and no-op so the app keeps running. */
    if (strcmp(sub, "screenorientation") == 0 || strcmp(sub, "systemui") == 0 ||
        strcmp(sub, "spinner") == 0 || strcmp(sub, "activity") == 0 ||
        strcmp(sub, "sensor") == 0 || strcmp(sub, "notification") == 0 ||
        strcmp(sub, "shortcut") == 0 || strcmp(sub, "networkinfo") == 0 ||
        strcmp(sub, "bluetooth") == 0) {
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
    return Tcl_PkgProvide(ip, "borg", "1.0");
}

/*
 * hardexit.c -- a tiny Tcl loadable command, `hardexit ?code?`, that calls
 * _exit(code) immediately.
 *
 * On iOS, Tcl's normal `exit` (which runs Tcl_Finalize) hangs and leaves a
 * white window when called from de1app's Settings "app exit" path. _exit()
 * terminates the process at once, cleanly. de1app's utils.tcl `ios_install_hardexit`
 * loads this dylib and routes `exit` through `hardexit` on iWish.
 *
 * Build (arm64 iOS device):
 *   SDK=$(xcrun --sdk iphoneos --show-sdk-path)
 *   clang -dynamiclib -fPIC -DUSE_TCL_STUBS=1 \
 *     -arch arm64 -target arm64-apple-ios15.0 -miphoneos-version-min=15.0 -isysroot "$SDK" \
 *     -I<androwish>/jni/tcl/generic -o libhardexit.dylib hardexit.c \
 *     <build>/libtclstub8.6.a -install_name libhardexit.dylib
 */
#include <tcl.h>
#include <stdlib.h>

static int HardexitObjCmd(ClientData cd, Tcl_Interp *ip, int objc, Tcl_Obj *const objv[]) {
    int code = 0;
    if (objc >= 2) {
        (void)Tcl_GetIntFromObj(ip, objv[1], &code);
    }
    _exit(code);
    return TCL_OK; /* unreachable */
}

int Hardexit_Init(Tcl_Interp *ip) {
    if (Tcl_InitStubs(ip, "8.6", 0) == NULL) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(ip, "hardexit", HardexitObjCmd, NULL, NULL);
    return Tcl_PkgProvide(ip, "hardexit", "1.0");
}

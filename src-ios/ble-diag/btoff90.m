#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdio.h>

static BOOL bget(id o, const char *sel){ return ((BOOL(*)(id,SEL))objc_msgSend)(o, sel_registerName(sel)); }
static void bset(id o, const char *sel, BOOL v){ ((void(*)(id,SEL,BOOL))objc_msgSend)(o, sel_registerName(sel), v); }
static void spin(double s){ [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:s]]; }

int main(int argc, char **argv){
  @autoreleasepool {
    void *h = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
    printf("dlopen=%p err=%s\n", h, dlerror()?dlerror():"none"); fflush(stdout);
    Class BM = NSClassFromString(@"BluetoothManager");
    printf("BluetoothManager class=%p\n", (__bridge void*)BM); fflush(stdout);
    if(!BM){ printf("NO CLASS\n"); return 2; }
    id bm = ((id(*)(id,SEL))objc_msgSend)(BM, sel_registerName("sharedInstance"));
    printf("shared=%p\n", (__bridge void*)bm); fflush(stdout);
    spin(1.5);
    printf("BEFORE powered=%d enabled=%d available=%d\n", bget(bm,"powered"), bget(bm,"enabled"), bget(bm,"available")); fflush(stdout);
    printf("setPowered:NO\n"); fflush(stdout);
    bset(bm,"setPowered:",NO);
    bset(bm,"setEnabled:",NO);
    spin(90);
    printf("MID powered=%d enabled=%d\n", bget(bm,"powered"), bget(bm,"enabled")); fflush(stdout);
    printf("setPowered:YES\n"); fflush(stdout);
    bset(bm,"setPowered:",YES);
    bset(bm,"setEnabled:",YES);
    spin(5.0);
    printf("AFTER powered=%d enabled=%d available=%d\n", bget(bm,"powered"), bget(bm,"enabled"), bget(bm,"available")); fflush(stdout);
  }
  return 0;
}

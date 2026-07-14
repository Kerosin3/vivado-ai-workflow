/* LD_PRELOAD shim: neutralize udev_enumerate_scan_devices.
 *
 * Vivado's WebTalk usage-telemetry code (HAPRWebtalkHelper::GetHostInfo,
 * triggered by launch_runs) calls into libudev to enumerate host devices
 * for a machine fingerprint. In this container that call corrupts the heap
 * (glibc aborts with "realloc(): invalid pointer" / "mremap_chunk(): invalid
 * pointer", reproduced directly under `launch_runs synth_1`) — a libudev bug
 * unrelated to the design being built.
 *
 * A plain LD_PRELOAD symbol override does NOT work here: the caller
 * (libXil_lmgr11.so, dlopen'd internally by Vivado) resolves
 * udev_enumerate_scan_devices via RTLD_DEEPBIND-style internal binding, so
 * it keeps calling the real libudev.so.1 symbol regardless of what this
 * library exports under the same name (confirmed — an override function
 * with a debug print never got invoked, even though this shim loads).
 *
 * Instead, dlopen/dlsym the *real* function to get its actual in-memory
 * address, then binary-patch its first instruction to `xor eax,eax; ret`
 * (bytes 31 C0 C3) so it's a no-op returning 0 (matches the real function's
 * "scan succeeded, nothing found" case) no matter which symbol-resolution
 * path a caller uses to reach it — this changes the code itself, not which
 * symbol table answers a lookup.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

__attribute__((constructor))
static void patch_udev_enumerate_scan_devices(void) {
    void *handle = dlopen("libudev.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (!handle) {
        fprintf(stderr, "udev_stub: dlopen libudev.so.1 failed: %s\n", dlerror());
        return;
    }

    void *fn = dlsym(handle, "udev_enumerate_scan_devices");
    if (!fn) {
        fprintf(stderr, "udev_stub: dlsym udev_enumerate_scan_devices failed: %s\n", dlerror());
        return;
    }

    long pagesize = sysconf(_SC_PAGESIZE);
    uintptr_t addr = (uintptr_t)fn;
    uintptr_t page = addr & ~(uintptr_t)(pagesize - 1);

    /* cover a possible page-boundary crossing near the patch site */
    if (mprotect((void *)page, (size_t)pagesize * 2, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        fprintf(stderr, "udev_stub: mprotect RW failed: %s\n", strerror(errno));
        return;
    }

    static const unsigned char patch[] = {0x31, 0xC0, 0xC3}; /* xor eax,eax; ret */
    memcpy(fn, patch, sizeof(patch));

    mprotect((void *)page, (size_t)pagesize * 2, PROT_READ | PROT_EXEC);
}

/*
 * GoldHEN Plugin SDK - a prx hook/patch sdk for Orbis OS
 *
 * Credits
 * - OSM <https://github.com/OSM-Made>
 * - jocover <https://github.com/jocover>
 * - bucanero <https://github.com/bucanero>
 * - OpenOrbis Team <https://github.com/OpenOrbis>
 * - SiSTRo <https://github.com/SiSTR0>
 * - ItsJokerZz <https://github.com/ItsJokerZz>
 */

#include "GoldHEN/Common.h"

__asm__(".att_syntax prefix\n"
        ".globl orbis_syscall\n"
        "orbis_syscall:\n"
        "  movq $0, %rax\n"
        "  movq %rcx, %r10\n"
        "  syscall\n"
        "  jb err\n"
        "  retq\n"
        "err:\n"
        "  pushq %rax\n"
        "  callq __error\n"
        "  popq %rcx\n"
        "  movl %ecx, 0(%rax)\n"
        "  movq $0xFFFFFFFFFFFFFFFF, %rax\n"
        "  movq $0xFFFFFFFFFFFFFFFF, %rdx\n"
        "  retq\n");

int sys_dynlib_dlsym(int loadedModuleID, const char *name, void *destination) {
  return orbis_syscall(SYS_dynlib_dlsym, loadedModuleID, name, destination);
}

int sys_dynlib_load_prx(const char *name, int *idDestination) {
  return orbis_syscall(SYS_dynlib_load, name, 0, idDestination, 0);
}

int sys_dynlib_unload_prx(int *idDestination) {
  return orbis_syscall(SYS_dynlib_load, idDestination);
}

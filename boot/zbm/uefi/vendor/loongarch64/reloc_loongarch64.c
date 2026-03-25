/* reloc_loongarch64.c — 逻辑同 gnu-efi gnuefi/reloc_loongarch64.c（BSD） */
/* 自包含 ELF 常量，便于 freestanding / zig cc（无系统 elf.h） */

#include <stddef.h>
#include <stdint.h>

#define EFI_UNUSED __attribute__((unused))

typedef uint64_t UINTN;
typedef UINTN EFI_STATUS;
typedef void *EFI_HANDLE;

#define EFI_SUCCESS ((EFI_STATUS)0)
#define EFI_LOAD_ERROR ((EFI_STATUS)1)

typedef struct {
    int64_t d_tag;
    union {
        uint64_t d_val;
        uint64_t d_ptr;
    } d_un;
} Elf64_Dyn;

typedef struct {
    uint64_t r_offset;
    uint64_t r_info;
    int64_t r_addend;
} Elf64_Rela;

#define DT_NULL 0
#define DT_PLTGOT 3
#define DT_RELA 7
#define DT_RELASZ 8
#define DT_RELAENT 9

#define ELF64_R_TYPE(i) ((uint32_t)(i))

#define R_LARCH_NONE 0
#define R_LARCH_RELATIVE 3

EFI_STATUS _relocate(long ldbase, Elf64_Dyn *dyn, EFI_HANDLE image EFI_UNUSED,
                     void *systab EFI_UNUSED) {
    long relsz = 0, relent = 0;
    Elf64_Rela *rel = NULL;
    unsigned long *addr;
    int i;

    for (i = 0; dyn[i].d_tag != DT_NULL; ++i) {
        switch (dyn[i].d_tag) {
        case DT_RELA:
            rel = (Elf64_Rela *)((unsigned long)dyn[i].d_un.d_ptr + (unsigned long)ldbase);
            break;
        case DT_RELASZ:
            relsz = (long)dyn[i].d_un.d_val;
            break;
        case DT_RELAENT:
            relent = (long)dyn[i].d_un.d_val;
            break;
        case DT_PLTGOT:
            addr = (unsigned long *)((unsigned long)dyn[i].d_un.d_ptr + (unsigned long)ldbase);
            (void)addr;
            break;
        default:
            break;
        }
    }

    if (!rel && relent == 0)
        return EFI_SUCCESS;
    if (!rel || relent == 0)
        return EFI_LOAD_ERROR;

    while (relsz > 0) {
        switch (ELF64_R_TYPE(rel->r_info)) {
        case R_LARCH_NONE:
            break;
        case R_LARCH_RELATIVE:
            addr = (unsigned long *)((unsigned long)ldbase + (unsigned long)rel->r_offset);
            *addr += (unsigned long)ldbase;
            break;
        default:
            break;
        }
        rel = (Elf64_Rela *)((char *)rel + (size_t)relent);
        relsz -= relent;
    }
    return EFI_SUCCESS;
}

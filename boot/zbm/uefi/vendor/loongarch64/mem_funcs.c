/* 供 ZBM EFI 链接：Zig/LLVM 仍可能在 panic、slice 等路径生成对 memcpy/memset/memmove 的 PLT 调用。
 * gnu-efi 的 _relocate 只处理 R_LARCH_RELATIVE，不处理 R_LARCH_JUMP_SLOT；若这三者为 U 符号，
 * GOT 未解析，jirl 会落到映像间隙（如 ERA≈0x1A210）触发 #INE。 */

#include <stddef.h>

void *memcpy(void *restrict dest, const void *restrict src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    for (size_t i = 0; i < n; i++)
        d[i] = s[i];
    return dest;
}

void *memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char uc = (unsigned char)c;
    for (size_t i = 0; i < n; i++)
        p[i] = uc;
    return s;
}

void *memmove(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    if (d < s || d >= s + n) {
        for (size_t i = 0; i < n; i++)
            d[i] = s[i];
    } else {
        for (size_t i = n; i > 0; i--)
            d[i - 1] = s[i - 1];
    }
    return dest;
}

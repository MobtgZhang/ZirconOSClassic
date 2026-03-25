#!/usr/bin/env bash
# 将 zig-out/bin/zbm_loongarch64.o 链接为 BOOTLOONGARCH64.EFI。
# 使用仓库内 boot/zbm/uefi/vendor/loongarch64/ 的 crt0 + reloc + lds（不依赖系统 gnu-efi 包）。
# 依赖：LoongArch 交叉 gcc（默认 loongarch64-linux-gnu-gcc）、objcopy（LLVM 或 GNU，需支持 efi-app-loongarch64）。
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

ZIG_BIN="${ZIG_OUT:-$ROOT/zig-out/bin}"
OBJ="$ZIG_BIN/zbm_loongarch64.o"
[[ -f "$OBJ" ]] || OBJ="$ROOT/zig-out/zbm_loongarch64.o"
OUT="$ZIG_BIN/BOOTLOONGARCH64.EFI"

VENDOR="$ROOT/boot/zbm/uefi/vendor/loongarch64"
CRT0_S="$VENDOR/crt0-efi-loongarch64.S"
RELOC_C="$VENDOR/reloc_loongarch64.c"
MEM_C="$VENDOR/mem_funcs.c"
LDS="$VENDOR/elf_loongarch64_efi.lds"

# 支持无版本后缀的 gcc，也支持 Debian/Ubuntu 常见的 loongarch64-linux-gnu-gcc-14 等
die() { echo "link_zbm_loongarch_efi.sh: $*" >&2; exit 1; }

if [[ -n "${LOONGARCH_CC:-}" ]]; then
  CC="$LOONGARCH_CC"
else
  CC=""
  for cand in loongarch64-linux-gnu-gcc loongarch64-linux-gnu-gcc-{14,13,12,11,10}; do
    if command -v "$cand" >/dev/null 2>&1; then
      CC="$cand"
      break
    fi
  done
fi

# 优先与 gcc 同系列的 objcopy（含 -14 后缀），否则 llvm-objcopy
OBJCOPY="${LOONGARCH_OBJCOPY:-}"
if [[ -z "$OBJCOPY" ]]; then
  for cand in loongarch64-linux-gnu-objcopy loongarch64-linux-gnu-objcopy-{14,13,12,11,10}; do
    if command -v "$cand" >/dev/null 2>&1; then
      OBJCOPY="$cand"
      break
    fi
  done
fi
if [[ -z "$OBJCOPY" ]]; then
  if command -v llvm-objcopy >/dev/null 2>&1; then
    OBJCOPY=llvm-objcopy
  else
    OBJCOPY=objcopy
  fi
fi

command -v "$CC" >/dev/null 2>&1 || die "未找到 LoongArch 交叉 gcc（已尝试 loongarch64-linux-gnu-gcc 及 -14…-10 后缀）；请安装或设置 LOONGARCH_CC"
[[ -f "$OBJ" ]] || die "缺少 zbm_loongarch64.o，请先: zig build zbm-loongarch-uefi -Darch=loongarch64"
[[ -f "$CRT0_S" && -f "$RELOC_C" && -f "$LDS" ]] || die "缺少 vendor 文件于 $VENDOR"

# 可选额外 gcc 开关（默认空 = 与 Zig 默认 lp64d 一致）。crt0 会写 CSR EUEN，勿再强制 -mabi=lp64s 除非整链改软浮点。
LOONGARCH_ABI_FLAGS="${LOONGARCH_ABI_FLAGS:-}"

CRT0_O="$ZIG_BIN/crt0-efi-loongarch64.o"
RELOC_O="$ZIG_BIN/reloc_loongarch64.o"
MEM_O="$ZIG_BIN/mem_funcs_loongarch64.o"
TMP_ELF="$ZIG_BIN/zbm_loongarch64.elf.tmp"
rm -f "$CRT0_O" "$RELOC_O" "$MEM_O" "$TMP_ELF" "$OUT"

"$CC" $LOONGARCH_ABI_FLAGS -c -fno-stack-protector "$CRT0_S" -o "$CRT0_O"
"$CC" $LOONGARCH_ABI_FLAGS -c -fpic -ffreestanding -fno-stack-protector -fshort-wchar \
  "$RELOC_C" -o "$RELOC_O"
"$CC" $LOONGARCH_ABI_FLAGS -c -fpic -ffreestanding -fno-stack-protector -fshort-wchar \
  "$MEM_C" -o "$MEM_O"

"$CC" -nostdlib $LOONGARCH_ABI_FLAGS -Wl,-znocombreloc -Wl,-T"$LDS" -Wl,-shared -Wl,-Bsymbolic \
  -fno-stack-protector -fPIC -fshort-wchar \
  "$CRT0_O" "$RELOC_O" "$MEM_O" "$OBJ" \
  -o "$TMP_ELF"

if "$OBJCOPY" --version 2>/dev/null | head -1 | grep -qi llvm; then
  "$OBJCOPY" --target=efi-app-loongarch64 "$TMP_ELF" "$OUT" || die "llvm-objcopy 失败（需支持 efi-app-loongarch64）"
else
  # GNU objcopy：必须带上 .rodata（及 .rela.rodata），否则 Zig 的 UTF-16 字面量不在 PE 里，
  # 运行时 OutputString 读到无效地址，菜单整屏不显示，仅栈上 printDecimal 能打出左上角 "10"。
  "$OBJCOPY" \
    -j .text -j .sdata -j .data -j .rodata \
    -j .rela.rodata -j .rela.plt \
    -j .dynamic -j .dynsym -j .rel -j .rela -j .reloc \
    --target=efi-app-loongarch64 "$TMP_ELF" "$OUT" 2>/dev/null || \
  "$OBJCOPY" -O efi-app-loongarch64 "$TMP_ELF" "$OUT" || die "objcopy 失败；可安装 llvm-objcopy 并设置 LOONGARCH_OBJCOPY"
fi

cp -f "$TMP_ELF" "$ZIG_BIN/zbm_la_debug.elf" 2>/dev/null || true
rm -f "$TMP_ELF"
echo "Wrote $OUT"

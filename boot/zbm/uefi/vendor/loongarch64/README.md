# LoongArch64 UEFI 链接桩（gnu-efi 精简）

来源：[rhboot/gnu-efi](https://github.com/rhboot/gnu-efi)（BSD/GPL 双许可，与上游文件头一致）。

- `crt0-efi-loongarch64.S` — 相对上游：`bl _entry` → **`bl efi_main`**；并在调用 `efi_main` 前 **`csrwr` 写 CSR EUEN (0x2)** 打开 FPU/LSX/LASX，避免固件以 EUEN=0 进入时在应用内触发 **#INE**。
- `elf_loongarch64_efi.lds` - 未改。
- `reloc_loongarch64.c` - 自包含 ELF 类型定义（`stdint.h`），无 `efi.h` / `efilib.h`。

链接阶段需要 **`loongarch64-linux-gnu-gcc`**（或带版本后缀如 **`loongarch64-linux-gnu-gcc-14`**；`link_zbm_loongarch_efi.sh` 会自动探测），亦可设置 **`LOONGARCH_CC`** / **`LOONGARCH_OBJCOPY`**。（推荐 `llvm-objcopy` 或 `loongarch64-linux-gnu-objcopy`，需支持 `efi-app-loongarch64`）。**不必**安装发行版 `gnu-efi` 包。

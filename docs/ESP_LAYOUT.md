# ESP 目录布局（64 位 UEFI）

用于在 FAT 格式的 EFI 系统分区上安装 ZirconOS Classic 引导产物。

## 推荐结构

```text
EFI/
  Boot/
    BOOTX64.EFI           ← 将 zig-out/bin/zbmfw.efi 复制为此名（x86_64）
    BOOTAA64.EFI          ← AArch64：由 zbmfw.efi 重命名
    BOOTLOONGARCH64.EFI   ← LoongArch64：`make loongarch-efi`（vendor crt0/reloc/lds + 交叉 gcc）
boot/
  kernel.elf         ← zig-out/bin/kernel（或安装前缀下的 kernel）
  BCD                ← 可选；ZBM 可读取 BCD 默认值（见 boot/zbm）
```

## 构建产物路径

默认 `zig build` 会安装：

- `zig-out/bin/kernel` — ntoskrnl ELF
- `zig-out/bin/zbmfw.efi` — UEFI ZBM（x86_64 / AArch64，`make run` 非 LoongArch 时选用）

LoongArch64：`zig build zbm-loongarch-uefi` 安装 `zbm_loongarch64.o`；再 `make loongarch-efi` 用仓库内 `boot/zbm/uefi/vendor/loongarch64/` 与交叉工具链生成 `BOOTLOONGARCH64.EFI`。

将引导程序复制到 ESP 上固件期望的名称（x86_64：`EFI/Boot/BOOTX64.EFI`；LoongArch：`EFI/Boot/BOOTLOONGARCH64.EFI`）。

## 与 ZBM 的约定

- 内核路径：`\boot\kernel.elf`（UEFI 文本菜单与加载逻辑见 `boot/zbm/uefi/main.zig` 中的 `KERNEL_PATH`）。
- 引导契约（Multiboot2 信息块、寄存器约定）：[`BOOT_ABI.md`](BOOT_ABI.md)。

## QEMU / 固件

推荐直接使用 **`make run`**（或 `make`，默认即 `run`）：Makefile 会组装 FAT ESP 并调用 `scripts/qemu_run.sh`，固件默认从 [EDK2 Nightly](https://retrage.github.io/edk2-nightly/) 获取（见 `firmware/edk2-nightly/README.md`）。

手动跑 QEMU 时，可使用发行版 OVMF，例如：

- `/usr/share/OVMF/OVMF_CODE.fd`
- `/usr/share/edk2-ovmf/x64/OVMF_CODE.fd`

将上述 ESP 树挂载为 FAT 镜像或 `-drive file=fat:rw:path/to/esp-root,...` 供 QEMU 使用。

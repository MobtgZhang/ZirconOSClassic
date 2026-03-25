# ZirconOS Classic

用 **Zig** 实现的 **NT 5.0（Windows 2000 时代）风格** 操作系统线路，参考 [ZirconOS](https://github.com/MobtgZhang/ZirconOS) 的内核与引导设计。内核源码位于根目录 **`src/`**（与上游仓库布局一致）。

## 目标特性

- **架构**：x86-64、AArch64、LoongArch64、RISC-V 64、MIPS64el（内核 ELF）。
- **引导**：仅 **ZirconOS Boot Manager（ZBM）** — UEFI 应用 + BIOS **MBR/VBR/stage2**；**不使用 GRUB**。
- **风格**：ZBM 文本菜单与字符串面向 **Windows 2000 / NT 5.0** 启动体验（见 `boot/zbm/uefi/main.zig`）。
- **开发流程**：见 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)。

## 构建

需要 **Zig ≥ 0.15.2**。持久化构建选项请编辑根目录 **`build.conf`**（风格对齐 [ZirconOS `build.conf`](https://github.com/MobtgZhang/ZirconOS/blob/main/build.conf)）。

```bash
zig build                    # 默认 x86_64：kernel + zbm + uefi
zig build -Darch=aarch64 kernel
zig build -Darch=riscv64 kernel
zig build -Darch=loongarch64 kernel
zig build -Darch=mips64el kernel

make                         # 默认 = make run：构建后 QEMU UEFI 启动（见 build.conf）
make build                   # 仅 zig build，不启动虚拟机
make clean                   # 删除 zig-out 与 .zig-cache
```

`make run` 的固件：x86_64 / AArch64 使用 [EDK2 Nightly](https://retrage.github.io/edk2-nightly/)（`firmware/edk2-nightly/`）；**LoongArch64** 使用龙芯 [LoongArchVirtMachine](https://github.com/loongson/Firmware/tree/main/LoongArchVirtMachine) 的 `QEMU_EFI.fd` / `QEMU_VARS.fd`（`firmware/loongarch-virt/`，`qemu_run.sh` 用 **`-bios`** 启动，与 `virt` 机型一致）。可事先 `make fetch-edk2`。

产物（默认前缀 `zig-out/bin/`）：`kernel`（ELF）、`zbm` 静态库（x86 BIOS）、x86/AArch64 UEFI 为 `zbmfw.efi`；LoongArch64 UEFI 需额外 `make loongarch-efi` 生成 `BOOTLOONGARCH64.EFI`（需 **loongarch64-linux-gnu-gcc** 与 **objcopy**；crt0/reloc/lds 已内置在 `boot/zbm/uefi/vendor/loongarch64/`，**无需**系统 gnu-efi 包）。

```bash
make run ARCH=loongarch64    # 构建 loongarch 内核 + ZBM EFI 并在 QEMU 中启动（需 qemu-system-loongarch64）
```

## 仓库布局（对齐 ZirconOS `src/`）

```
├── src/
│   ├── main.zig              # 内核入口
│   ├── config/               # 嵌入默认 *.conf + config.zig
│   ├── arch/                 # x86_64, aarch64, riscv64, loongarch64, mips64el
│   ├── hal/                  # 硬件抽象（串口、帧缓冲等）
│   ├── drivers/video/        # 显示栈占位
│   ├── ke/ mm/ ob/ ps/ se/   # NT 执行体、内存、对象、进程、安全（桩）
│   ├── io/ lpc/ fs/ loader/  # I/O、LPC、文件系统、加载器（桩）
│   ├── rtl/                  # klog
│   ├── libs/                 # ntdll / kernel32 桩
│   ├── servers/              # 进程服务、SMSS 桩
│   ├── subsystems/win32/     # ntuser / ntgdi、x86_early（GRE）
│   └── classic/              # Windows 2000 Classic 配色常量
├── boot/zbm/                 # ZBM
├── link/                     # 链接脚本
└── docs/
```

## 与上游 ZirconOS 的关系

子目录与职责与 [ZirconOS](https://github.com/MobtgZhang/ZirconOS) 一致；本仓库为 **NT 5.0 产品线** 精简实现 + 桩模块，完整功能请自上游分阶段移植。

## 许可

见 [`LICENSE`](LICENSE)。

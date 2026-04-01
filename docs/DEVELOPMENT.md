# ZirconOS Classic — 开发流程（必须遵循）

本仓库以 [ZirconOS](https://github.com/MobtgZhang/ZirconOS) 为参考，目标为 **NT 5.0（Windows 2000 时代）风格** 的混合内核与用户态体系。**不使用 GRUB**；引导仅通过自研 **ZirconOS Boot Manager（ZBM）**（UEFI 应用与 BIOS/MBR 链路）。合规与贡献约定见根目录 [`CONTRIBUTING.md`](../CONTRIBUTING.md)；内核 **ELF 与 PE 路线**见 [`KERNEL_IMAGE.md`](KERNEL_IMAGE.md)。

## 1. 阶段划分（与上游 Roadmap 对齐并收窄到 Classic）

| 阶段 | 内容 | 产出 |
|------|------|------|
| P0 | 构建系统、链接脚本、多架构 `kernel.elf` 可链接 | `zig build` |
| P1 | ZBM：UEFI（x86_64 / AArch64）、LoongArch（`.o` + 内置 gnu-efi 桩链出 `BOOTLOONGARCH64.EFI`）、BIOS MBR/VBR/stage2 汇编 | `zig build zbm` / `uefi` / `make loongarch-efi` |
| P2 | 内核早期：串口、中断/陷阱桩、与 ZBM 约定（Multiboot2 / UEFI vector） | 可启动最小 ntoskrnl |
| P3 | 内存管理、对象管理、进程/线程（NT 命名：`ke/`、`mm/`、`ob/`、`ps/`） | 与上游 ZirconOS 目录语义一致（当前为桩） |
| P4 | LPC、I/O、驱动模型；FAT/NTFS 与 **Zircon64** 子系统（按需自上游移植） | 用户态与 shell |
| P5 | **Zircon64 / GRE 骨架**：HAL 线性帧缓冲、GRE 子集（`ntgdi`）、桌面占位（`ntuser`）；x86_64 Multiboot2 帧缓冲标签 | `src/subsystems/zircon64/`、`src/hal/x86_64/framebuffer.zig` |

**规则**：每一阶段合并前须满足：对应架构下 `zig build -Darch=<arch> kernel` 无警告失败；若改动引导，须同步更新本文与 `README.md` 中的启动路径说明。

## 2. 日常开发命令

```bash
make                         # 默认：make run（QEMU + EDK2 Nightly，见 firmware/edk2-nightly/README.md）
make build                   # 仅 zig build
make clean                   # zig-out + .zig-cache

zig build -Darch=x86_64 kernel
zig build -Darch=aarch64 kernel
zig build -Darch=riscv64 kernel
zig build -Darch=loongarch64 kernel
zig build -Darch=mips64el kernel
zig build -Darch=x86_64 zbm
zig build -Darch=x86_64 uefi
zig build -Darch=aarch64 uefi
zig build -Darch=loongarch64 zbm-loongarch-uefi
make loongarch-efi   # 需 loongarch64-linux-gnu-gcc + objcopy；vendor 自带 crt0/reloc/lds，无需 gnu-efi 包
make run ARCH=loongarch64   # 需 qemu-system-loongarch64；自动 kernel + loongarch-efi
```

## 3. 架构与引导矩阵

| 架构 | 内核 | UEFI ZBM | BIOS/MBR ZBM |
|------|------|----------|----------------|
| x86_64 | ✓ | ✓ | ✓（`boot/zbm/bios/*.s` + 链接脚本） |
| aarch64 | ✓ | ✓ | 以 UEFI 为主 |
| riscv64 | ✓ | （riscv64 UEFI PE 受限） | 视平台而定 |
| loongarch64 | ✓ | `BOOTLOONGARCH64.EFI`（`make loongarch-efi`；Multiboot2 与 x86/AArch64 对齐） | 视平台而定 |
| mips64el | ✓ | — | — |

## 4. 代码与命名约定

- 内核产品名：**ZirconOS Classic**；版本线与 **NT 5.0** 对齐。
- 源码根目录：**`src/`**（与 [ZirconOS](https://github.com/MobtgZhang/ZirconOS) 一致），勿再使用已废弃的 `kernel/src/`。
- 从上游同步大块代码时，在提交说明中注明对应 ZirconOS 提交或目录。

## 5. Zircon64 图形子系统与渲染路径（P5）

- **x86_64 + Multiboot2**：`src/arch/x86_64/boot.zig` 解析帧缓冲；`src/subsystems/zircon64/gre_early.zig` 初始化帧缓冲并调用 `desktop_session.bootstrapFromBootInfo()`（内部 `ntuser` + WM_PAINT 泵）。
- **交互循环**：`enable_idt` 时 `kernel_main` 在 P5 后进入 `desktop_session.runSessionLoop()`（HLT/WFI + 消息泵）；IRQ0 驱动调度器与任务栏时钟刷新。
- **启动链**：`servers/smss.zig` 步骤化日志 → `servers/csrss.zig` 经 `lpc/mod.zig` ApiPort 握手桩 → GRE。
- **桌面对象**：`subsystems/zircon64/winsta.zig`（会话站 Default + OB 句柄）、`ntuser.zig`（HWND、按窗口消息队列）、`gdi.zig`（主表面 FillRect）、`ntgdi.zig`（经典风格任务栏/开始菜单/托盘时钟占位）。
- **Syscall**：`arch/x86_64/syscall.zig` 分发 `zircon64_syscalls.zig`（0x1000..0x1010）；`libs/ntdll.zig` / `zircon64_user_api.zig` / `zircon64_gdi_api.zig` 为编号与文档桩。
- **日志**：`src/rtl/klog.zig`。
- **配色 / 主题**：`src/classic/colors.zig` 使用 **0xRRGGBB**（与 `hal/fb_console.packPixel32` 一致），桌面背景应对齐 Win2000 青绿 **#008080**；活动标题栏为左 `#000080` → 右 `#1084D0` 水平渐变（`gdi.fillRectGradientH`）。Multiboot2 `desktop=` 经 `theme.zig` 生效，缺省 `ntclassic`。
- **PS/2 鼠标（x86_64）**：`hal/x86_64/ps2_mouse.zig` 在 `enable_idt` 路径下于开中断前 `init()`，解除 **IRQ12**（及 **IRQ1** 键盘）；`desktop_session` 中处理移动与左键沿，命中逻辑见 `shell_layout.zig` / `shell_click.zig`。
- **软件光标**：`cursor_overlay.zig` 在帧缓冲上保存/恢复光标矩形后绘制箭头（`classic/resources/mod.zig`）。
- **嵌入式资源**：原创 8×8 ARGB 图标经 GRE 放大为 32×32；说明目录 [`resources/classic/README.md`](../resources/classic/README.md)，数据在 `src/classic/resources/`。
- **加载器**：`loader/mod.zig` 提供 `tryLoadEmbeddedShellElf`（ELF64 校验；映射执行后续实现）。
- **后续**：自上游移植完整 Ring3 Zircon64 用户 API / Explorer 与真实 CSRSS 进程。

## 5.1 多架构说明（Zircon64 GRE）

- **完整 GRE 路径**：当前为 **x86_64、AArch64**（Multiboot2 帧缓冲 + `gre_early` + 可选桌面会话循环）。
- **LoongArch64**：UEFI 路径与 x86/AArch64 相同 Multiboot2 信息块 + `.uefi_vector`；`kernel_main` 走 `startMultibootKernel`（帧分配器等）。完整 GRE / 桌面会话循环仍为 **x86_64、AArch64**。
- **RISC-V / MIPS**：内核可构建；与 Zircon64 GRE 帧缓冲启动链未完全打通时行为见 `docs/NT5_REACTOS_MATRIX.md`。

## 5.2 验收建议（QEMU 图形桌面）

- 使用带 GOP/线性帧缓冲的启动路径；默认 QEMU PS/2 鼠标即可（`-device virtio-mouse` 等若替换需自行对齐驱动）。
- 目视：桌面为 **青绿 #008080**（非黄绿）；任务栏灰 **#C0C0C0**；可拖动鼠标、左键点 **Start** 弹出菜单、点 **Exit** 关闭欢迎窗、点桌面图标串口有 `SHELL: desktop icon click` 日志。

## 6. 参考

- 上游：<https://github.com/MobtgZhang/ZirconOS>
- 参考书目：[`REFERENCES.md`](REFERENCES.md)

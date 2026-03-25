# NT 5.0 / Windows 2000 开发与图形子系统参考

阅读顺序建议：先官方白皮书与子系统概述，再对照 ReactOS 目录，最后深入 *Windows Internals*。

## 官方与存档（Microsoft Learn）

- [MS Windows NT Kernel-mode User and GDI White Paper](https://learn.microsoft.com/en-us/previous-versions/cc750820(v=technet.10)) — 内核态 USER/GDI 迁移背景（NT 4+）。
- [Lesson 5 - Windows NT Subsystems](https://learn.microsoft.com/en-us/previous-versions/cc767884(v=technet.10)) — 环境子系统与 Executive。
- [Windows 2000 Server Resource Kit](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/cc984339(v=msdn.10)) — 组件与运维视角。
- [Windows 2000 Startup and Logon Traffic Analysis](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/bb742590(v=technet.10)) — 启动/登录链。

## Multiboot2（x86 引导信息）

- [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html) — 帧缓冲等标签布局。

## 开源对照（模块树）

- [ReactOS Wiki: Win32k.sys](https://reactos.org/wiki/Win32k.sys)
- [Techwiki: Win32k](https://reactos.org/wiki/Techwiki:Win32k)
- [ReactOS Architecture](https://www.reactos.org/architecture)

## 内核/驱动社区

- [OSR Online](https://community.osr.com/) — Windows 内核与驱动讨论。

## 书籍

- Mark Russinovich 等，*Windows Internals* — 以目录中 **Win32k、图形、内存管理** 相关章节为准（版本更新频繁，不固定页码）。

## 本仓库引导与对照文档

- [`BOOT_ABI.md`](BOOT_ABI.md) — ZBM ↔ 内核 Multiboot2 契约。
- [`NT5_REACTOS_MATRIX.md`](NT5_REACTOS_MATRIX.md) — NT 5.0 模块与 ReactOS 路径对照。
- [`ESP_LAYOUT.md`](ESP_LAYOUT.md) — UEFI ESP 目录布局。

## 本仓库上游

- [ZirconOS](https://github.com/MobtgZhang/ZirconOS) — 完整内核、Win32 子系统与桌面主题，可作为移植源。

# NT 5.0 模块 ↔ ReactOS / 本仓库路径对照

用于避免实现语义漂移；详细 API 以 Windows 2000 时代文档与 *Windows Internals* 为准。

| NT 5.x 组件 | 典型职责 | ReactOS 参考树（概念） | ZirconOS Classic `src/` |
|-------------|----------|-------------------------|-------------------------|
| ntoskrnl Executive | 对象、进程、线程、同步、调度 | `ntoskrnl/` | `ke/`, `mm/`, `ob/`, `ps/`, `se/` |
| I/O Manager | 设备栈、IRP | `ntoskrnl/io/` | `io/`, `drivers/` |
| LPC | 子系统端口、本地消息 | `ntoskrnl/lpc/` | `lpc/` |
| 内存管理 | 页帧、池、VAD（远期） | `ntoskrnl/mm/` | `mm/` |
| 对象管理器 | 句柄、目录、类型 | `ntoskrnl/ob/` | `ob/` |
| 安全引用监视器 | Token、访问检查 | `ntoskrnl/se/` | `se/` |
| 会话管理器 | Session 0、启动子系统 | `base/system/smss`（用户态） | `servers/smss.zig`（内核侧桩/编排） |
| CSRSS | Win32 子系统用户态服务 | `base/system/csrss` | `servers/csrss.zig`（桩） |
| win32k.sys | USER+GDI 内核态 | `win32ss/` | `subsystems/win32/` |
| ntdll | 原生 API | `dll/ntdll` | `libs/ntdll.zig` |
| kernel32 | Win32 基线 | `dll/win32/kernel32` | `libs/kernel32.zig` |

## 启动阶段（简）

1. **引导**：ZBM → `kernel_main`（Multiboot2 信息块）。
2. **内核早期**：HAL 串口、帧缓冲可选、`mm` 帧分配、`ke` 调度桩。
3. **SMSS 等价**：初始化会话与子系统启动顺序（当前为日志 + 桩）。
4. **CSRSS + win32k**：LPC 连接后提供窗口/消息/GDI；Shell 绘制经典桌面。

## 系统调用 / SSDT

完整 SSDT 对齐为远期项；当前在 `ntdll.zig` / `win32` 子系统中以 **子集 + 文档化偏移** 方式扩展。

## 外部文档

见 [`REFERENCES.md`](REFERENCES.md)（Microsoft Learn 存档、ReactOS Wiki、OSR）。

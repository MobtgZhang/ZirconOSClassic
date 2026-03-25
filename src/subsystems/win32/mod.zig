//! 图形桌面子系统（内核态 GRE / ntuser 早期路径）。
//! Multiboot2 帧缓冲 + GRE：`gre_early.zig`（x86_64 / aarch64 + UEFI ZBM）；`x86_early.zig` 为兼容别名。

pub const ntuser = @import("ntuser.zig");
pub const ntgdi = @import("ntgdi.zig");
pub const gdi = @import("gdi.zig");
pub const theme = @import("theme.zig");
pub const winsta = @import("winsta.zig");
pub const desktop_session = @import("desktop_session.zig");
pub const win32_syscalls = @import("win32_syscalls.zig");

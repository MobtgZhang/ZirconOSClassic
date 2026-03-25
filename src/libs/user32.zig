//! user32 薄层文档桩（GetMessage/CreateWindowEx 等远期实现）。
//! 消息与 HWND 语义见内核 `subsystems/win32/ntuser.zig`。

const ntdll = @import("ntdll.zig");

pub const HWND_DESKTOP: u32 = 1;

pub fn logSubsystemVersion() void {
    _ = ntdll.syscall.NtUserInvalidateWindow;
}

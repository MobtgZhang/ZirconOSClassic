//! Zircon64 GDI 类 API 薄层文档桩（GetDC/BitBlt 等远期经 NtGdi* syscall）。

const ntdll = @import("ntdll.zig");

pub fn logSubsystemVersion() void {
    _ = ntdll.syscall.NtGdiFillRect;
}

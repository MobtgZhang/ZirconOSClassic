//! Zircon64 用户态基线 API 桩（CreateProcess/ExitProcess 等远期实现）。

const klog = @import("../rtl/klog.zig");

pub fn initStub() void {}

pub fn logSubsystemVersion() void {
    klog.info("Zircon64 kernel API layer stub (process APIs TBD)", .{});
}

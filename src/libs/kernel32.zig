//! kernel32 桩（用户态基线 API 占位）。

const klog = @import("../rtl/klog.zig");

pub fn initStub() void {}

pub fn logSubsystemVersion() void {
    klog.info("KERNEL32: userspace base stub (CreateProcess/ExitProcess TBD)", .{});
}

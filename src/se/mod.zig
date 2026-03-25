//! Security（se）— Token、SID、访问检查（NT 5.x LSA/安全引用监视器骨架）。

const klog = @import("../rtl/klog.zig");

pub fn initExecutive() void {
    klog.info("SE: access check + token stubs (allow-all phase)", .{});
}

pub fn initStub() void {
    initExecutive();
}

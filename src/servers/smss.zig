//! Session Manager（SMSS）— 会话 0 与子系统启动顺序（内核侧编排桩）。

const klog = @import("../rtl/klog.zig");
const ntdll = @import("../libs/ntdll.zig");
const zc_kernel_api = @import("../libs/zircon64_kernel_api.zig");
const csrss_mod = @import("csrss.zig");

pub fn runBootstrapSequence() void {
    klog.info("SMSS: step 1 — Session 0 bootstrap", .{});
    klog.info("SMSS: step 2 — native baseline libraries", .{});
    ntdll.logSubsystemVersion();
    zc_kernel_api.logSubsystemVersion();
    klog.info("SMSS: step 3 — CSRSS on LPC ApiPort", .{});
    csrss_mod.bootstrapAfterSmss();
    klog.info("SMSS: step 4 — continue to desktop GRE / shell", .{});
}

pub fn initStub() void {}

//! 页错误（#PF）处理与按需分页 — 与 `arch/x86_64/isr.zig` 接线为后续项。

const klog = @import("../rtl/klog.zig");

pub fn initExecutive() void {
    klog.info("MM: page fault / demand paging handler wiring TBD", .{});
}

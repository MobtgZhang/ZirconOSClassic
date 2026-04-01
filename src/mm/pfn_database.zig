//! PFN 数据库：与 `frame.zig` 位图分配器配套的高层视图（状态枚举、未来扩展点）。

const klog = @import("../rtl/klog.zig");

pub const PageFrameState = enum(u8) {
    free = 0,
    zeroed = 1,
    standby = 2,
    active = 3,
    bad = 4,
};

pub fn initExecutive() void {
    klog.info("MM: PFN database view — backed by FrameAllocator bitmap (extended states TBD)", .{});
}

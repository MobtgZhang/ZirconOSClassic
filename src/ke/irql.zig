//! IRQL（中断请求级别）骨架，与调度器/自旋锁约定对齐 NT 风格命名。

const klog = @import("../rtl/klog.zig");

pub const IRQL = enum(u8) {
    passive_level = 0,
    apc_level = 1,
    dispatch_level = 2,
    /// 设备中断自 DIRQL 起；此处仅占位上界。
    high_level = 31,
};

var g_current: IRQL = .passive_level;

pub fn current() IRQL {
    return g_current;
}

pub fn raiseIrql(new: IRQL) IRQL {
    const old = g_current;
    g_current = new;
    return old;
}

pub fn lowerIrql(old: IRQL) void {
    g_current = old;
}

pub fn initExecutive() void {
    klog.info("KE: IRQL model stub (raise/lower TBD vs real PIC/APIC)", .{});
}

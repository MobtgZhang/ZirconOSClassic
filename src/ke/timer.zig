//! Kernel Timer Module (PIT at 100Hz)

const arch = @import("../arch.zig");
const scheduler = @import("scheduler.zig");
const klog = @import("../rtl/klog.zig");

const TIMER_HZ: u32 = 100;

var timer_initialized: bool = false;

pub fn init() void {
    if (@hasDecl(arch.impl, "initPic")) arch.impl.initPic();
    if (@hasDecl(arch.impl, "initTimer")) arch.impl.initTimer();
    if (@hasDecl(arch.impl, "unmaskIrq")) arch.impl.unmaskIrq(0);
    timer_initialized = true;
    klog.info("Phase 2: Timer PIT at %uHz, PIC initialized", .{TIMER_HZ});
}

pub fn getTicks() u64 {
    return scheduler.getTicks();
}

pub fn getHz() u32 {
    return TIMER_HZ;
}

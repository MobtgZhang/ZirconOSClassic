//! Kernel Timer Module（x86: PIT；LoongArch: CSR 定时器）

const builtin = @import("builtin");
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
    if (builtin.target.cpu.arch == .loongarch64) {
        klog.info("Phase 2: LoongArch CSR timer (target ~%uHz UI tick, virtio poll in IRQ)", .{TIMER_HZ});
    } else {
        klog.info("Phase 2: Timer PIT at %uHz, PIC initialized", .{TIMER_HZ});
    }
}

pub fn getTicks() u64 {
    return scheduler.getTicks();
}

pub fn getHz() u32 {
    return TIMER_HZ;
}

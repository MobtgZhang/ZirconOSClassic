//! LAPIC one-shot/periodic timer — 寄存器编程待接调度器；此处占位。

const klog = @import("../../rtl/klog.zig");
const lapic = @import("lapic_early.zig");

pub fn logTimerStub() void {
    const b = lapic.mmioPhysBase();
    if (b == 0) {
        klog.info("HAL LAPIC timer: skipped (no APIC base)", .{});
        return;
    }
    klog.info("HAL LAPIC timer: periodic/one-shot programming TBD (MMIO 0x%x)", .{b});
}

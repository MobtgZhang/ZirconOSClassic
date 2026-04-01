//! HPET：ACPI HPET 表解析与 MMIO 映射为后续项；当前仅占位日志。

const klog = @import("../../rtl/klog.zig");

pub fn logStub() void {
    klog.info("HAL HPET: probe not implemented — PIT/IRQ0 or LAPIC timer in use", .{});
}

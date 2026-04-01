//! Local xAPIC：通过 IA32_APIC_BASE MSR 使能，供后续时钟/ IPI 使用。

const msr = @import("msr.zig");
const klog = @import("../../rtl/klog.zig");

const APIC_BASE_ENABLE: u64 = 1 << 11;
const APIC_BASE_BSP: u64 = 1 << 8;

var g_apic_mmio_phys: u64 = 0;

pub fn mmioPhysBase() u64 {
    return g_apic_mmio_phys;
}

/// 置位 APIC Enable；记录 MMIO 物理基址（通常为 0xFEE00000）。
pub fn enableLocalApic() void {
    var v = msr.rdmsr64(msr.IA32_APIC_BASE);
    v |= APIC_BASE_ENABLE | APIC_BASE_BSP;
    msr.wrmsr64(msr.IA32_APIC_BASE, v);
    g_apic_mmio_phys = v & 0xFFFF_FFFF_FFFFF000;
    klog.info("HAL LAPIC: enabled MMIO phys base 0x%x", .{g_apic_mmio_phys});
}

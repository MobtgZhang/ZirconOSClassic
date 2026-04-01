//! PCIe ECAM（MCFG）：ACPI 表解析后在此做 MMIO 配置空间访问；当前为 API 占位。

const klog = @import("../../rtl/klog.zig");

/// 段号 + 总线/设备/功能 → 配置 dword 读（未实现时返回 0xFFFF_FFFF）。
pub fn readConfigDword(segment: u16, bus: u8, dev: u8, func: u8, offset: u8) u32 {
    _ = .{ segment, bus, dev, func, offset };
    klog.debug("PCIe ECAM: readConfigDword stub", .{});
    return 0xffff_ffff;
}

pub fn initStubFromMcfg() void {
    klog.info("PCIe ECAM: MCFG-driven ECAM base TBD (use I/O CF8/CFC or virtio for now)", .{});
}

//! ACPI RSDP 校验与日志（数据来自 `ZirconBootContext` / Multiboot2 tag）。

const std = @import("std");
const zbc = @import("../../boot/zircon_boot_context.zig");
const klog = @import("../../rtl/klog.zig");

const rsdp_sig = "RSD PTR ";

pub fn validateAndLogFromBootContext() void {
    const ctx = zbc.get() orelse {
        klog.info("HAL ACPI: no ZirconBootContext", .{});
        return;
    };
    const rp = ctx.acpi_rsdp_phys orelse {
        klog.info("HAL ACPI: no RSDP from boot loader (optional on bare metal)", .{});
        return;
    };
    const p: [*]const u8 = @ptrFromInt(rp);
    if (!std.mem.eql(u8, p[0..8], rsdp_sig)) {
        klog.err("HAL ACPI: invalid RSDP signature at phys 0x%x", .{rp});
        return;
    }
    klog.info("HAL ACPI: RSDP valid at phys 0x%x acpi_rev=%u", .{ rp, p[15] });
}

//! Intel 核显 MVP：PCI 探测、命令寄存器使能、记录 MMIO BAR。
//! 线性帧缓冲仍由 UEFI GOP → Multiboot2 tag 8 提供，由 `gre_early` 调用 `fb_console.initEx`；
//! 本模块不做 modeset（见 `intel_display_future.zig`）。

const builtin = @import("builtin");
const klog = @import("../../rtl/klog.zig");
const pci = @import("pci.zig");
const ids = @import("intel_gpu_ids.zig");

comptime {
    if (builtin.target.cpu.arch != .x86_64) {
        @compileError("intel_igpu.zig is x86_64-only");
    }
}

const VENDOR_INTEL: u16 = 0x8086;

pub const PciLoc = pci.PciLoc;

var probe_ok: bool = false;
var saved_loc: PciLoc = undefined;
var saved_bar0: usize = 0;

pub fn probed() bool {
    return probe_ok;
}

pub fn mmioBase() usize {
    return saved_bar0;
}

/// 扫描 PCI，若发现已知 iGPU 则使能并记录 BAR0（MMIO）。不初始化帧缓冲。
pub fn probeAndEnable() bool {
    if (probe_ok) return true;

    var bus: u16 = 0;
    while (bus < 256) : (bus += 1) {
        var dev: u8 = 0;
        while (dev < 32) : (dev += 1) {
            var func: u8 = 0;
            while (func < 8) : (func += 1) {
                const v0 = pci.vendorDevice(@truncate(bus), dev, func);
                const ven = @as(u16, @truncate(v0));
                if (pci.isEmptyVendor(ven)) {
                    if (func == 0) break;
                    continue;
                }
                if (ven != VENDOR_INTEL) {
                    if (func == 0) {
                        const ht = pci.read8(@truncate(bus), dev, 0, 0x0e);
                        if ((ht & 0x80) == 0) break;
                    }
                    continue;
                }

                const did = @as(u16, @truncate(v0 >> 16));
                const cr = pci.readClassRev(@truncate(bus), dev, func);
                if (cr.class_code != 0x03 or cr.subclass != 0x00) {
                    if (func == 0) {
                        const ht = pci.read8(@truncate(bus), dev, 0, 0x0e);
                        if ((ht & 0x80) == 0) break;
                    }
                    continue;
                }
                if (!ids.isKnownIgpu(did)) {
                    if (func == 0) {
                        const ht = pci.read8(@truncate(bus), dev, 0, 0x0e);
                        if ((ht & 0x80) == 0) break;
                    }
                    continue;
                }

                pci.enableMmioAndBusMaster(@truncate(bus), dev, func);
                const bar0 = pci.barMmioPhys(@truncate(bus), dev, func, 0) orelse 0;
                saved_loc = .{ .bus = @truncate(bus), .dev = dev, .func = func };
                saved_bar0 = bar0;
                probe_ok = true;

                klog.info("intel-igpu: %04x:%04x rev=%u BAR0/MMIO=0x%x (FB via UEFI GOP → gre_early)", .{
                    ven, did, cr.rev, bar0,
                });
                return true;
            }
        }
    }
    return false;
}

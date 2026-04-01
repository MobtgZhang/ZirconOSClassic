//! QEMU `loongarch64` `virt` PCI ECAM（与 `virtio_gpu.zig` / `virtio_hid.zig` 一致）。

const VIRT_PCI_CFG_BASE: usize = 0x2000_0000;

fn pciCfgAddr(bus: u8, dev: u8, func: u8, reg: usize) usize {
    return VIRT_PCI_CFG_BASE +
        (@as(usize, bus) << 20) +
        (@as(usize, dev) << 15) +
        (@as(usize, func) << 12) +
        reg;
}

pub fn read8(bus: u8, dev: u8, func: u8, reg: usize) u8 {
    return @as(*const volatile u8, @ptrFromInt(pciCfgAddr(bus, dev, func, reg))).*;
}

pub fn read32(bus: u8, dev: u8, func: u8, reg: usize) u32 {
    const a = pciCfgAddr(bus, dev, func, reg);
    var v: u32 = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        v |= @as(u32, @as(*const volatile u8, @ptrFromInt(a + i)).*) << @intCast(8 * i);
    }
    return v;
}

pub fn write32(bus: u8, dev: u8, func: u8, reg: usize, v: u32) void {
    const a = pciCfgAddr(bus, dev, func, reg);
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        @as(*volatile u8, @ptrFromInt(a + i)).* = @truncate(v >> @intCast(8 * i));
    }
}

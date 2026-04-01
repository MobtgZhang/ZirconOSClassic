//! x86_64 PCI 配置空间访问（端口 0xCF8 / 0xCFC）。
//! 适用于传统主机桥与多数 QEMU `-machine q35` 环境。

const portio = @import("portio.zig");

pub const PciLoc = struct {
    bus: u8,
    dev: u8,
    func: u8,
};

fn addrU32(bus: u8, dev: u8, func: u8, reg: u8) u32 {
    return 0x8000_0000 |
        (@as(u32, bus) << 16) |
        (@as(u32, dev) << 11) |
        (@as(u32, func) << 8) |
        @as(u32, reg & 0xfc);
}

pub fn read32(bus: u8, dev: u8, func: u8, reg: usize) u32 {
    portio.outl(0xCF8, addrU32(bus, dev, func, @truncate(reg)));
    return portio.inl(0xCFC);
}

pub fn write32(bus: u8, dev: u8, func: u8, reg: usize, v: u32) void {
    portio.outl(0xCF8, addrU32(bus, dev, func, @truncate(reg)));
    portio.outl(0xCFC, v);
}

pub fn read16(bus: u8, dev: u8, func: u8, reg: usize) u16 {
    const align_reg = reg & ~@as(usize, 3);
    const shift: u5 = @intCast((reg & 3) * 8);
    return @truncate(read32(bus, dev, func, align_reg) >> shift);
}

pub fn read8(bus: u8, dev: u8, func: u8, reg: usize) u8 {
    const align_reg = reg & ~@as(usize, 3);
    const shift: u5 = @intCast((reg & 3) * 8);
    return @truncate(read32(bus, dev, func, align_reg) >> shift);
}

pub fn write16(bus: u8, dev: u8, func: u8, reg: usize, v: u16) void {
    const align_reg = reg & ~@as(usize, 3);
    const cur = read32(bus, dev, func, align_reg);
    const shift: u5 = @intCast((reg & 3) * 8);
    const mask: u32 = @as(u32, 0xffff) << shift;
    const nv = (cur & ~mask) | (@as(u32, v) << shift);
    write32(bus, dev, func, align_reg, nv);
}

/// 返回 MMIO 物理基址；I/O BAR 或无效时返回 null。支持 64-bit BAR。
pub fn barMmioPhys(bus: u8, dev: u8, func: u8, bar_idx: u8) ?usize {
    const reg: usize = 0x10 + @as(usize, bar_idx) * 4;
    const lo = read32(bus, dev, func, reg);
    if ((lo & 1) != 0) return null;
    const typ = lo & 0x6;
    var base: usize = @as(usize, lo) & 0xFFFF_FFF0;
    if (typ == 4) {
        const hi = read32(bus, dev, func, reg + 4);
        base |= @as(usize, hi) << 32;
    }
    if (base == 0) return null;
    return base;
}

/// 置位 memory space、I/O（如需要）、bus master（virtio / DMA 显示设备常用）。
pub fn enableMmioAndBusMaster(bus: u8, dev: u8, func: u8) void {
    const cmd = read16(bus, dev, func, 0x04);
    write16(bus, dev, func, 0x04, cmd | 0x7);
}

/// 配置空间 dword @0x08：rev、prog-if、subclass、class。
pub fn readClassRev(bus: u8, dev: u8, func: u8) struct { rev: u8, prog_if: u8, subclass: u8, class_code: u8 } {
    const w = read32(bus, dev, func, 0x08);
    return .{
        .rev = @truncate(w),
        .prog_if = @truncate(w >> 8),
        .subclass = @truncate(w >> 16),
        .class_code = @truncate(w >> 24),
    };
}

pub fn vendorDevice(bus: u8, dev: u8, func: u8) u32 {
    return read32(bus, dev, func, 0);
}

/// 无效设备或空槽。
pub fn isEmptyVendor(vendor: u16) bool {
    return vendor == 0xffff;
}

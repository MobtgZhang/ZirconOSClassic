//! FAT12/16/32 引导扇区与只读遍历（NT 5.x 可安装文件系统最小子集）。

const klog = @import("../rtl/klog.zig");

pub const BootSector = extern struct {
    jmp: [3]u8,
    oem: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sector_count: u16,
    num_fats: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media: u8,
    fat_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_32: u32,
};

pub fn validateBootSector(bytes: *const [512]u8) bool {
    const sig0 = bytes[510];
    const sig1 = bytes[511];
    if (sig0 != 0x55 or sig1 != 0xAA) return false;
    const bpb: *const BootSector = @ptrCast(bytes);
    if (bpb.bytes_per_sector == 0 or (bpb.bytes_per_sector & (bpb.bytes_per_sector - 1)) != 0) return false;
    klog.info("FS: FAT BPB OK (bps=%u spc=%u)", .{ bpb.bytes_per_sector, bpb.sectors_per_cluster });
    return true;
}

pub fn initReadOnlyStubs() void {
    klog.info("FS: FAT read-only layer registered (no volume mounted)", .{});
}

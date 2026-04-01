//! Multiboot2-compatible boot info construction shared by UEFI ZBM (x86_64, AArch64, LoongArch object).
const std = @import("std");
const uefi = std.os.uefi;
const ConfigurationTable = uefi.tables.ConfigurationTable;

/// GOP framebuffer fields passed to the kernel via multiboot2 tag 8.
pub const GopFbInfo = struct {
    addr: u64,
    width: u32,
    height: u32,
    pitch: u32,
    bpp: u8,
    /// 1 = UEFI BGR order; 0 = RGB
    pixel_bgr: u8,
};

noinline fn copyBytes(dst: [*]u8, src: []const u8) void {
    for (src, 0..) |b, i| {
        @as(*volatile u8, @ptrCast(dst + i)).* = b;
    }
}

/// UEFI 配置表中的 ACPI RSDP 副本长度（按 ACPI 规范 revision / length 字段）。
fn acpiRsdpPayloadLen(p: [*]const u8) usize {
    const rev = p[15];
    if (rev >= 2) {
        const len = std.mem.readInt(u32, p[20..24], .little);
        if (len >= 36 and len <= 512) return @intCast(len);
    }
    return 20;
}

/// 自 UEFI SystemTable 查找 ACPI 2.0/1.0 RSDP，供 Multiboot2 tag 14/15 嵌入。
pub fn findAcpiRsdp(st: *uefi.tables.SystemTable) ?[]const u8 {
    const n = st.number_of_table_entries;
    const cts = st.configuration_table[0..n];
    for (cts) |ct| {
        if (ct.vendor_guid.eql(ConfigurationTable.acpi_20_table_guid)) {
            const p: [*]const u8 = @ptrCast(ct.vendor_table);
            const len = acpiRsdpPayloadLen(p);
            return p[0..len];
        }
    }
    for (cts) |ct| {
        if (ct.vendor_guid.eql(ConfigurationTable.acpi_10_table_guid)) {
            const p: [*]const u8 = @ptrCast(ct.vendor_table);
            return p[0..20];
        }
    }
    return null;
}

pub fn buildBootInfo(
    bi_base: [*]u8,
    mmap: uefi.tables.MemoryMapSlice,
    cmdline: []const u8,
    gop_fb: ?GopFbInfo,
    acpi_rsdp: ?[]const u8,
) usize {
    var off: usize = 8; // skip BootInfoHeader (filled at end)

    // Tag: command line (type=1)
    {
        const p: [*]u32 = @ptrCast(@alignCast(bi_base + off));
        p[0] = 1;
        const str_sz: u32 = @intCast(cmdline.len + 1);
        p[1] = 8 + str_sz;
        copyBytes(bi_base + off + 8, cmdline);
        (bi_base + off + 8)[cmdline.len] = 0;
        off += (8 + str_sz + 7) & ~@as(usize, 7);
    }

    // Tag: basic memory info (type=4)
    const meminfo_off = off;
    {
        const p: [*]u32 = @ptrCast(@alignCast(bi_base + off));
        p[0] = 4;
        p[1] = 16;
        p[2] = 640; // mem_lower KB
        p[3] = 0; // mem_upper KB (filled after mmap scan)
        off += 16;
    }

    // Tag: memory map (type=6)
    {
        const tag_start = off;
        const p: [*]u32 = @ptrCast(@alignCast(bi_base + off));
        p[0] = 6;
        p[2] = 24; // entry_size
        p[3] = 0; // entry_version
        var eoff: usize = 16;
        var mem_upper_kb: u32 = 0;

        var it = mmap.iterator();
        while (it.next()) |desc| {
            const mb_type: u32 = uefiToMb2MemType(desc.type);
            const base = desc.physical_start;
            const length = desc.number_of_pages * 4096;

            const ep: [*]u8 = bi_base + tag_start + eoff;
            @as(*u64, @ptrCast(@alignCast(ep))).* = base;
            @as(*u64, @ptrCast(@alignCast(ep + 8))).* = length;
            @as(*u32, @ptrCast(@alignCast(ep + 16))).* = mb_type;
            @as(*u32, @ptrCast(@alignCast(ep + 20))).* = 0;

            if (mb_type == 1 and base >= 0x100000) {
                mem_upper_kb +|= @intCast(length / 1024);
            }
            eoff += 24;
        }

        p[1] = @intCast(eoff); // tag size

        const mi: [*]u32 = @ptrCast(@alignCast(bi_base + meminfo_off));
        mi[3] = mem_upper_kb;

        off += (eoff + 7) & ~@as(usize, 7);
    }

    // Tag: framebuffer (type=8)
    if (gop_fb) |fb| {
        const base = bi_base + off;
        @as(*u32, @ptrCast(@alignCast(base))).* = 8;
        @as(*u32, @ptrCast(@alignCast(base + 4))).* = 32;
        @as(*u64, @ptrCast(@alignCast(base + 8))).* = fb.addr;
        @as(*u32, @ptrCast(@alignCast(base + 16))).* = fb.pitch;
        @as(*u32, @ptrCast(@alignCast(base + 20))).* = fb.width;
        @as(*u32, @ptrCast(@alignCast(base + 24))).* = fb.height;
        base[28] = fb.bpp;
        base[29] = 1;
        base[30] = fb.pixel_bgr;
        base[31] = 0x5A;
        off += (32 + 7) & ~@as(usize, 7);
    }

    // Tag: ACPI RSDP (type=14 old / 15 new, per GNU Multiboot2)
    if (acpi_rsdp) |rsdp| {
        if (rsdp.len >= 20) {
            const use_new: bool = rsdp.len >= 36 or rsdp[15] >= 2;
            const tag_type: u32 = if (use_new) 15 else 14;
            const p: [*]u32 = @ptrCast(@alignCast(bi_base + off));
            p[0] = tag_type;
            const tag_sz: u32 = @intCast(8 + rsdp.len);
            p[1] = tag_sz;
            copyBytes(bi_base + off + 8, rsdp);
            off += (tag_sz + 7) & ~@as(usize, 7);
        }
    }

    // Tag: end (type=0)
    {
        const p: [*]u32 = @ptrCast(@alignCast(bi_base + off));
        p[0] = 0;
        p[1] = 8;
        off += 8;
    }

    const hdr: [*]u32 = @ptrCast(@alignCast(bi_base));
    hdr[0] = @intCast(off);
    hdr[1] = 0;

    return @intFromPtr(bi_base);
}

fn uefiToMb2MemType(t: uefi.tables.MemoryType) u32 {
    return switch (t) {
        .conventional_memory, .loader_code, .loader_data,
        .boot_services_code, .boot_services_data,
        => 1,
        .acpi_reclaim_memory => 3,
        .acpi_memory_nvs => 4,
        .unusable_memory => 5,
        else => 2,
    };
}

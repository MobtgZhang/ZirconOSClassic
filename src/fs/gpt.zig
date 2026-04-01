//! GPT 分区表只读解析子集（保护性 MBR + 主头），供块栈后续使用。

const std = @import("std");

pub const GptHeaderMagic: u64 = 0x5452415020494645; // "EFI PART" little-endian on disk as bytes

pub fn isGptProtectiveMbr(mbr_sector: *const [512]u8) bool {
    // 分区类型 0xEE 在第一分区项
    return mbr_sector[450] == 0xEE;
}

pub fn headerMagicOk(header_lba0: *const [512]u8) bool {
    return std.mem.readInt(u64, header_lba0[0..8], .little) == GptHeaderMagic;
}

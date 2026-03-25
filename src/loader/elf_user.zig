//! 用户态 ELF64 映像校验（加载器第一阶段）。

pub const ELF_MAGIC: u32 = 0x464C457F;

pub fn isElf64Executable(buf: [*]const u8, len: usize) bool {
    if (len < 24) return false;
    const magic: u32 = @as(*const u32, @ptrCast(@alignCast(buf))).*;
    if (magic != ELF_MAGIC) return false;
    if (buf[4] != 2) return false; // ELFCLASS64
    if (buf[16] != 2) return false; // ET_EXEC
    return true;
}

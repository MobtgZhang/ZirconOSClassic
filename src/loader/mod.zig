//! 加载器 — PE/ELF（NT 5.x 映像加载器骨架）。

const klog = @import("../rtl/klog.zig");

pub const elf_user = @import("elf_user.zig");

pub fn initExecutive() void {
    klog.info("LOADER: ELF64 user image validator ready", .{});
}

/// 校验嵌入式 shell.elf；映射与用户态入口为后续阶段。
pub fn tryLoadEmbeddedShellElf(buf: []const u8) bool {
    if (buf.len == 0) {
        klog.info("LOADER: no embedded shell image", .{});
        return false;
    }
    if (!elf_user.isElf64Executable(@ptrCast(@alignCast(buf.ptr)), buf.len)) {
        klog.warn("LOADER: embedded blob is not ELF64 ET_EXEC", .{});
        return false;
    }
    klog.info("LOADER: ELF64 shell validated (exec mapping TBD)", .{});
    return true;
}

pub fn initStub() void {
    initExecutive();
}

//! 文件系统 — VFS、FAT（NT 5.x IFS 骨架）。

const klog = @import("../rtl/klog.zig");

pub const fat = @import("fat.zig");
pub const gpt = @import("gpt.zig");

pub fn initExecutive() void {
    fat.initReadOnlyStubs();
    klog.info("FS: VFS executive init (GPT helpers in fs/gpt.zig)", .{});
}

pub fn initStub() void {
    initExecutive();
}

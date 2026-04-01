//! Zircon64 原生系统调用表（`syscall`/`SYSRET` 路径用）；与 int 0x80 GRE 路径分离。

const klog = @import("../../rtl/klog.zig");

/// 服务描述符（SSDT 风格自命名，不声称与任何商业 OS 二进制兼容）。
pub const ZcServiceTableDescriptor = struct {
    base: [*]const *const anyopaque,
    limit: u32,
};

pub fn ZcStubNtTerminateProcess() callconv(.c) void {}

var zc_native_table: [1]*const anyopaque = .{&ZcStubNtTerminateProcess};

pub var ZcServiceDescriptorTable: ZcServiceTableDescriptor = .{
    .base = &zc_native_table,
    .limit = @sizeOf(@TypeOf(zc_native_table)),
};

pub fn initExecutive() void {
    klog.info("SYSCALL: ZcServiceDescriptorTable native path stub (1 service)", .{});
}

//! ntdll 兼容层（Nt*/Rtl* 子集桩）。
//! Syscall 编号与 `subsystems/win32/win32_syscalls.zig` 对齐（int 0x80，RAX）。

const klog = @import("../rtl/klog.zig");

pub const NTSTATUS = u32;
pub const STATUS_SUCCESS: NTSTATUS = 0;

/// 与内核 `win32_syscalls` 一致（用户态 Ring3 目标 ABI）。
pub const syscall = struct {
    pub const NtUserInvalidateWindow: u64 = 0x1000;
    pub const NtUserToggleStartMenu: u64 = 0x1001;
    pub const NtGdiFillRect: u64 = 0x1010;
};

pub fn initStub() void {}

pub fn logSubsystemVersion() void {
    klog.info("NTDLL: native API + GRE syscall ids 0x1000..0x1010 (stub)", .{});
}

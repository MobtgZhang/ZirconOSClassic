//! Syscall dispatch stub (Phase 2)
//! int 0x80 vector 128；GRE 桌面 syscall 见 `subsystems/zircon64/zircon64_syscalls.zig`。
//! 原生 `syscall`/`SYSRET` 表见 `zircon_syscall_table.zig`（`ZcServiceDescriptorTable`）。

const klog = @import("../../rtl/klog.zig");
const InterruptFrame = @import("../../ke/interrupt.zig").InterruptFrame;
const gre_sc = @import("../../subsystems/zircon64/zircon64_syscalls.zig");

pub const STATUS_INVALID_PARAMETER: i64 = -1;

pub fn dispatch(frame: *InterruptFrame) void {
    const syscall_no = frame.rax;
    if (gre_sc.dispatchGre(frame)) return;

    klog.debug("Syscall %u (stub)", .{syscall_no});
    frame.rax = @as(u64, @bitCast(STATUS_INVALID_PARAMETER));
}

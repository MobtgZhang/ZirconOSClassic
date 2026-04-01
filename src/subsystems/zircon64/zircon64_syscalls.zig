//! int 0x80 / vector 128：NtUser* / NtGdi* 最小分发（内核侧；与 ntdll 编号一致）。

const InterruptFrame = @import("../../ke/interrupt.zig").InterruptFrame;
const ntuser = @import("ntuser.zig");
const gdi_mod = @import("gdi.zig");

pub const NtUserInvalidateWindow: u64 = 0x1000;
pub const NtUserToggleStartMenu: u64 = 0x1001;
pub const NtGdiFillRect: u64 = 0x1010;

pub const STATUS_SUCCESS: u64 = 0;

pub fn dispatchGre(frame: *InterruptFrame) bool {
    return switch (frame.rax) {
        NtUserInvalidateWindow => blk: {
            ntuser.invalidateWindow(@truncate(frame.rdi));
            frame.rax = STATUS_SUCCESS;
            break :blk true;
        },
        NtUserToggleStartMenu => blk: {
            ntuser.toggleStartMenu();
            frame.rax = STATUS_SUCCESS;
            break :blk true;
        },
        NtGdiFillRect => blk: {
            const x: i32 = @bitCast(@as(u32, @truncate(frame.rsi)));
            const y: i32 = @bitCast(@as(u32, @truncate(frame.rdx)));
            const w: i32 = @bitCast(@as(u32, @truncate(frame.r10)));
            const h: i32 = @bitCast(@as(u32, @truncate(frame.r8)));
            const color: u32 = @truncate(frame.r9);
            gdi_mod.fillRectScreen(x, y, w, h, color);
            frame.rax = STATUS_SUCCESS;
            break :blk true;
        },
        else => false,
    };
}

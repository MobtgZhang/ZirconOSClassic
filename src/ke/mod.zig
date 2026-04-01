//! Kernel Executive（ke）— 调度、定时器、中断、同步（NT 5.x `ke/` 骨架）。

pub const interrupt = @import("interrupt.zig");
pub const timer = @import("timer.zig");
pub const scheduler = @import("scheduler.zig");
pub const sync = @import("sync.zig");
pub const irql = @import("irql.zig");

pub fn initStub() void {}

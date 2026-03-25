//! Memory Manager（mm）— 物理帧、虚拟内存、堆（NT 5.x 内存管理器骨架）。

const klog = @import("../rtl/klog.zig");

pub const frame = @import("frame.zig");
pub const heap = @import("heap.zig");

var global_frames: ?*frame.FrameAllocator = null;

pub fn initExecutive(fa: *frame.FrameAllocator) void {
    global_frames = fa;
    klog.info("MM: Executive bound to frame allocator (used_frames=%u)", .{fa.used_frames});
}

pub fn frameAllocator() ?*frame.FrameAllocator {
    return global_frames;
}

pub fn initStub() void {}

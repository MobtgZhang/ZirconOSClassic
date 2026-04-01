//! 调度器级同步原语子集（NT 5.x `KTHREAD` / dispatcher 对象雏形，单核自旋占位）。

const klog = @import("../rtl/klog.zig");

pub const DispatcherMutex = struct {
    locked: bool = false,

    pub fn init() DispatcherMutex {
        return .{};
    }

    pub fn lock(self: *DispatcherMutex) void {
        while (self.locked) {}
        self.locked = true;
    }

    pub fn unlock(self: *DispatcherMutex) void {
        self.locked = false;
    }
};

pub const DispatcherEvent = struct {
    signaled: bool = false,

    pub fn init(manual_reset: bool) DispatcherEvent {
        _ = manual_reset;
        return .{};
    }

    pub fn set(self: *DispatcherEvent) void {
        self.signaled = true;
    }

    pub fn clear(self: *DispatcherEvent) void {
        self.signaled = false;
    }
};

var g_system_lock: DispatcherMutex = .{};

pub fn initExecutive() void {
    @import("irql.zig").initExecutive();
    g_system_lock = DispatcherMutex.init();
    klog.info("KE: dispatcher mutex + event stubs ready", .{});
}

pub fn systemLock() *DispatcherMutex {
    return &g_system_lock;
}

//! Process / Thread 子系统（ps）— EPROCESS 语义最小子集。

const klog = @import("../rtl/klog.zig");

pub const Process = struct {
    pid: u32,
    parent_pid: u32,
    name: [16]u8,
};

const MAX_PROC: usize = 32;
var processes: [MAX_PROC]Process = undefined;
var proc_count: usize = 0;

pub fn initExecutive() void {
    proc_count = 0;
    processes[0] = .{
        .pid = 4,
        .parent_pid = 0,
        .name = [_]u8{0} ** 16,
    };
    const sys = "System";
    @memcpy(processes[0].name[0..sys.len], sys);
    proc_count = 1;
    klog.info("PS: System process pid=%u — 64-bit native only, no WOW64 (stub)", .{processes[0].pid});
}

pub fn processCount() usize {
    return proc_count;
}

pub fn getProcess(i: usize) ?Process {
    if (i >= proc_count) return null;
    return processes[i];
}

pub fn initStub() void {
    initExecutive();
}

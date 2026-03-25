//! Object Manager（ob）— 句柄表与对象类型（NT 5.x 最小子集）。

const klog = @import("../rtl/klog.zig");

pub const ObjectType = enum(u8) {
    none = 0,
    file = 1,
    event = 2,
    port = 3,
    device = 4,
    directory = 5,
    window_station = 6,
    desktop = 7,
    window = 8,
};

const HANDLE_FIRST: u32 = 0x10;
const MAX_HANDLES: usize = 256;

var handles: [MAX_HANDLES]?*anyopaque = [_]?*anyopaque{null} ** MAX_HANDLES;
var handle_types: [MAX_HANDLES]ObjectType = [_]ObjectType{.none} ** MAX_HANDLES;
var next_index: u32 = 0;
var initialized: bool = false;

pub fn initExecutive() void {
    if (initialized) return;
    initialized = true;
    for (&handles) |*h| h.* = null;
    for (&handle_types) |*t| t.* = .none;
    next_index = 0;
    klog.info("OB: handle table (%u slots), types=%u", .{ MAX_HANDLES, @intFromEnum(ObjectType.directory) + 1 });
}

pub fn referenceObject(handle: u32) bool {
    const idx = handle - HANDLE_FIRST;
    if (idx >= MAX_HANDLES) return false;
    return handles[idx] != null;
}

pub fn createHandle(ptr: *anyopaque, ty: ObjectType) ?u32 {
    if (next_index >= MAX_HANDLES) return null;
    const idx: u32 = @intCast(next_index);
    next_index += 1;
    handles[idx] = ptr;
    handle_types[idx] = ty;
    return HANDLE_FIRST + idx;
}

pub fn dereferenceHandle(handle: u32) void {
    const idx = handle - HANDLE_FIRST;
    if (idx >= MAX_HANDLES) return;
    handles[idx] = null;
    handle_types[idx] = .none;
}

pub fn initStub() void {
    initExecutive();
}

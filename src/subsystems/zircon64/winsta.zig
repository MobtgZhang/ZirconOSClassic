//! Window Station / Desktop 内核对象（WinSta0\Default），与 OB 句柄绑定。

const ob = @import("../../ob/mod.zig");
const klog = @import("../../rtl/klog.zig");

pub const WindowStation = struct {
    name: [32]u8 = undefined,
    name_len: usize = 0,
    default_desktop_handle: u32 = 0,
};

pub const DesktopObj = struct {
    id: u32,
    heap_reserved_kb: u32,
    winsta_ob_handle: u32,
};

var g_winsta: WindowStation = .{};
var g_desktop: DesktopObj = .{
    .id = 0,
    .heap_reserved_kb = 0,
    .winsta_ob_handle = 0,
};

pub var winsta_ob_handle: u32 = 0;
pub var default_desktop_ob_handle: u32 = 0;

pub fn initWinSta0Default() void {
    const n = "WinSta0";
    @memset(&g_winsta.name, 0);
    @memcpy(g_winsta.name[0..n.len], n);
    g_winsta.name_len = n.len;

    winsta_ob_handle = ob.createHandle(@ptrCast(&g_winsta), .window_station) orelse 0;
    g_desktop = .{
        .id = 1,
        .heap_reserved_kb = 4096,
        .winsta_ob_handle = winsta_ob_handle,
    };
    default_desktop_ob_handle = ob.createHandle(@ptrCast(&g_desktop), .desktop) orelse 0;
    g_winsta.default_desktop_handle = default_desktop_ob_handle;

    klog.info("WINSTA: WinSta0\\Default desk_id=%u ob_sta=0x%x ob_desk=0x%x", .{
        g_desktop.id,
        winsta_ob_handle,
        default_desktop_ob_handle,
    });
}

pub fn desktopId() u32 {
    return g_desktop.id;
}

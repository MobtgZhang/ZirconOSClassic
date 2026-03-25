//! ntuser — 窗口站、桌面、HWND、按窗口的消息队列（USER 层骨架）。

const klog = @import("../../rtl/klog.zig");
const winsta_mod = @import("winsta.zig");
const shell_state = @import("shell_state.zig");

pub const winsta_interactive: []const u8 = "WinSta0";
pub const desktop_default: []const u8 = "Default";

pub var interactive_desktop_id: u32 = 0;
pub var focus_hwnd: u32 = 0;
pub var input_desktop_id: u32 = 0;

pub const MsgId = enum(u32) {
    wm_null = 0x0000,
    wm_paint = 0x000F,
    wm_close = 0x0010,
    wm_quit = 0x0012,
    wm_keydown = 0x0100,
    wm_keyup = 0x0101,
};

pub const Message = struct {
    hwnd: u32,
    msg: MsgId,
    wparam: usize = 0,
    lparam: usize = 0,
};

pub const WndClass = enum(u8) {
    desktop_root,
    shell_tray,
};

pub const Window = struct {
    hwnd: u32,
    parent: u32,
    class: WndClass,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    visible: bool,
    dirty: bool,
    z_order: u8,
};

pub const HWND_DESKTOP: u32 = 1;
pub const HWND_TASKBAR: u32 = 2;

const MAX_WINDOWS: usize = 8;
const MSG_QUEUE_CAP: usize = 16;

var windows: [MAX_WINDOWS]?Window = .{null} ** MAX_WINDOWS;

const PerHwndQueue = struct {
    buf: [MSG_QUEUE_CAP]Message = undefined,
    head: usize = 0,
    tail: usize = 0,
    count: usize = 0,
};

var msg_queues: [MAX_WINDOWS]PerHwndQueue = undefined;

var start_menu_open: bool = false;
var vk_lwin_held: bool = false;

pub fn isStartMenuOpen() bool {
    return start_menu_open;
}

pub fn toggleStartMenu() void {
    start_menu_open = !start_menu_open;
    shell_state.resetStartMenuNav();
    invalidateWindow(HWND_DESKTOP);
    invalidateWindow(HWND_TASKBAR);
}

pub fn closeStartMenu() void {
    if (!start_menu_open) return;
    start_menu_open = false;
    shell_state.resetStartMenuNav();
    invalidateWindow(HWND_DESKTOP);
    invalidateWindow(HWND_TASKBAR);
}

fn hwndToSlot(hwnd: u32) ?usize {
    if (hwnd == 0 or hwnd > MAX_WINDOWS) return null;
    return @intCast(hwnd - 1);
}

pub fn init() void {
    winsta_mod.initWinSta0Default();
    interactive_desktop_id = winsta_mod.desktopId();
    input_desktop_id = interactive_desktop_id;

    for (&msg_queues) |*q| {
        q.* = .{};
    }
    for (&windows) |*w| w.* = null;

    const sw: i32 = @intCast(@import("../../hal/fb_console.zig").screenWidth());
    const sh: i32 = @intCast(@import("../../hal/fb_console.zig").screenHeight());
    const taskbar_h: i32 = 28;

    registerWindow(.{
        .hwnd = HWND_DESKTOP,
        .parent = 0,
        .class = .desktop_root,
        .x = 0,
        .y = 0,
        .w = sw,
        .h = if (sh > taskbar_h) sh - taskbar_h else sh,
        .visible = true,
        .dirty = true,
        .z_order = 0,
    });

    registerWindow(.{
        .hwnd = HWND_TASKBAR,
        .parent = 0,
        .class = .shell_tray,
        .x = 0,
        .y = if (sh > taskbar_h) sh - taskbar_h else 0,
        .w = sw,
        .h = taskbar_h,
        .visible = true,
        .dirty = true,
        .z_order = 1,
    });

    focus_hwnd = HWND_TASKBAR;

    klog.info("NTUSER: WinSta0\\Default desktop id=%u (per-HWND queues)", .{interactive_desktop_id});
    dispatchShellStartup();
}

fn registerWindow(w: Window) void {
    const slot = hwndToSlot(w.hwnd) orelse return;
    windows[slot] = w;
}

pub fn getWindow(hwnd: u32) ?Window {
    const slot = hwndToSlot(hwnd) orelse return null;
    return windows[slot];
}

pub fn invalidateWindow(hwnd: u32) void {
    const slot = hwndToSlot(hwnd) orelse return;
    if (windows[slot]) |*win| {
        win.dirty = true;
        _ = postMessageTo(hwnd, .{ .hwnd = hwnd, .msg = .wm_paint, .wparam = 0, .lparam = 0 });
    }
}

pub fn invalidateRect(hwnd: u32) void {
    invalidateWindow(hwnd);
}

/// 全桌面无效（壁纸 + 任务栏）。
pub fn invalidateDesktopVisual() void {
    invalidateWindow(HWND_DESKTOP);
    invalidateWindow(HWND_TASKBAR);
}

/// 仅无效化桌面 HWND（开始菜单高亮等），不刷任务栏，避免指针每帧移动时整条任务栏闪烁。
pub fn invalidateDesktopWorkspace() void {
    invalidateWindow(HWND_DESKTOP);
}

pub fn postMessageTo(hwnd: u32, msg: Message) bool {
    if (msg.hwnd != hwnd) return false;
    const slot = hwndToSlot(hwnd) orelse return false;
    const q = &msg_queues[slot];
    if (q.count >= MSG_QUEUE_CAP) return false;
    q.buf[q.tail] = msg;
    q.tail = (q.tail + 1) % MSG_QUEUE_CAP;
    q.count += 1;
    return true;
}

pub fn postMessage(msg: Message) bool {
    return postMessageTo(msg.hwnd, msg);
}

pub fn peekMessageForHwnd(hwnd: u32) ?Message {
    const slot = hwndToSlot(hwnd) orelse return null;
    const q = &msg_queues[slot];
    if (q.count == 0) return null;
    return q.buf[q.head];
}

pub fn getMessageAny() ?Message {
    var i: usize = 0;
    while (i < MAX_WINDOWS) : (i += 1) {
        if (peekMessageForHwnd(@intCast(i + 1))) |m| return m;
    }
    return null;
}

pub fn popMessageForHwnd(hwnd: u32) ?Message {
    const slot = hwndToSlot(hwnd) orelse return null;
    const q = &msg_queues[slot];
    if (q.count == 0) return null;
    const m = q.buf[q.head];
    q.head = (q.head + 1) % MSG_QUEUE_CAP;
    q.count -= 1;
    return m;
}

/// 轮询所有队列，取第一条消息（公平轮询）。
pub fn popMessageRoundRobin(state: *usize) ?Message {
    var n: usize = 0;
    while (n < MAX_WINDOWS) : (n += 1) {
        const hwnd: u32 = @intCast((state.* % MAX_WINDOWS) + 1);
        state.* +%= 1;
        if (popMessageForHwnd(hwnd)) |m| return m;
    }
    return null;
}

pub fn clearPaintQueued(hwnd: u32) void {
    const slot = hwndToSlot(hwnd) orelse return;
    if (windows[slot]) |*win| win.dirty = false;
}

pub fn dispatchShellStartup() void {
    _ = postMessageTo(HWND_DESKTOP, .{ .hwnd = HWND_DESKTOP, .msg = .wm_paint, .wparam = 0, .lparam = 0 });
    _ = postMessageTo(HWND_TASKBAR, .{ .hwnd = HWND_TASKBAR, .msg = .wm_paint, .wparam = 0, .lparam = 0 });
    klog.info("NTUSER: Shell_TrayWnd + desktop HWND startup messages", .{});
}

pub fn postKeyDownToDesktop(vk: u32) bool {
    return postMessageTo(HWND_DESKTOP, .{ .hwnd = HWND_DESKTOP, .msg = .wm_keydown, .wparam = vk, .lparam = 0 });
}

pub fn postKeyUpToDesktop(vk: u32) bool {
    return postMessageTo(HWND_DESKTOP, .{ .hwnd = HWND_DESKTOP, .msg = .wm_keyup, .wparam = vk, .lparam = 0 });
}

pub fn onVirtualKeyDown(key: u32) void {
    switch (key) {
        0x5B => {
            if (!vk_lwin_held) {
                vk_lwin_held = true;
                toggleStartMenu();
            }
        },
        0x1B => {
            if (shell_state.context_menu_visible) {
                shell_state.context_menu_visible = false;
                invalidateWindow(HWND_DESKTOP);
            }
            if (start_menu_open) {
                closeStartMenu();
            }
        },
        else => {},
    }
}

pub fn onVirtualKeyUp(key: u32) void {
    if (key == 0x5B) vk_lwin_held = false;
}

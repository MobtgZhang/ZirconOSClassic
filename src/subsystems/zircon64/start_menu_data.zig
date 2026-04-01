//! 开始菜单静态树（扁平 `lines` + 子范围），供布局、绘制与命中共用。

pub const Cmd = enum(u16) {
    none = 0,
    help = 1,
    run_dialog = 2,
    standby = 3,
    shutdown = 4,
    my_documents = 5,
    control_panel = 6,
    internet_explorer = 7,
    notepad = 8,
    paint = 9,
    ms_dos = 10,
    win_explorer = 11,
    generic_launch = 12,
};

pub const Line = struct {
    text: []const u8 = "",
    separator: bool = false,
    cascade: bool = false,
    first_child: u16 = 0,
    child_count: u8 = 0,
    cmd: Cmd = .none,
};

/// 扁平表：根项为索引 0..root_count-1。
pub const lines = [_]Line{
    // --- 根菜单 (0..9) ---
    .{ .text = "Programs", .cascade = true, .first_child = 9, .child_count = 9 },
    .{ .text = "Documents", .cascade = true, .first_child = 38, .child_count = 1 },
    .{ .text = "Settings", .cascade = true, .first_child = 39, .child_count = 6 },
    .{ .text = "Find", .cascade = true, .first_child = 45, .child_count = 3 },
    .{ .text = "Help", .cmd = .help },
    .{ .text = "Run...", .cmd = .run_dialog },
    .{ .separator = true },
    .{ .text = "Suspend", .cmd = .standby },
    .{ .text = "Shut Down...", .cmd = .shutdown },
    // --- Programs (9..18) ---
    .{ .text = "Accessories", .cascade = true, .first_child = 18, .child_count = 11 },
    .{ .text = "Online Services", .cascade = true, .first_child = 29, .child_count = 2 },
    .{ .text = "StartUp", .cascade = true, .first_child = 31, .child_count = 1 },
    .{ .text = "Internet Explorer", .cmd = .internet_explorer },
    .{ .text = "Internet Mail", .cmd = .generic_launch },
    .{ .text = "Internet News", .cmd = .generic_launch },
    .{ .text = "Microsoft NetMeeting", .cmd = .generic_launch },
    .{ .text = "MS-DOS Prompt", .cmd = .ms_dos },
    .{ .text = "Windows Explorer", .cmd = .win_explorer },
    // --- Accessories (18..29) ---
    .{ .text = "Internet Tools", .cascade = true, .first_child = 32, .child_count = 2 },
    .{ .text = "Multimedia", .cascade = true, .first_child = 34, .child_count = 2 },
    .{ .text = "System Tools", .cascade = true, .first_child = 36, .child_count = 2 },
    .{ .text = "Calculator", .cmd = .generic_launch },
    .{ .text = "HyperTerminal", .cmd = .generic_launch },
    .{ .text = "Imaging", .cmd = .generic_launch },
    .{ .text = "Notepad", .cmd = .notepad },
    .{ .text = "Online Registration", .cmd = .generic_launch },
    .{ .text = "Paint", .cmd = .paint },
    .{ .text = "Phone Dialer", .cmd = .generic_launch },
    .{ .text = "WordPad", .cmd = .generic_launch },
    // --- Online Services (29..31) ---
    .{ .text = "Online Service A", .cmd = .generic_launch },
    .{ .text = "Online Service B", .cmd = .generic_launch },
    // --- StartUp (31) ---
    .{ .text = "Startup Item", .cmd = .generic_launch },
    // --- Internet Tools (32..34) ---
    .{ .text = "Get on the Internet", .cmd = .generic_launch },
    .{ .text = "Internet Explorer", .cmd = .internet_explorer },
    // --- Multimedia (34..36) ---
    .{ .text = "CD Player", .cmd = .generic_launch },
    .{ .text = "Sound Recorder", .cmd = .generic_launch },
    // --- System Tools (36..38) ---
    .{ .text = "Disk Cleanup", .cmd = .generic_launch },
    .{ .text = "Scandisk", .cmd = .generic_launch },
    // --- Documents (38) ---
    .{ .text = "My Documents", .cmd = .my_documents },
    // --- Settings (39..45) ---
    .{ .text = "Control Panel", .cmd = .control_panel },
    .{ .text = "Printers", .cmd = .generic_launch },
    .{ .text = "Taskbar and Start Menu", .cmd = .generic_launch },
    .{ .text = "Folder Options", .cmd = .generic_launch },
    .{ .text = "Active Desktop", .cmd = .generic_launch },
    .{ .text = "Windows Update", .cmd = .generic_launch },
    // --- Find (45..48) ---
    .{ .text = "For Files or Folders...", .cmd = .generic_launch },
    .{ .text = "For Computers...", .cmd = .generic_launch },
    .{ .text = "On the Internet...", .cmd = .generic_launch },
};

pub const root_count: u8 = 9;
pub const max_cascade_depth: u8 = 7;

pub fn lineAt(i: u16) Line {
    return lines[i];
}

pub fn rowPixelHeight(layout_mod: type, idx: u16) i32 {
    const L = lines[idx];
    if (L.separator) return layout_mod.START_MENU_SEP_H;
    return layout_mod.START_MENU_ITEM_H;
}

pub fn blockPixelHeight(layout_mod: type, first: u16, count: u8) i32 {
    var sum: i32 = layout_mod.START_MENU_BODY_TOP_PAD;
    var k: u8 = 0;
    while (k < count) : (k += 1) {
        sum += rowPixelHeight(layout_mod, first + k);
    }
    sum += layout_mod.START_MENU_BODY_BOTTOM_PAD;
    return sum;
}

pub fn childLineIndex(parent: u16, slot: u8) ?u16 {
    const L = lines[parent];
    if (!L.cascade or L.child_count == 0 or slot >= L.child_count) return null;
    return L.first_child + slot;
}

//! Classic Start Menu
//! Single-column popup layout with grey background and 3D raised border.
//! Left sidebar shows "ZirconOS" vertical text on dark gradient strip.
//! Items are flat text entries with 16x16 icons, highlight on hover.
//! Submenus cascade to the right. Separator lines divide groups.

const theme = @import("theme.zig");

pub const MenuItem = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: u8 = 0,
    icon_id: u16 = 0,
    is_separator: bool = false,
    has_submenu: bool = false,
};

const MAX_ITEMS: usize = 24;
var items: [MAX_ITEMS]MenuItem = [_]MenuItem{.{}} ** MAX_ITEMS;
var item_count: usize = 0;

var visible: bool = false;

pub fn init() void {
    item_count = 0;
    visible = false;
    addDefaultItems();
}

fn setStr(dest: []u8, src: []const u8) u8 {
    const len = @min(src.len, dest.len);
    for (0..len) |i| {
        dest[i] = src[i];
    }
    return @intCast(len);
}

fn addItem(name: []const u8, icon_id: u16, has_submenu: bool) void {
    if (item_count >= MAX_ITEMS) return;
    var item = &items[item_count];
    item.name_len = setStr(&item.name, name);
    item.icon_id = icon_id;
    item.has_submenu = has_submenu;
    item_count += 1;
}

fn addSeparator() void {
    if (item_count >= MAX_ITEMS) return;
    items[item_count].is_separator = true;
    item_count += 1;
}

pub const identity = struct {
    pub const title = "Windows 2000 Style - Classic";
    pub const sidebar_text = "ZirconOS 2000";
    pub const shutdown_label = "Shut Down...";
    pub const logoff_label = "Log Off admin...";
    pub const user_name = "admin";
    pub const version_tag = "Classic GDI v1.0";
};

fn addDefaultItems() void {
    addItem("Programs", 0, true);
    addItem("Documents", 2, true);
    addItem("Settings", 6, true);
    addItem("Find", 0, true);
    addSeparator();
    addItem("Help", 0, false);
    addItem("Run...", 0, false);
    addSeparator();
    addItem("Shut Down...", 0, false);
}

pub fn toggle() void {
    visible = !visible;
}

pub fn show() void {
    visible = true;
}

pub fn hide() void {
    visible = false;
}

pub fn isVisible() bool {
    return visible;
}

pub fn contains(screen_h: i32, x: i32, y: i32) bool {
    const menu_h = theme.Layout.startmenu_height;
    const menu_w = theme.Layout.startmenu_width;
    const taskbar_h = theme.Layout.taskbar_height;
    const menu_y = screen_h - taskbar_h - menu_h;

    return x >= 0 and x < menu_w and y >= menu_y and y < menu_y + menu_h;
}

pub fn getItems() []const MenuItem {
    return items[0..item_count];
}

pub fn getBackgroundColor() u32 {
    return theme.menu_bg;
}

pub fn getSidebarColor() u32 {
    return theme.menu_sidebar_bg;
}

pub fn getHighlightColor() u32 {
    return theme.menu_hover_bg;
}

pub fn getHighlightTextColor() u32 {
    return theme.menu_hover_text;
}

pub fn getTextColor() u32 {
    return theme.menu_text;
}

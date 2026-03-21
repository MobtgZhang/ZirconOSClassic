//! Resource Loader — ZirconOS Classic Desktop
//! Scans and catalogues graphical assets from the resources/ directory tree:
//!   resources/icons/         — 16-color system icons (SVG)
//!   resources/cursors/       — Classic cursor set (SVG)
//!
//! Classic theme uses a minimal resource set: no wallpaper images (solid
//! color desktop), simple 16-color icons, and standard arrow cursors.

pub const MAX_ICONS: usize = 32;
pub const MAX_CURSORS: usize = 16;
pub const PATH_MAX: usize = 128;

pub const ResourceEntry = struct {
    path: [PATH_MAX]u8 = [_]u8{0} ** PATH_MAX,
    path_len: u8 = 0,
    loaded: bool = false,
    id: u16 = 0,
};

var icons: [MAX_ICONS]ResourceEntry = [_]ResourceEntry{.{}} ** MAX_ICONS;
var icon_count: usize = 0;

var cursors: [MAX_CURSORS]ResourceEntry = [_]ResourceEntry{.{}} ** MAX_CURSORS;
var cursor_count: usize = 0;

var initialized: bool = false;

fn setPath(dest: *[PATH_MAX]u8, src: []const u8) u8 {
    const len = @min(src.len, PATH_MAX);
    for (0..len) |i| {
        dest[i] = src[i];
    }
    return @intCast(len);
}

fn addIcon(path: []const u8, id: u16) void {
    if (icon_count >= MAX_ICONS) return;
    var e = &icons[icon_count];
    e.path_len = setPath(&e.path, path);
    e.id = id;
    e.loaded = true;
    icon_count += 1;
}

fn addCursor(path: []const u8, id: u16) void {
    if (cursor_count >= MAX_CURSORS) return;
    var e = &cursors[cursor_count];
    e.path_len = setPath(&e.path, path);
    e.id = id;
    e.loaded = true;
    cursor_count += 1;
}

pub fn init() void {
    if (initialized) return;

    icon_count = 0;
    cursor_count = 0;

    registerBuiltinIcons();
    registerBuiltinCursors();

    initialized = true;
}

fn registerBuiltinIcons() void {
    addIcon("resources/icons/computer.svg", 1);
    addIcon("resources/icons/documents.svg", 2);
    addIcon("resources/icons/network.svg", 3);
    addIcon("resources/icons/recycle_bin.svg", 4);
    addIcon("resources/icons/browser.svg", 5);
    addIcon("resources/icons/settings.svg", 6);
    addIcon("resources/icons/terminal.svg", 7);
    addIcon("resources/icons/folder.svg", 8);
}

fn registerBuiltinCursors() void {
    addCursor("resources/cursors/classic_arrow.svg", 1);
    addCursor("resources/cursors/classic_hand.svg", 2);
    addCursor("resources/cursors/classic_ibeam.svg", 3);
    addCursor("resources/cursors/classic_wait.svg", 4);
    addCursor("resources/cursors/classic_size_ns.svg", 5);
    addCursor("resources/cursors/classic_size_ew.svg", 6);
    addCursor("resources/cursors/classic_move.svg", 7);
}

// ── Public query API ──

pub fn getIconCount() usize {
    return icon_count;
}

pub fn getCursorCount() usize {
    return cursor_count;
}

pub fn getLoadedIcons() []const ResourceEntry {
    return icons[0..icon_count];
}

pub fn getCursors() []const ResourceEntry {
    return cursors[0..cursor_count];
}

pub fn findIconById(id: u16) ?*const ResourceEntry {
    for (icons[0..icon_count]) |*e| {
        if (e.id == id) return e;
    }
    return null;
}

pub fn findCursorById(id: u16) ?*const ResourceEntry {
    for (cursors[0..cursor_count]) |*e| {
        if (e.id == id) return e;
    }
    return null;
}

// ── Embedded 16x16 bitmap fallback icons (16-color system palette) ──
// Windows 2000 style: flat 16-color icons for framebuffer mode.

pub const EmbeddedIcon = struct {
    id: u16,
    name: []const u8,
    svg_path: []const u8,
    palette: [16]u32,
    pixels: [16][16]u4,
};

pub const classic_icons = [_]EmbeddedIcon{
    .{
        .id = 1,
        .name = "computer",
        .svg_path = "resources/icons/computer.svg",
        .palette = .{
            0x000000, 0x000080, 0x008000, 0x008080,
            0x800000, 0x800080, 0x808000, 0xC0C0C0,
            0x808080, 0x0000FF, 0x00FF00, 0x00FFFF,
            0xFF0000, 0xFF00FF, 0xFFFF00, 0xFFFFFF,
        },
        .pixels = .{
            .{ 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
            .{ 0, 0, 1, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 0, 0, 0 },
            .{ 0, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 15, 15, 15, 15, 15, 15, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 15, 3, 3, 3, 3, 15, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 15, 3, 3, 3, 3, 15, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 15, 3, 3, 3, 3, 15, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 15, 15, 15, 15, 15, 15, 1, 1, 3, 1, 0, 0 },
            .{ 0, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 0, 0 },
            .{ 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 7, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 0, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0 },
            .{ 0, 0, 0, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0, 0, 0, 0 },
            .{ 0, 0, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 0, 0, 0 },
            .{ 0, 0, 0, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        },
    },
    .{
        .id = 4,
        .name = "recycle_bin",
        .svg_path = "resources/icons/recycle_bin.svg",
        .palette = .{
            0x000000, 0x000080, 0x008000, 0x008080,
            0x800000, 0x800080, 0x808000, 0xC0C0C0,
            0x808080, 0x0000FF, 0x00FF00, 0x00FFFF,
            0xFF0000, 0xFF00FF, 0xFFFF00, 0xFFFFFF,
        },
        .pixels = .{
            .{ 0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0 },
            .{ 0, 0, 0, 8, 7, 7, 7, 7, 7, 7, 7, 8, 0, 0, 0, 0 },
            .{ 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0 },
            .{ 0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0 },
            .{ 0, 0, 8, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 0, 0, 0 },
            .{ 0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        },
    },
};

pub fn getEmbeddedIcons() []const EmbeddedIcon {
    return &classic_icons;
}

pub fn findEmbeddedIconById(id: u16) ?*const EmbeddedIcon {
    for (&classic_icons) |*icon| {
        if (icon.id == id) return icon;
    }
    return null;
}

pub fn isInitialized() bool {
    return initialized;
}

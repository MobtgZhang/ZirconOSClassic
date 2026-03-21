//! ZirconOS Classic — Windows 2000 GDI Desktop Theme
//! Library root: re-exports all public modules for use by the kernel
//! display compositor and the standalone desktop shell executable.
//!
//! Architecture follows ReactOS NT5 desktop model:
//!   winlogon → shell (explorer) → GDI compositor → desktop/taskbar/startmenu
//! No DWM compositor — all rendering is flat 3D beveled GDI-style.

pub const theme = @import("theme.zig");
pub const desktop = @import("desktop.zig");
pub const taskbar = @import("taskbar.zig");
pub const startmenu = @import("startmenu.zig");
pub const window_decorator = @import("window_decorator.zig");
pub const shell = @import("shell.zig");
pub const controls = @import("controls.zig");
pub const winlogon = @import("winlogon.zig");
pub const theme_loader = @import("theme_loader.zig");
pub const resource_loader = @import("resource_loader.zig");
pub const font_loader = @import("font_loader.zig");

// ── Theme identity ──

pub const theme_name = "Classic";
pub const theme_version = "1.0.0";
pub const theme_description = "ZirconOS Classic — Windows 2000 style flat 3D beveled GDI desktop with no compositor effects";

// ── Available theme variants ──

pub const available_themes = [_][]const u8{
    "classic_standard",
    "classic_storm",
    "classic_spruce",
    "classic_lilac",
    "classic_desert",
    "highcontrast_black",
    "highcontrast_white",
};

// ── Quick accessors for the kernel display compositor ──

pub fn getDesktopBackground() u32 {
    return theme.getActiveDesktopBg();
}

pub fn getTaskbarHeight() i32 {
    return theme.Layout.taskbar_height;
}

pub fn getTitlebarHeight() i32 {
    return theme.Layout.titlebar_height;
}

pub fn isDwmEnabled() bool {
    return false;
}

pub fn initClassicShell() void {
    shell.initShell();
}

pub fn switchTheme(cs: theme.ColorScheme) void {
    shell.switchTheme(cs);
}

pub fn switchThemeByName(name: []const u8) bool {
    return shell.switchThemeByName(name);
}

pub fn getActiveScheme() theme.ColorScheme {
    return theme.getActiveScheme();
}

pub fn getAvailableThemeCount() usize {
    return theme_loader.getThemeCount();
}

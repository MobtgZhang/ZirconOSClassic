//! 活动桌面主题（Multiboot2 `desktop=` 与嵌入配置对齐）。

const mb2 = @import("../../boot/multiboot2.zig");

pub var active: mb2.DesktopTheme = .ntclassic;

pub fn setFromBoot(theme: mb2.DesktopTheme) void {
    active = theme;
}

//! 经典浅色主题配色（与上游 `src/desktop/classic/src/theme.zig` 中 `scheme_standard` 语义对齐）。
//! 内核与 `hal/fb_console.packPixel32` 约定：颜色常量为 **0xRRGGBB**（R 在高字节）。

pub fn rgb(r: u32, g: u32, b: u32) u32 {
    return (r << 16) | (g << 8) | b;
}

/// 经典「标准」方案（青绿桌面 + 深蓝标题栏）。
pub const scheme_standard = struct {
    pub const desktop_bg = rgb(0x00, 0x80, 0x80);
    pub const titlebar_active = rgb(0x00, 0x00, 0x80);
    pub const titlebar_active_right = rgb(0x10, 0x84, 0xD0);
    pub const titlebar_text = rgb(0xFF, 0xFF, 0xFF);
    pub const window_bg = rgb(0xFF, 0xFF, 0xFF);
    pub const button_face = rgb(0xC0, 0xC0, 0xC0);
    pub const menu_text = rgb(0x00, 0x00, 0x00);
    /// Win2000 对话框客户区灰（近似 #D4D0C8）。
    pub const window_client = rgb(0xD4, 0xD0, 0xC8);
    pub const highlight_3d = rgb(0xFF, 0xFF, 0xFF);
    pub const shadow_3d = rgb(0x80, 0x80, 0x80);
    /// 开始菜单选中行（与活动标题栏同色）。
    pub const menu_highlight_bg = titlebar_active;
    pub const menu_highlight_fg = titlebar_text;
};

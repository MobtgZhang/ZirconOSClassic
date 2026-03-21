//! Classic Window Decorator
//! Draws window chrome with flat 3D beveled titlebar, double-line borders,
//! and caption buttons (minimize, maximize/restore, close) with raised edges.
//! Active windows get navy blue gradient titlebar; inactive windows get grey.
//! No glass, no rounded corners, no shadows.

const theme = @import("theme.zig");

pub const WindowState = enum {
    normal,
    maximized,
    minimized,
};

pub const CaptionButton = enum {
    none,
    minimize,
    maximize,
    close,
};

pub const WindowChrome = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 640,
    height: i32 = 480,
    title: [128]u8 = [_]u8{0} ** 128,
    title_len: u8 = 0,
    active: bool = true,
    state: WindowState = .normal,
    resizable: bool = true,

    pub fn getTitlebarColor(self: *const WindowChrome) u32 {
        return if (self.active) theme.titlebar_active else theme.titlebar_inactive;
    }

    pub fn getTitlebarRightColor(self: *const WindowChrome) u32 {
        return if (self.active) theme.titlebar_active_right else theme.titlebar_inactive_right;
    }

    pub fn getTitlebarText(self: *const WindowChrome) u32 {
        return if (self.active) theme.titlebar_text else theme.titlebar_inactive_text;
    }

    pub fn getBorderColor(_: *const WindowChrome) u32 {
        return theme.button_face;
    }
};

pub fn hitTestCaption(chrome: *const WindowChrome, click_x: i32, click_y: i32) CaptionButton {
    const tb_h = theme.Layout.titlebar_height;
    const btn_sz = theme.Layout.btn_size;

    if (click_y < chrome.y or click_y >= chrome.y + tb_h) return .none;

    const close_x = chrome.x + chrome.width - btn_sz - 4;
    const max_x = close_x - btn_sz - theme.Layout.caption_btn_gap;
    const min_x = max_x - btn_sz - theme.Layout.caption_btn_gap;

    if (click_x >= close_x and click_x < close_x + btn_sz and
        click_y >= chrome.y + 2 and click_y < chrome.y + 2 + btn_sz)
    {
        return .close;
    }
    if (click_x >= max_x and click_x < max_x + btn_sz and
        click_y >= chrome.y + 2 and click_y < chrome.y + 2 + btn_sz)
    {
        return .maximize;
    }
    if (click_x >= min_x and click_x < min_x + btn_sz and
        click_y >= chrome.y + 2 and click_y < chrome.y + 2 + btn_sz)
    {
        return .minimize;
    }
    return .none;
}

pub fn hitTestBorder(chrome: *const WindowChrome, click_x: i32, click_y: i32) u8 {
    if (!chrome.resizable) return 0;

    const bw = theme.Layout.window_border_width;

    const on_left = click_x >= chrome.x and click_x < chrome.x + bw;
    const on_right = click_x >= chrome.x + chrome.width - bw and click_x < chrome.x + chrome.width;
    const on_top = click_y >= chrome.y and click_y < chrome.y + bw;
    const on_bottom = click_y >= chrome.y + chrome.height - bw and click_y < chrome.y + chrome.height;

    if (on_top and on_left) return 14;
    if (on_top and on_right) return 15;
    if (on_bottom and on_left) return 16;
    if (on_bottom and on_right) return 17;
    if (on_left) return 10;
    if (on_right) return 11;
    if (on_top) return 12;
    if (on_bottom) return 13;
    return 0;
}

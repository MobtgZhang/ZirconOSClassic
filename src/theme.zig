//! ZirconOS Classic Theme Definition
//! Windows 2000 visual style: flat 3D beveled borders, grey taskbar,
//! dark blue titlebar, no DWM compositor (basic GDI-only rendering).

pub const COLORREF = u32;

pub fn rgb(r: u32, g: u32, b: u32) u32 {
    return r | (g << 8) | (b << 16);
}

pub const RGB = rgb;

pub fn argb(a: u32, r: u32, g: u32, b: u32) u32 {
    return r | (g << 8) | (b << 16) | (a << 24);
}

pub fn alphaBlend(fg: u32, bg: u32, alpha: u8) u32 {
    const a: u32 = @as(u32, alpha);
    const inv_a: u32 = 255 - a;
    const fr = fg & 0xFF;
    const fg_ = (fg >> 8) & 0xFF;
    const fb = (fg >> 16) & 0xFF;
    const br = bg & 0xFF;
    const bg_ = (bg >> 8) & 0xFF;
    const bb = (bg >> 16) & 0xFF;
    const or_ = (fr * a + br * inv_a) / 255;
    const og = (fg_ * a + bg_ * inv_a) / 255;
    const ob = (fb * a + bb * inv_a) / 255;
    return (or_ & 0xFF) | ((og & 0xFF) << 8) | ((ob & 0xFF) << 16);
}

// ── Font Constants (mapped from ZirconOSFonts) ──
// MS Sans Serif style → DejaVu Sans

pub const FONT_SYSTEM = "DejaVu Sans";
pub const FONT_SYSTEM_SIZE: i32 = 11;
pub const FONT_MONO = "DejaVu Sans Mono";
pub const FONT_MONO_SIZE: i32 = 10;
pub const FONT_CJK = "Noto Sans CJK SC";
pub const FONT_CJK_SIZE: i32 = 11;
pub const FONT_TITLE_SIZE: i32 = 11;

// ── Color Schemes ──

pub const ColorScheme = enum {
    classic_standard,
    classic_storm,
    classic_spruce,
    classic_lilac,
    classic_desert,
    highcontrast_black,
    highcontrast_white,
};

pub const SchemeColors = struct {
    desktop_bg: u32,
    titlebar_active: u32,
    titlebar_active_right: u32,
    titlebar_inactive: u32,
    titlebar_inactive_right: u32,
    titlebar_text: u32,
    titlebar_inactive_text: u32,
    window_bg: u32,
    button_face: u32,
    button_highlight: u32,
    button_shadow: u32,
    button_dark_shadow: u32,
    menu_bg: u32,
    menu_text: u32,
    selection_bg: u32,
    selection_text: u32,
};

pub const scheme_standard = SchemeColors{
    .desktop_bg = rgb(0x00, 0x80, 0x80),
    .titlebar_active = rgb(0x00, 0x00, 0x80),
    .titlebar_active_right = rgb(0x10, 0x84, 0xD0),
    .titlebar_inactive = rgb(0x80, 0x80, 0x80),
    .titlebar_inactive_right = rgb(0xC0, 0xC0, 0xC0),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xC0, 0xC0, 0xC0),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xC0, 0xC0, 0xC0),
    .button_highlight = rgb(0xFF, 0xFF, 0xFF),
    .button_shadow = rgb(0x80, 0x80, 0x80),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xC0, 0xC0, 0xC0),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x00, 0x00, 0x80),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub const scheme_storm = SchemeColors{
    .desktop_bg = rgb(0x00, 0x00, 0x00),
    .titlebar_active = rgb(0x00, 0x00, 0x64),
    .titlebar_active_right = rgb(0x00, 0x64, 0xC8),
    .titlebar_inactive = rgb(0x58, 0x58, 0x58),
    .titlebar_inactive_right = rgb(0x90, 0x90, 0x90),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xA0, 0xA0, 0xA0),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xB0, 0xB0, 0xB0),
    .button_highlight = rgb(0xE0, 0xE0, 0xE0),
    .button_shadow = rgb(0x70, 0x70, 0x70),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xB0, 0xB0, 0xB0),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x00, 0x00, 0x64),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub const scheme_spruce = SchemeColors{
    .desktop_bg = rgb(0x00, 0x60, 0x40),
    .titlebar_active = rgb(0x00, 0x40, 0x20),
    .titlebar_active_right = rgb(0x40, 0x90, 0x60),
    .titlebar_inactive = rgb(0x60, 0x80, 0x60),
    .titlebar_inactive_right = rgb(0xA0, 0xC0, 0xA0),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xC0, 0xD0, 0xC0),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xC0, 0xC0, 0xC0),
    .button_highlight = rgb(0xFF, 0xFF, 0xFF),
    .button_shadow = rgb(0x80, 0x80, 0x80),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xC0, 0xC0, 0xC0),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x00, 0x40, 0x20),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub const scheme_lilac = SchemeColors{
    .desktop_bg = rgb(0x60, 0x40, 0x80),
    .titlebar_active = rgb(0x50, 0x30, 0x70),
    .titlebar_active_right = rgb(0x90, 0x60, 0xB0),
    .titlebar_inactive = rgb(0x80, 0x70, 0x88),
    .titlebar_inactive_right = rgb(0xC0, 0xB0, 0xC8),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xD0, 0xC0, 0xD8),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xC0, 0xC0, 0xC0),
    .button_highlight = rgb(0xFF, 0xFF, 0xFF),
    .button_shadow = rgb(0x80, 0x80, 0x80),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xC0, 0xC0, 0xC0),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x50, 0x30, 0x70),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub const scheme_desert = SchemeColors{
    .desktop_bg = rgb(0xC0, 0x98, 0x50),
    .titlebar_active = rgb(0x80, 0x60, 0x20),
    .titlebar_active_right = rgb(0xC0, 0xA0, 0x60),
    .titlebar_inactive = rgb(0x90, 0x88, 0x70),
    .titlebar_inactive_right = rgb(0xC0, 0xB8, 0xA0),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xD0, 0xC8, 0xB0),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xC0, 0xC0, 0xC0),
    .button_highlight = rgb(0xFF, 0xFF, 0xFF),
    .button_shadow = rgb(0x80, 0x80, 0x80),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xC0, 0xC0, 0xC0),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x80, 0x60, 0x20),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub const scheme_highcontrast_black = SchemeColors{
    .desktop_bg = rgb(0x00, 0x00, 0x00),
    .titlebar_active = rgb(0x00, 0x00, 0x80),
    .titlebar_active_right = rgb(0x00, 0x00, 0x80),
    .titlebar_inactive = rgb(0x00, 0x80, 0x00),
    .titlebar_inactive_right = rgb(0x00, 0x80, 0x00),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0xFF, 0xFF, 0xFF),
    .window_bg = rgb(0x00, 0x00, 0x00),
    .button_face = rgb(0x00, 0x00, 0x00),
    .button_highlight = rgb(0xFF, 0xFF, 0xFF),
    .button_shadow = rgb(0xFF, 0xFF, 0xFF),
    .button_dark_shadow = rgb(0xFF, 0xFF, 0xFF),
    .menu_bg = rgb(0x00, 0x00, 0x00),
    .menu_text = rgb(0xFF, 0xFF, 0xFF),
    .selection_bg = rgb(0xFF, 0xFF, 0xFF),
    .selection_text = rgb(0x00, 0x00, 0x00),
};

pub const scheme_highcontrast_white = SchemeColors{
    .desktop_bg = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_active = rgb(0x00, 0x00, 0xFF),
    .titlebar_active_right = rgb(0x00, 0x00, 0xFF),
    .titlebar_inactive = rgb(0x80, 0x80, 0x80),
    .titlebar_inactive_right = rgb(0x80, 0x80, 0x80),
    .titlebar_text = rgb(0xFF, 0xFF, 0xFF),
    .titlebar_inactive_text = rgb(0x00, 0x00, 0x00),
    .window_bg = rgb(0xFF, 0xFF, 0xFF),
    .button_face = rgb(0xFF, 0xFF, 0xFF),
    .button_highlight = rgb(0x00, 0x00, 0x00),
    .button_shadow = rgb(0x00, 0x00, 0x00),
    .button_dark_shadow = rgb(0x00, 0x00, 0x00),
    .menu_bg = rgb(0xFF, 0xFF, 0xFF),
    .menu_text = rgb(0x00, 0x00, 0x00),
    .selection_bg = rgb(0x00, 0x00, 0xFF),
    .selection_text = rgb(0xFF, 0xFF, 0xFF),
};

pub fn getScheme(cs: ColorScheme) SchemeColors {
    return switch (cs) {
        .classic_standard => scheme_standard,
        .classic_storm => scheme_storm,
        .classic_spruce => scheme_spruce,
        .classic_lilac => scheme_lilac,
        .classic_desert => scheme_desert,
        .highcontrast_black => scheme_highcontrast_black,
        .highcontrast_white => scheme_highcontrast_white,
    };
}

// ── Active Theme State ──

var active_scheme: ColorScheme = .classic_standard;

pub fn setActiveScheme(cs: ColorScheme) void {
    active_scheme = cs;
}

pub fn getActiveScheme() ColorScheme {
    return active_scheme;
}

pub fn getActiveColors() SchemeColors {
    return getScheme(active_scheme);
}

pub fn getActiveDesktopBg() u32 {
    return getScheme(active_scheme).desktop_bg;
}

// ── Core Classic Palette (Default Standard) ──

pub const desktop_bg = rgb(0x00, 0x80, 0x80);

pub const taskbar_bg = rgb(0xC0, 0xC0, 0xC0);
pub const taskbar_top_highlight = rgb(0xFF, 0xFF, 0xFF);
pub const taskbar_bottom_shadow = rgb(0x80, 0x80, 0x80);

pub const start_btn_face = rgb(0xC0, 0xC0, 0xC0);
pub const start_btn_highlight = rgb(0xFF, 0xFF, 0xFF);
pub const start_btn_shadow = rgb(0x80, 0x80, 0x80);
pub const start_btn_dark_shadow = rgb(0x00, 0x00, 0x00);
pub const start_btn_text = rgb(0x00, 0x00, 0x00);
pub const start_label = "Start";

pub const titlebar_active = rgb(0x00, 0x00, 0x80);
pub const titlebar_active_right = rgb(0x10, 0x84, 0xD0);
pub const titlebar_text = rgb(0xFF, 0xFF, 0xFF);
pub const titlebar_inactive = rgb(0x80, 0x80, 0x80);
pub const titlebar_inactive_right = rgb(0xC0, 0xC0, 0xC0);
pub const titlebar_inactive_text = rgb(0xC0, 0xC0, 0xC0);

pub const window_bg = rgb(0xFF, 0xFF, 0xFF);
pub const window_border = rgb(0xC0, 0xC0, 0xC0);

pub const button_face = rgb(0xC0, 0xC0, 0xC0);
pub const button_highlight = rgb(0xFF, 0xFF, 0xFF);
pub const button_shadow = rgb(0x80, 0x80, 0x80);
pub const button_dark_shadow = rgb(0x00, 0x00, 0x00);

pub const tray_bg = rgb(0xC0, 0xC0, 0xC0);
pub const clock_text = rgb(0x00, 0x00, 0x00);

pub const icon_text = rgb(0xFF, 0xFF, 0xFF);
pub const icon_text_shadow = rgb(0x00, 0x00, 0x00);
pub const icon_selection = rgb(0x00, 0x00, 0x80);

pub const menu_bg = rgb(0xC0, 0xC0, 0xC0);
pub const menu_text = rgb(0x00, 0x00, 0x00);
pub const menu_separator = rgb(0x80, 0x80, 0x80);
pub const menu_hover_bg = rgb(0x00, 0x00, 0x80);
pub const menu_hover_text = rgb(0xFF, 0xFF, 0xFF);
pub const menu_sidebar_bg = rgb(0xA0, 0xA0, 0xA0);

pub const selection_bg = rgb(0x00, 0x00, 0x80);
pub const selection_text = rgb(0xFF, 0xFF, 0xFF);

pub const scrollbar_bg = rgb(0xC0, 0xC0, 0xC0);
pub const scrollbar_thumb = rgb(0xC0, 0xC0, 0xC0);

pub const login_bg = rgb(0x00, 0x00, 0x80);
pub const login_text = rgb(0xFF, 0xFF, 0xFF);

pub const shutdown_btn_bg = rgb(0xC0, 0xC0, 0xC0);
pub const shutdown_btn_text = rgb(0x00, 0x00, 0x00);

// ── Layout Constants (Windows 2000 Classic) ──

pub const Layout = struct {
    pub const taskbar_height: i32 = 30;
    pub const titlebar_height: i32 = 20;
    pub const start_btn_width: i32 = 60;
    pub const icon_size: i32 = 32;
    pub const icon_grid_x: i32 = 75;
    pub const icon_grid_y: i32 = 75;
    pub const window_border_width: i32 = 3;
    pub const corner_radius: i32 = 0;
    pub const btn_size: i32 = 16;
    pub const tray_height: i32 = 20;
    pub const tray_clock_width: i32 = 60;
    pub const startmenu_width: i32 = 200;
    pub const startmenu_height: i32 = 360;
    pub const caption_btn_gap: i32 = 2;
};

// ── GDI-only Rendering Helpers ──
// Classic theme does NOT use DWM compositor or glass effects.

pub fn isGlassEnabled() bool {
    return false;
}

pub fn getGlassAlpha() u8 {
    return 255;
}

pub fn getBlurRadius() i32 {
    return 0;
}

pub const ThemeColors = struct {
    desktop_background: u32,
    window_border_active: u32,
    window_border_inactive: u32,
    button_highlight_c: u32,
    button_shadow_c: u32,
    titlebar_active_c: u32,
    titlebar_active_right_c: u32,
    titlebar_text_c: u32,
};

pub fn getColors() ThemeColors {
    const sc = getActiveColors();
    return .{
        .desktop_background = sc.desktop_bg,
        .window_border_active = sc.button_face,
        .window_border_inactive = sc.button_face,
        .button_highlight_c = sc.button_highlight,
        .button_shadow_c = sc.button_shadow,
        .titlebar_active_c = sc.titlebar_active,
        .titlebar_active_right_c = sc.titlebar_active_right,
        .titlebar_text_c = sc.titlebar_text,
    };
}

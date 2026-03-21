//! Font Loader — ZirconOS Classic Desktop
//! Catalogues font files from 3rdparty/ZirconOSFonts/fonts/ and provides
//! named accessors for the GDI text rendering subsystem.
//!
//! Classic theme maps MS Sans Serif → DejaVu Sans (from ZirconOSFonts).
//! Font families:
//!   - Western: DejaVu Sans (MS Sans Serif replacement)
//!   - Monospace: DejaVu Sans Mono (Courier New replacement)
//!   - CJK: Noto Sans CJK SC, LXGW WenKai

pub const MAX_FONT_FAMILIES: usize = 32;
pub const PATH_MAX: usize = 160;
pub const NAME_MAX: usize = 64;

pub const FontCategory = enum(u8) {
    western = 0,
    cjk = 1,
    monospace = 2,
    display = 3,
};

pub const FontEntry = struct {
    name: [NAME_MAX]u8 = [_]u8{0} ** NAME_MAX,
    name_len: u8 = 0,
    path: [PATH_MAX]u8 = [_]u8{0} ** PATH_MAX,
    path_len: u8 = 0,
    category: FontCategory = .western,
    is_bold: bool = false,
    is_italic: bool = false,
    loaded: bool = false,
};

var fonts: [MAX_FONT_FAMILIES]FontEntry = [_]FontEntry{.{}} ** MAX_FONT_FAMILIES;
var font_count: usize = 0;
var initialized: bool = false;

var system_font_idx: usize = 0;
var mono_font_idx: usize = 0;
var cjk_font_idx: usize = 0;

fn setStr(dest: []u8, src: []const u8) u8 {
    const len = @min(src.len, dest.len);
    for (0..len) |i| {
        dest[i] = src[i];
    }
    return @intCast(len);
}

fn addFont(name: []const u8, path: []const u8, category: FontCategory) usize {
    if (font_count >= MAX_FONT_FAMILIES) return font_count;
    var e = &fonts[font_count];
    e.name_len = setStr(&e.name, name);
    e.path_len = setStr(&e.path, path);
    e.category = category;
    e.loaded = true;
    const idx = font_count;
    font_count += 1;
    return idx;
}

pub fn init() void {
    if (initialized) return;

    font_count = 0;
    registerBuiltinFonts();
    initialized = true;
}

fn registerBuiltinFonts() void {
    // MS Sans Serif replacement
    system_font_idx = addFont(
        "DejaVu Sans",
        "3rdparty/ZirconOSFonts/fonts/DejaVuSans.ttf",
        .western,
    );
    _ = addFont(
        "DejaVu Sans Bold",
        "3rdparty/ZirconOSFonts/fonts/DejaVuSans-Bold.ttf",
        .western,
    );

    // Courier New replacement
    mono_font_idx = addFont(
        "DejaVu Sans Mono",
        "3rdparty/ZirconOSFonts/fonts/DejaVuSansMono.ttf",
        .monospace,
    );
    _ = addFont(
        "DejaVu Sans Mono Bold",
        "3rdparty/ZirconOSFonts/fonts/DejaVuSansMono-Bold.ttf",
        .monospace,
    );

    // CJK fonts
    cjk_font_idx = addFont(
        "Noto Sans CJK SC",
        "3rdparty/ZirconOSFonts/fonts/NotoSansCJKsc-Regular.otf",
        .cjk,
    );
    _ = addFont(
        "Noto Sans CJK SC Bold",
        "3rdparty/ZirconOSFonts/fonts/NotoSansCJKsc-Bold.otf",
        .cjk,
    );
    _ = addFont(
        "LXGW WenKai",
        "3rdparty/ZirconOSFonts/fonts/LXGWWenKai-Regular.ttf",
        .cjk,
    );
    _ = addFont(
        "LXGW WenKai Bold",
        "3rdparty/ZirconOSFonts/fonts/LXGWWenKai-Bold.ttf",
        .cjk,
    );
}

// ── Public query API ──

pub fn getSystemFontName() []const u8 {
    if (system_font_idx < font_count) {
        return fonts[system_font_idx].name[0..fonts[system_font_idx].name_len];
    }
    return "DejaVu Sans";
}

pub fn getMonoFontName() []const u8 {
    if (mono_font_idx < font_count) {
        return fonts[mono_font_idx].name[0..fonts[mono_font_idx].name_len];
    }
    return "DejaVu Sans Mono";
}

pub fn getCjkFontName() []const u8 {
    if (cjk_font_idx < font_count) {
        return fonts[cjk_font_idx].name[0..fonts[cjk_font_idx].name_len];
    }
    return "Noto Sans CJK SC";
}

pub fn getSystemFontPath() []const u8 {
    if (system_font_idx < font_count) {
        return fonts[system_font_idx].path[0..fonts[system_font_idx].path_len];
    }
    return "";
}

pub fn getMonoFontPath() []const u8 {
    if (mono_font_idx < font_count) {
        return fonts[mono_font_idx].path[0..fonts[mono_font_idx].path_len];
    }
    return "";
}

pub fn getCjkFontPath() []const u8 {
    if (cjk_font_idx < font_count) {
        return fonts[cjk_font_idx].path[0..fonts[cjk_font_idx].path_len];
    }
    return "";
}

pub fn getWesternFontCount() usize {
    var count: usize = 0;
    for (fonts[0..font_count]) |e| {
        if (e.category == .western) count += 1;
    }
    return count;
}

pub fn getCjkFontCount() usize {
    var count: usize = 0;
    for (fonts[0..font_count]) |e| {
        if (e.category == .cjk) count += 1;
    }
    return count;
}

pub fn getMonoFontCount() usize {
    var count: usize = 0;
    for (fonts[0..font_count]) |e| {
        if (e.category == .monospace) count += 1;
    }
    return count;
}

pub fn getTotalFontCount() usize {
    return font_count;
}

pub fn getFonts() []const FontEntry {
    return fonts[0..font_count];
}

pub fn findFontByName(name: []const u8) ?*const FontEntry {
    for (fonts[0..font_count]) |*e| {
        const stored = e.name[0..e.name_len];
        if (stored.len == name.len) {
            var ok = true;
            for (0..stored.len) |i| {
                if (stored[i] != name[i]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return e;
        }
    }
    return null;
}

pub fn isInitialized() bool {
    return initialized;
}

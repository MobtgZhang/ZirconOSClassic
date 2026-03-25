//! GDI 最小子集：主表面 DC、FillRect、边框、BitBlt 占位（GRE 路径）。

const fb = @import("../../hal/fb_console.zig");
const classic = @import("../../classic/colors.zig");
const theme_mod = @import("theme.zig");

pub const DcHandle = u32;
pub const hdc_screen: DcHandle = 1;

pub fn desktopBackgroundColor() u32 {
    return switch (theme_mod.active) {
        .none => classic.rgb(0x20, 0x20, 0x20),
        else => classic.scheme_standard.desktop_bg,
    };
}

pub fn fillRectScreen(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    if (!fb.isReady() or w <= 0 or h <= 0) return;
    const x0: usize = @intCast(@max(x, 0));
    const y0: usize = @intCast(@max(y, 0));
    const rw: usize = @intCast(w);
    const rh: usize = @intCast(h);
    fb.fillRect(x0, y0, rw, rh, color);
}

pub fn frameRectScreen(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    if (w <= 1 or h <= 1) return;
    fillRectScreen(x, y, w, 1, color);
    fillRectScreen(x, y + h - 1, w, 1, color);
    fillRectScreen(x, y, 1, h, color);
    fillRectScreen(x + w - 1, y, 1, h, color);
}

/// 与 `fb_console` 8×16 字体匹配的文本宽度（像素）。
pub fn textWidthPx(text: []const u8) i32 {
    return @intCast(text.len * 8);
}

pub fn drawTextScreen(x: i32, y: i32, fg: u32, bg: u32, text: []const u8) void {
    if (!fb.isReady() or x < 0 or y < 0) return;
    fb.drawTextAtPx(@intCast(x), @intCast(y), fg, bg, text);
}

const char_w_px: i32 = 8;

/// 限制水平宽度，避免文字画出客户区后在拖动窗体时留下残影。
pub fn drawTextClipped(x: i32, y: i32, fg: u32, bg: u32, text: []const u8, max_w: i32) void {
    if (!fb.isReady() or x < 0 or y < 0 or max_w < char_w_px) return;
    const max_chars: usize = @intCast(@divTrunc(max_w, char_w_px));
    if (max_chars == 0) return;
    drawTextScreen(x, y, fg, bg, text[0..@min(text.len, max_chars)]);
}

/// 按固定列宽折行（简单按字符切分，空格处尽量断行）。
pub fn drawTextWrapped(x: i32, y: i32, fg: u32, bg: u32, text: []const u8, max_w: i32, line_h: i32, max_lines: usize) void {
    if (!fb.isReady() or x < 0 or y < 0 or max_w < char_w_px or max_lines == 0) return;
    const cpl: usize = @intCast(@divTrunc(max_w, char_w_px));
    if (cpl == 0) return;
    var off: usize = 0;
    var ly = y;
    var li: usize = 0;
    while (off < text.len and li < max_lines) : (li += 1) {
        var end = @min(off + cpl, text.len);
        if (end < text.len) {
            var k = end;
            while (k > off and text[k - 1] != ' ') : (k -= 1) {}
            if (k > off) end = k;
        }
        if (end == off) end = @min(off + 1, text.len);
        var s = off;
        while (s < end and text[s] == ' ') : (s += 1) {}
        const e = end;
        if (s < e) drawTextScreen(x, ly, fg, bg, text[s..e]);
        off = end;
        while (off < text.len and text[off] == ' ') : (off += 1) {}
        ly += line_h;
    }
}

fn lerpChan(a: u8, b: u8, num: u32, den: u32) u8 {
    if (den == 0) return a;
    return @truncate(@divTrunc(@as(u32, a) * (den - num) + @as(u32, b) * num, den));
}

fn lerpColor(left: u32, right: u32, num: u32, den: u32) u32 {
    const rl: u8 = @truncate(left >> 16);
    const gl: u8 = @truncate(left >> 8);
    const bl: u8 = @truncate(left);
    const rr: u8 = @truncate(right >> 16);
    const gr: u8 = @truncate(right >> 8);
    const br: u8 = @truncate(right);
    return classic.rgb(
        lerpChan(rl, rr, num, den),
        lerpChan(gl, gr, num, den),
        lerpChan(bl, br, num, den),
    );
}

/// 水平线性渐变（Win2000 活动标题栏风格）。
pub fn fillRectGradientH(x: i32, y: i32, w: i32, h: i32, left: u32, right: u32) void {
    if (!fb.isReady() or w <= 0 or h <= 0) return;
    const wd: u32 = @intCast(w);
    var col: i32 = 0;
    while (col < w) : (col += 1) {
        const c = lerpColor(left, right, @intCast(col), @max(wd, 1));
        fillRectScreen(x + col, y, 1, h, c);
    }
}

/// 精灵：`0x00000000` 为洞；其余像素取低 24 位为 `0xRRGGBB`（与 `classic.rgb` 一致，不要求 A 通道）。
pub fn blitArgb32(dx: i32, dy: i32, src_w: u32, src_h: u32, pixels: []const u32) void {
    if (!fb.isReady() or pixels.len < src_w * src_h) return;
    var row: u32 = 0;
    while (row < src_h) : (row += 1) {
        var col: u32 = 0;
        while (col < src_w) : (col += 1) {
            const px = pixels[row * src_w + col];
            if (px == 0) continue;
            const rgb24 = px & 0xFFFFFF;
            fillRectScreen(dx + @as(i32, @intCast(col)), dy + @as(i32, @intCast(row)), 1, 1, rgb24);
        }
    }
}

/// 最近邻放大 blit（如 16×16 → 32×32）。
pub fn blitArgb32Scaled(dx: i32, dy: i32, src_w: u32, src_h: u32, scale: u32, pixels: []const u32) void {
    if (scale < 1) return;
    var row: u32 = 0;
    while (row < src_h) : (row += 1) {
        var col: u32 = 0;
        while (col < src_w) : (col += 1) {
            const px = pixels[row * src_w + col];
            if (px == 0) continue;
            const rgb24 = px & 0xFFFFFF;
            const ox = dx + @as(i32, @intCast(col * scale));
            const oy = dy + @as(i32, @intCast(row * scale));
            fillRectScreen(ox, oy, @intCast(scale), @intCast(scale), rgb24);
        }
    }
}

/// 经典凸起按钮（1px 亮边左上 + 暗边右下）。
pub fn fill3dRaised(x: i32, y: i32, w: i32, h: i32, face: u32, hi: u32, lo: u32) void {
    if (w <= 2 or h <= 2) return;
    fillRectScreen(x, y, w, h, face);
    fillRectScreen(x, y, w, 1, hi);
    fillRectScreen(x, y, 1, h, hi);
    fillRectScreen(x, y + h - 1, w, 1, lo);
    fillRectScreen(x + w - 1, y, 1, h, lo);
}

/// 凹陷区域（托盘 / 快速启动槽）。
pub fn fill3dSunken(x: i32, y: i32, w: i32, h: i32, face: u32, hi: u32, lo: u32) void {
    if (w <= 2 or h <= 2) return;
    fillRectScreen(x, y, w, h, face);
    fillRectScreen(x, y, w, 1, lo);
    fillRectScreen(x, y, 1, h, lo);
    fillRectScreen(x, y + h - 1, w, 1, hi);
    fillRectScreen(x + w - 1, y, 1, h, hi);
}

/// 设备无关 BitBlt：当前实现为同缓冲 no-op（占位）。
pub fn bitBlt(_: DcHandle, _: i32, _: i32, _: i32, _: i32, _: DcHandle, _: i32, _: i32, _: u32) void {}

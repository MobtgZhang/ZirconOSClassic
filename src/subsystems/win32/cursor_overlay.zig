//! 软件鼠标：保存光标下像素、移动后恢复再绘制（热点左上角）。

const fb = @import("../../hal/fb_console.zig");
const res = @import("../../classic/resources/mod.zig");
const icons = @import("../../classic/resources/icons.zig");

const CW = icons.cursor_w;
const CH = icons.cursor_h;

var saved: [CW * CH]u32 = undefined;
var save_valid: bool = false;
var last_cx: i32 = -1;
var last_cy: i32 = -1;

/// 任意 WM_PAINT 前调用：先把上一帧光标下的像素写回帧缓冲，再丢弃保存区（避免任务栏局部重绘留下光标鬼影）。
pub fn markFramebufferDirty() void {
    restoreUnderCursor();
    save_valid = false;
}

fn restoreUnderCursor() void {
    if (!save_valid or !fb.isReady()) return;
    var yy: usize = 0;
    while (yy < CH) : (yy += 1) {
        var xx: usize = 0;
        while (xx < CW) : (xx += 1) {
            const px = last_cx + @as(i32, @intCast(xx));
            const py = last_cy + @as(i32, @intCast(yy));
            if (px < 0 or py < 0) continue;
            const ux: usize = @intCast(px);
            const uy: usize = @intCast(py);
            fb.putPixel(ux, uy, saved[yy * CW + xx]);
        }
    }
}

fn saveUnderCursor(cx: i32, cy: i32) void {
    if (!fb.isReady()) return;
    var yy: usize = 0;
    while (yy < CH) : (yy += 1) {
        var xx: usize = 0;
        while (xx < CW) : (xx += 1) {
            const px = cx + @as(i32, @intCast(xx));
            const py = cy + @as(i32, @intCast(yy));
            var v: u32 = 0;
            if (px >= 0 and py >= 0) {
                const ux: usize = @intCast(px);
                const uy: usize = @intCast(py);
                if (ux < fb.screenWidth() and uy < fb.screenHeight()) {
                    v = fb.getPackedRgbAt(ux, uy);
                }
            }
            saved[yy * CW + xx] = v;
        }
    }
    last_cx = cx;
    last_cy = cy;
    save_valid = true;
}

fn drawSprite(cx: i32, cy: i32) void {
    var yy: usize = 0;
    while (yy < CH) : (yy += 1) {
        var xx: usize = 0;
        while (xx < CW) : (xx += 1) {
            const px = res.cursor_arrow[yy * CW + xx];
            if (px == 0) continue;
            const sx = cx + @as(i32, @intCast(xx));
            const sy = cy + @as(i32, @intCast(yy));
            if (sx < 0 or sy < 0) continue;
            const ux: usize = @intCast(sx);
            const uy: usize = @intCast(sy);
            if (ux < fb.screenWidth() and uy < fb.screenHeight()) {
                fb.putPixelXrgbOpaque(ux, uy, px & 0xFFFFFF);
            }
        }
    }
}

pub fn present(mx: i32, my: i32) void {
    if (!fb.isReady()) return;
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    const cx = @max(0, @min(mx, sw - @as(i32, @intCast(CW))));
    const cy = @max(0, @min(my, sh - @as(i32, @intCast(CH))));

    if (save_valid and cx == last_cx and cy == last_cy) return;

    restoreUnderCursor();
    saveUnderCursor(cx, cy);
    drawSprite(cx, cy);
}

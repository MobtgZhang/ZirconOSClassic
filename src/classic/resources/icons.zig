//! ZirconOS Classic 原创 16×16 图标（ARGB，A=0xFF 不透明，0x00000000 透明），经 GRE 放大绘制。
//! GDI/光标精灵：仅 `0x00000000` 为洞；可见色可为 `0x00RRGGBB`（与 `classic.rgb` 一致）。

const T: u32 = 0x00000000;
const classic = @import("../colors.zig");

inline fn o(r: u32, g: u32, b: u32) u32 {
    return 0xFF000000 | (r << 16) | (g << 8) | b;
}

fn i(x: u32, y: u32) usize {
    return @intCast(y * 16 + x);
}

pub const icon_src: u32 = 16;

pub fn my_documents() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            if (y >= 3 and y <= 5 and x >= 5 and x <= 12) b[k] = o(0xDD, 0xBB, 0x00);
            if (y >= 6 and y <= 12 and x >= 3 and x <= 13) {
                if (y <= 7) {
                    b[k] = o(0xEE, 0xCC, 0x11);
                } else if (y <= 10) {
                    b[k] = o(0xFF, 0xDD, 0x33);
                } else {
                    b[k] = o(0xCC, 0xAA, 0x00);
                }
            }
        }
    }
    var dy: u32 = 7;
    while (dy <= 10) : (dy += 1) {
        var dx: u32 = 6;
        while (dx <= 10) : (dx += 1) {
            b[i(dx, dy)] = o(0xF8, 0xF8, 0xFA);
        }
    }
    b[i(6, 7)] = o(0xD0, 0xD0, 0xD8);
    b[i(7, 8)] = o(0xC8, 0xC8, 0xD0);
    return b;
}

pub fn my_computer() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            if (y >= 3 and y <= 4 and x >= 4 and x <= 11) b[k] = o(0x50, 0x90, 0xD0);
            if (y >= 5 and y <= 10 and x >= 4 and x <= 11) b[k] = o(0xB8, 0xB8, 0xC0);
            if (y == 5 and x >= 4 and x <= 11) b[k] = o(0x40, 0x70, 0xA8);
            if (y >= 11 and y <= 12 and x >= 6 and x <= 9) b[k] = o(0x70, 0x58, 0x40);
            if (y == 13 and x >= 5 and x <= 10) b[k] = o(0x50, 0x40, 0x30);
        }
    }
    b[i(6, 7)] = o(0x88, 0xA8, 0xD0);
    b[i(9, 8)] = o(0x70, 0x98, 0xC8);
    return b;
}

pub fn network_places() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            if (y >= 3 and y <= 7 and x >= 2 and x <= 6) {
                if (y <= 4 and x >= 3 and x <= 5) {
                    b[k] = o(0x70, 0xA0, 0xE8);
                } else {
                    b[k] = o(0x90, 0x90, 0x98);
                }
            }
            if (y >= 3 and y <= 7 and x >= 9 and x <= 13) {
                if (y <= 4 and x >= 10 and x <= 12) {
                    b[k] = o(0x70, 0xA0, 0xE8);
                } else {
                    b[k] = o(0x90, 0x90, 0x98);
                }
            }
        }
    }
    var lx: u32 = 4;
    while (lx <= 11) : (lx += 1) {
        b[i(lx, 9)] = o(0x00, 0x90, 0x30);
    }
    b[i(3, 10)] = o(0x00, 0x70, 0x20);
    b[i(12, 10)] = o(0x00, 0x70, 0x20);
    return b;
}

pub fn recycle_bin() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            if (y == 3 and x >= 4 and x <= 11) b[k] = o(0xA8, 0xA8, 0xB0);
            if (y >= 4 and y <= 11 and x >= 4 and x <= 11) b[k] = o(0x88, 0x88, 0x94);
            if (y >= 5 and y <= 9 and x >= 6 and x <= 9) b[k] = o(0x50, 0x70, 0xC8);
        }
    }
    return b;
}

pub fn internet_explorer() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    const cx: f32 = 7.5;
    const cy: f32 = 7.5;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            const dx = @as(f32, @floatFromInt(x)) + 0.5 - cx;
            const dy = @as(f32, @floatFromInt(y)) + 0.5 - cy;
            if (dx * dx + dy * dy <= 30.0) b[k] = o(0x00, 0x70, 0xE8);
            if (dx * dx + dy * dy <= 22.0) b[k] = o(0x20, 0x98, 0xF0);
        }
    }
    var sx: u32 = 9;
    while (sx <= 13) : (sx += 1) {
        b[i(sx, 3)] = o(0xE8, 0xC0, 0x20);
    }
    b[i(11, 4)] = o(0xD8, 0xA8, 0x10);
    b[i(12, 5)] = o(0xC8, 0x90, 0x08);
    b[i(13, 6)] = o(0xB8, 0x80, 0x00);
    return b;
}

pub fn connect_internet() [256]u32 {
    var b: [256]u32 = [_]u32{T} ** 256;
    var y: u32 = 0;
    while (y < 16) : (y += 1) {
        var x: u32 = 0;
        while (x < 16) : (x += 1) {
            const k = i(x, y);
            if (y >= 3 and y <= 8 and x >= 3 and x <= 9) b[k] = o(0xC0, 0xC0, 0xC8);
            if (y >= 4 and y <= 6 and x >= 4 and x <= 8) b[k] = o(0x40, 0xA0, 0xE8);
        }
    }
    const gcx: f32 = 11.0;
    const gcy: f32 = 10.0;
    var gy: u32 = 6;
    while (gy < 14) : (gy += 1) {
        var gx: u32 = 7;
        while (gx < 15) : (gx += 1) {
            const k = i(gx, gy);
            const dx = @as(f32, @floatFromInt(gx)) - gcx;
            const dy = @as(f32, @floatFromInt(gy)) - gcy;
            if (dx * dx + dy * dy <= 10.0) b[k] = o(0x00, 0xC0, 0x80);
            if (dx * dx + dy * dy <= 5.0) b[k] = o(0x40, 0xE0, 0xA0);
        }
    }
    b[i(2, 12)] = o(0xFF, 0xFF, 0xFF);
    b[i(3, 12)] = o(0x20, 0x20, 0x28);
    return b;
}

pub fn make_arrow_cursor() [176]u32 {
    // 0=洞 1=白填充 2=黑描边（箭头光标）；描边不可为 0，否则 cursor_overlay 当作透明洞跳过。
    const fill = classic.rgb(0xFF, 0xFF, 0xFF);
    const edge = classic.rgb(0x00, 0x00, 0x01);
    const raw: [176]u8 = .{
        2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0,
        2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0,
        2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0,
        2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0,
        2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0,
        2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0,
        2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0,
        2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1,
        2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1,
        2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1,
        2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2,
        2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1,
        2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1,
        2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    };
    var out: [176]u32 = undefined;
    for (&out, raw) |*dst, cell| {
        dst.* = switch (cell) {
            0 => T,
            1 => fill,
            2 => edge,
            else => T,
        };
    }
    return out;
}

pub const cursor_w: usize = 11;
pub const cursor_h: usize = 16;

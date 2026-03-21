//! Renderer - ZirconOS Classic Rendering Abstraction Layer
//! Provides a platform-independent drawing interface for Windows 2000
//! GDI-style rendering: flat solid fills, 3D beveled borders (raised/sunken),
//! horizontal/vertical gradient titlebars, and standard text rendering.
//! No glass, no blur, no rounded corners, no alpha blending.

const theme = @import("theme.zig");

pub const COLORREF = theme.COLORREF;

pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    pub fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.w and
            py >= self.y and py < self.y + self.h;
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.w and
            self.x + self.w > other.x and
            self.y < other.y + other.h and
            self.y + self.h > other.y;
    }

    pub fn intersection(self: Rect, other: Rect) Rect {
        const x1 = @max(self.x, other.x);
        const y1 = @max(self.y, other.y);
        const x2 = @min(self.x + self.w, other.x + other.w);
        const y2 = @min(self.y + self.h, other.y + other.h);
        if (x2 <= x1 or y2 <= y1) return .{};
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn union_(self: Rect, other: Rect) Rect {
        if (self.w == 0 or self.h == 0) return other;
        if (other.w == 0 or other.h == 0) return self;
        const x1 = @min(self.x, other.x);
        const y1 = @min(self.y, other.y);
        const x2 = @max(self.x + self.w, other.x + other.w);
        const y2 = @max(self.y + self.h, other.y + other.h);
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn isEmpty(self: Rect) bool {
        return self.w <= 0 or self.h <= 0;
    }

    pub fn offset(self: Rect, dx: i32, dy: i32) Rect {
        return .{ .x = self.x + dx, .y = self.y + dy, .w = self.w, .h = self.h };
    }

    pub fn inset(self: Rect, d: i32) Rect {
        return .{
            .x = self.x + d,
            .y = self.y + d,
            .w = @max(self.w - d * 2, 0),
            .h = @max(self.h - d * 2, 0),
        };
    }
};

pub const Point = struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub const Size = struct {
    w: i32 = 0,
    h: i32 = 0,
};

pub const TextAlignment = enum(u8) {
    left = 0,
    center = 1,
    right = 2,
};

pub const FontWeight = enum(u8) {
    normal = 0,
    bold = 1,
};

pub const FontSpec = struct {
    name: []const u8 = theme.FONT_SYSTEM,
    size: i32 = theme.FONT_SYSTEM_SIZE,
    weight: FontWeight = .normal,
};

pub const GradientDirection = enum(u8) {
    horizontal = 0,
    vertical = 1,
};

pub const RenderOps = struct {
    fill_rect: ?*const fn (rect: Rect, color: COLORREF) void = null,
    draw_rect: ?*const fn (rect: Rect, color: COLORREF, width: i32) void = null,
    draw_line: ?*const fn (x1: i32, y1: i32, x2: i32, y2: i32, color: COLORREF) void = null,
    draw_gradient: ?*const fn (rect: Rect, start: COLORREF, end: COLORREF, dir: GradientDirection) void = null,
    draw_text: ?*const fn (text: []const u8, rect: Rect, color: COLORREF, font: FontSpec, alignment: TextAlignment) void = null,
    draw_icon: ?*const fn (icon_id: u32, x: i32, y: i32, size: i32) void = null,
    draw_bitmap: ?*const fn (bitmap_id: u32, dest: Rect) void = null,
    set_clip: ?*const fn (rect: Rect) void = null,
    clear_clip: ?*const fn () void = null,
    blit_surface: ?*const fn (surface_id: u32, dest: Rect, alpha: u8) void = null,
    flush: ?*const fn () void = null,
};

var render_ops: RenderOps = .{};

pub fn setRenderOps(ops: RenderOps) void {
    render_ops = ops;
}

pub fn getRenderOps() *const RenderOps {
    return &render_ops;
}

pub fn fillRect(rect: Rect, color: COLORREF) void {
    if (render_ops.fill_rect) |f| f(rect, color);
}

pub fn drawRect(rect: Rect, color: COLORREF, width: i32) void {
    if (render_ops.draw_rect) |f| f(rect, color, width);
}

pub fn drawLine(x1: i32, y1: i32, x2: i32, y2: i32, color: COLORREF) void {
    if (render_ops.draw_line) |f| f(x1, y1, x2, y2, color);
}

pub fn drawGradient(rect: Rect, start: COLORREF, end: COLORREF, dir: GradientDirection) void {
    if (render_ops.draw_gradient) |f| f(rect, start, end, dir);
}

pub fn drawText(text: []const u8, rect: Rect, color: COLORREF, font: FontSpec, alignment: TextAlignment) void {
    if (render_ops.draw_text) |f| f(text, rect, color, font, alignment);
}

pub fn drawIcon(icon_id: u32, x: i32, y: i32, size: i32) void {
    if (render_ops.draw_icon) |f| f(icon_id, x, y, size);
}

pub fn drawBitmap(bitmap_id: u32, dest: Rect) void {
    if (render_ops.draw_bitmap) |f| f(bitmap_id, dest);
}

pub fn setClip(rect: Rect) void {
    if (render_ops.set_clip) |f| f(rect);
}

pub fn clearClip() void {
    if (render_ops.clear_clip) |f| f();
}

pub fn blitSurface(surface_id: u32, dest: Rect, alpha: u8) void {
    if (render_ops.blit_surface) |f| f(surface_id, dest, alpha);
}

pub fn flushRender() void {
    if (render_ops.flush) |f| f();
}

pub fn drawHGradient(rect: Rect, start_color: COLORREF, end_color: COLORREF) void {
    drawGradient(rect, start_color, end_color, .horizontal);
}

pub fn drawVGradient(rect: Rect, start_color: COLORREF, end_color: COLORREF) void {
    drawGradient(rect, start_color, end_color, .vertical);
}

/// Classic 3D beveled frame (raised or sunken).
/// Raised: white top-left, dark shadow bottom-right.
/// Sunken: dark top-left, white bottom-right.
pub fn draw3DFrame(rect: Rect, raised: bool) void {
    const colors = theme.getColors();
    const light = if (raised) colors.button_highlight_c else colors.button_shadow_c;
    const dark = if (raised) colors.button_shadow_c else colors.button_highlight_c;
    drawLine(rect.x, rect.y, rect.x + rect.w - 1, rect.y, light);
    drawLine(rect.x, rect.y, rect.x, rect.y + rect.h - 1, light);
    drawLine(rect.x + rect.w - 1, rect.y, rect.x + rect.w - 1, rect.y + rect.h - 1, dark);
    drawLine(rect.x, rect.y + rect.h - 1, rect.x + rect.w - 1, rect.y + rect.h - 1, dark);
}

/// Double 3D beveled frame for window borders:
/// outer highlight + inner highlight on top-left,
/// outer dark shadow + inner shadow on bottom-right.
pub fn draw3DFrameDouble(rect: Rect, raised: bool) void {
    draw3DFrame(rect, raised);
    const inner = rect.inset(1);
    const sc = theme.getActiveColors();
    const inner_light = if (raised) sc.button_face else sc.button_dark_shadow;
    const inner_dark = if (raised) sc.button_dark_shadow else sc.button_face;
    drawLine(inner.x, inner.y, inner.x + inner.w - 1, inner.y, inner_light);
    drawLine(inner.x, inner.y, inner.x, inner.y + inner.h - 1, inner_light);
    drawLine(inner.x + inner.w - 1, inner.y, inner.x + inner.w - 1, inner.y + inner.h - 1, inner_dark);
    drawLine(inner.x, inner.y + inner.h - 1, inner.x + inner.w - 1, inner.y + inner.h - 1, inner_dark);
}

/// Render Classic titlebar: horizontal gradient from active color to lighter shade
pub fn renderClassicTitlebar(rect: Rect, active: bool) void {
    const sc = theme.getActiveColors();
    if (active) {
        drawHGradient(rect, sc.titlebar_active, sc.titlebar_active_right);
    } else {
        drawHGradient(rect, sc.titlebar_inactive, sc.titlebar_inactive_right);
    }
}

/// Render desktop background as solid color fill
pub fn renderDesktopBackground(rect: Rect) void {
    fillRect(rect, theme.getColors().desktop_background);
}

/// Render Classic taskbar: flat grey with top highlight edge
pub fn renderClassicTaskbar(rect: Rect) void {
    fillRect(rect, theme.taskbar_bg);
    const edge = Rect{ .x = rect.x, .y = rect.y, .w = rect.w, .h = 1 };
    fillRect(edge, theme.taskbar_top_highlight);
}

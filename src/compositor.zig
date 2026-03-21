//! Compositor - ZirconOS Classic GDI Surface Manager
//! Basic compositing engine for the Classic (Windows 2000) theme.
//! No alpha blending, no glass transparency, no blur effects.
//! Surfaces are opaque and rendered back-to-front by Z-order.
//! This is a minimal GDI-compatible compositor: each surface is
//! a rectangular off-screen buffer blitted directly to the front
//! buffer with no per-pixel operations.

const theme = @import("theme.zig");
const renderer = @import("renderer.zig");

pub const Rect = renderer.Rect;
pub const COLORREF = theme.COLORREF;

pub const MAX_SURFACES: usize = 64;
pub const MAX_DAMAGE_RECTS: usize = 16;
pub const INVALID_SURFACE: u32 = 0;

pub const CURSOR_SURFACE_Z: i32 = 0x7FFFFF00;
pub const DESKTOP_SURFACE_Z: i32 = -0x7FFFFF00;

pub const SurfaceFlags = struct {
    has_alpha: bool = false,
    is_visible: bool = true,
    is_cursor: bool = false,
    is_desktop: bool = false,
};

pub const Surface = struct {
    id: u32 = INVALID_SURFACE,
    width: u32 = 0,
    height: u32 = 0,
    flags: SurfaceFlags = .{},
    dirty: bool = true,
    damage_rects: [MAX_DAMAGE_RECTS]Rect = [_]Rect{.{}} ** MAX_DAMAGE_RECTS,
    damage_count: usize = 0,
    z_order: i32 = 0,
    x: i32 = 0,
    y: i32 = 0,

    pub fn markDirty(self: *Surface, rect: Rect) void {
        if (self.damage_count < MAX_DAMAGE_RECTS) {
            self.damage_rects[self.damage_count] = rect;
            self.damage_count += 1;
        }
        self.dirty = true;
    }

    pub fn markFullDirty(self: *Surface) void {
        self.damage_count = 0;
        self.dirty = true;
    }

    pub fn clearDamage(self: *Surface) void {
        self.damage_count = 0;
        self.dirty = false;
    }

    pub fn getBounds(self: *const Surface) Rect {
        return .{
            .x = self.x,
            .y = self.y,
            .w = @intCast(self.width),
            .h = @intCast(self.height),
        };
    }

    pub fn getDamageBounds(self: *const Surface) Rect {
        if (self.damage_count == 0) return self.getBounds();
        var result = self.damage_rects[0];
        for (self.damage_rects[1..self.damage_count]) |r| {
            result = result.union_(r);
        }
        return result.offset(self.x, self.y);
    }
};

pub const CompositorStats = struct {
    total_frames: u64 = 0,
    dirty_frames: u64 = 0,
    surfaces_composited: u64 = 0,
    full_redraws: u64 = 0,
    partial_redraws: u64 = 0,
};

pub const CursorLayer = struct {
    x: i32 = 0,
    y: i32 = 0,
    prev_x: i32 = -1,
    prev_y: i32 = -1,
    width: i32 = 12,
    height: i32 = 19,
    visible: bool = true,
    surface_id: u32 = INVALID_SURFACE,
    needs_redraw: bool = true,
};

var surfaces: [MAX_SURFACES]Surface = [_]Surface{.{}} ** MAX_SURFACES;
var surface_count: usize = 0;
var next_surface_id: u32 = 1;

var screen_width: u32 = 0;
var screen_height: u32 = 0;
var compositor_dirty: bool = true;
var stats: CompositorStats = .{};
var compositor_initialized: bool = false;

var cursor_layer: CursorLayer = .{};

pub fn init(width: u32, height: u32) void {
    screen_width = width;
    screen_height = height;
    surface_count = 0;
    next_surface_id = 1;
    compositor_dirty = true;
    stats = .{};
    cursor_layer = .{};

    cursor_layer.surface_id = createSurface(12, 19, .{
        .is_visible = true,
        .is_cursor = true,
    });
    if (getSurface(cursor_layer.surface_id)) |sfc| {
        sfc.z_order = CURSOR_SURFACE_Z;
    }

    compositor_initialized = true;
}

pub fn createSurface(width: u32, height: u32, flags: SurfaceFlags) u32 {
    if (surface_count >= MAX_SURFACES) return INVALID_SURFACE;

    const id = next_surface_id;
    next_surface_id += 1;

    var sfc = &surfaces[surface_count];
    sfc.* = .{};
    sfc.id = id;
    sfc.width = width;
    sfc.height = height;
    sfc.flags = flags;
    sfc.dirty = true;

    surface_count += 1;
    compositor_dirty = true;
    return id;
}

pub fn destroySurface(id: u32) bool {
    if (id == cursor_layer.surface_id) return false;

    var i: usize = 0;
    while (i < surface_count) {
        if (surfaces[i].id == id) {
            var j = i;
            while (j + 1 < surface_count) : (j += 1) {
                surfaces[j] = surfaces[j + 1];
            }
            surfaces[surface_count - 1] = .{};
            surface_count -= 1;
            compositor_dirty = true;
            return true;
        }
        i += 1;
    }
    return false;
}

pub fn getSurface(id: u32) ?*Surface {
    for (surfaces[0..surface_count]) |*sfc| {
        if (sfc.id == id) return sfc;
    }
    return null;
}

pub fn moveSurface(id: u32, x: i32, y: i32) void {
    if (getSurface(id)) |sfc| {
        sfc.x = x;
        sfc.y = y;
        sfc.markFullDirty();
        compositor_dirty = true;
    }
}

pub fn resizeSurface(id: u32, width: u32, height: u32) void {
    if (getSurface(id)) |sfc| {
        sfc.width = width;
        sfc.height = height;
        sfc.markFullDirty();
        compositor_dirty = true;
    }
}

pub fn setSurfaceZOrder(id: u32, z: i32) void {
    if (getSurface(id)) |sfc| {
        sfc.z_order = z;
        compositor_dirty = true;
    }
}

pub fn setSurfaceVisible(id: u32, vis: bool) void {
    if (getSurface(id)) |sfc| {
        sfc.flags.is_visible = vis;
        compositor_dirty = true;
    }
}

pub fn updateCursorPosition(x: i32, y: i32) void {
    if (x == cursor_layer.x and y == cursor_layer.y) return;

    cursor_layer.prev_x = cursor_layer.x;
    cursor_layer.prev_y = cursor_layer.y;
    cursor_layer.x = x;
    cursor_layer.y = y;
    cursor_layer.needs_redraw = true;

    if (getSurface(cursor_layer.surface_id)) |sfc| {
        sfc.x = x;
        sfc.y = y;
        sfc.markFullDirty();
    }
}

pub fn setCursorVisible(vis: bool) void {
    cursor_layer.visible = vis;
    if (getSurface(cursor_layer.surface_id)) |sfc| {
        sfc.flags.is_visible = vis;
    }
    compositor_dirty = true;
}

pub fn getCursorPosition() struct { x: i32, y: i32 } {
    return .{ .x = cursor_layer.x, .y = cursor_layer.y };
}

pub fn compose() void {
    if (!compositor_initialized) return;

    stats.total_frames += 1;

    if (!needsRedraw()) return;
    stats.dirty_frames += 1;

    sortSurfacesByZOrder();

    const screen_rect = Rect{
        .x = 0,
        .y = 0,
        .w = @intCast(screen_width),
        .h = @intCast(screen_height),
    };

    stats.full_redraws += 1;
    composeFull(screen_rect);

    for (surfaces[0..surface_count]) |*sfc| {
        sfc.clearDamage();
    }
    compositor_dirty = false;
    cursor_layer.needs_redraw = false;

    renderer.flushRender();
}

fn composeFull(screen_rect: Rect) void {
    renderer.fillRect(screen_rect, theme.getColors().desktop_background);

    for (surfaces[0..surface_count]) |*sfc| {
        if (!sfc.flags.is_visible) continue;
        composeSurface(sfc);
        stats.surfaces_composited += 1;
    }
}

fn composeSurface(sfc: *const Surface) void {
    const bounds = sfc.getBounds();
    renderer.blitSurface(sfc.id, bounds, 255);
}

fn needsRedraw() bool {
    if (compositor_dirty) return true;
    if (cursor_layer.needs_redraw) return true;
    for (surfaces[0..surface_count]) |*sfc| {
        if (sfc.dirty) return true;
    }
    return false;
}

fn sortSurfacesByZOrder() void {
    var i: usize = 0;
    while (i + 1 < surface_count) : (i += 1) {
        var j: usize = 0;
        while (j + 1 < surface_count - i) : (j += 1) {
            if (surfaces[j].z_order > surfaces[j + 1].z_order) {
                const tmp = surfaces[j];
                surfaces[j] = surfaces[j + 1];
                surfaces[j + 1] = tmp;
            }
        }
    }
}

pub fn getStats() CompositorStats {
    return stats;
}

pub fn getSurfaceCount() usize {
    return surface_count;
}

pub fn getScreenSize() struct { w: u32, h: u32 } {
    return .{ .w = screen_width, .h = screen_height };
}

pub fn setScreenSize(width: u32, height: u32) void {
    screen_width = width;
    screen_height = height;
    compositor_dirty = true;
}

pub fn markAllDirty() void {
    for (surfaces[0..surface_count]) |*sfc| {
        sfc.markFullDirty();
    }
    compositor_dirty = true;
}

pub fn getCursorLayer() *const CursorLayer {
    return &cursor_layer;
}

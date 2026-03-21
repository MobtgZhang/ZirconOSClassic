//! Classic Cursor Module
//! Provides cursor state management and the Windows 2000 standard
//! arrow cursor bitmap.
//!
//! Classic cursor: no smooth interpolation, no sub-pixel positioning.
//! Direct 1:1 pixel mapping from raw input to display position.

const theme = @import("theme.zig");

pub const CursorState = struct {
    x: i32 = 0,
    y: i32 = 0,
    prev_x: i32 = -1,
    prev_y: i32 = -1,
    is_moving: bool = false,

    pub fn update(self: *CursorState, raw_x: i32, raw_y: i32, scr_w: i32, scr_h: i32) void {
        self.prev_x = self.x;
        self.prev_y = self.y;

        self.x = raw_x;
        self.y = raw_y;

        if (self.x < 0) self.x = 0;
        if (self.y < 0) self.y = 0;
        if (self.x >= scr_w) self.x = scr_w - 1;
        if (self.y >= scr_h) self.y = scr_h - 1;

        self.is_moving = (self.x != self.prev_x or self.y != self.prev_y);
    }

    pub fn positionChanged(self: *const CursorState) bool {
        return self.x != self.prev_x or self.y != self.prev_y;
    }

    pub fn snapTo(self: *CursorState, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
        self.prev_x = x;
        self.prev_y = y;
        self.is_moving = false;
    }
};

pub const CURSOR_W: usize = 12;
pub const CURSOR_H: usize = 19;

// 0=transparent, 1=white(fill), 2=black(outline)
pub const classic_cursor_bitmap = [CURSOR_H][CURSOR_W]u2{
    .{ 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 1, 1, 1, 2, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 1, 1, 1, 1, 2, 0, 0, 0, 0 },
    .{ 2, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0, 0 },
    .{ 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0 },
    .{ 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0 },
    .{ 2, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 0 },
    .{ 2, 1, 1, 1, 2, 1, 2, 0, 0, 0, 0, 0 },
    .{ 2, 1, 1, 2, 0, 2, 1, 2, 0, 0, 0, 0 },
    .{ 2, 1, 2, 0, 0, 2, 1, 2, 0, 0, 0, 0 },
    .{ 2, 2, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
};

//! Classic UI Controls
//! Windows 2000 styled UI primitives: flat 3D beveled buttons,
//! sunken text fields, flat checkboxes, and chunky progress bars.
//! No gradients, no rounded corners, no glow effects.

const theme = @import("theme.zig");

pub const ControlState = enum {
    rest,
    hover,
    pressed,
    disabled,
};

pub const Button = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 75,
    height: i32 = 23,
    label: [32]u8 = [_]u8{0} ** 32,
    label_len: u8 = 0,
    state: ControlState = .rest,
    is_default: bool = false,

    pub fn getBackgroundColor(_: *const Button) u32 {
        return theme.button_face;
    }

    pub fn getTextColor(self: *const Button) u32 {
        return if (self.state == .disabled)
            theme.button_shadow
        else
            theme.rgb(0x00, 0x00, 0x00);
    }

    pub fn isRaised(self: *const Button) bool {
        return self.state != .pressed;
    }

    pub fn contains(self: *const Button, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.width and
            py >= self.y and py < self.y + self.height;
    }
};

pub const TextBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 140,
    height: i32 = 21,
    text: [256]u8 = [_]u8{0} ** 256,
    text_len: u16 = 0,
    focused: bool = false,

    pub fn getBackgroundColor(_: *const TextBox) u32 {
        return theme.window_bg;
    }

    pub fn getBorderHighlight(_: *const TextBox) u32 {
        return theme.button_shadow;
    }

    pub fn getBorderShadow(_: *const TextBox) u32 {
        return theme.button_highlight;
    }
};

pub const CheckBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    checked: bool = false,
    state: ControlState = .rest,

    pub fn getBoxColor(_: *const CheckBox) u32 {
        return theme.window_bg;
    }

    pub fn getBorderColor(_: *const CheckBox) u32 {
        return theme.button_shadow;
    }

    pub fn getCheckColor(_: *const CheckBox) u32 {
        return theme.rgb(0x00, 0x00, 0x00);
    }
};

pub const ProgressBar = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 200,
    height: i32 = 16,
    progress: u8 = 0,

    pub fn getFilledColor(_: *const ProgressBar) u32 {
        return theme.selection_bg;
    }

    pub fn getTrackColor(_: *const ProgressBar) u32 {
        return theme.window_bg;
    }

    pub fn getFilledWidth(self: *const ProgressBar) i32 {
        return @divTrunc(self.width * @as(i32, self.progress), 100);
    }
};

pub const GroupBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 200,
    height: i32 = 100,
    label: [32]u8 = [_]u8{0} ** 32,
    label_len: u8 = 0,

    pub fn getBorderColor(_: *const GroupBox) u32 {
        return theme.button_shadow;
    }

    pub fn getLabelColor(_: *const GroupBox) u32 {
        return theme.rgb(0x00, 0x00, 0x00);
    }
};

//! AArch64 帧缓冲 — 实现见 `hal/fb_console.zig`。
const impl = @import("../fb_console.zig");

pub const init = impl.init;
pub const initEx = impl.initEx;
pub const clear = impl.clear;
pub const write = impl.write;
pub const fillRect = impl.fillRect;
pub const screenWidth = impl.screenWidth;
pub const screenHeight = impl.screenHeight;
pub const setTextColors = impl.setTextColors;
pub const isReady = impl.isReady;
pub const setConsoleEnabled = impl.setConsoleEnabled;
pub const isConsoleEnabled = impl.isConsoleEnabled;

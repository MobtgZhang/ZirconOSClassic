//! 桌面 GRE 指针输入薄封装：统一 `desktop_session` 内对 PS/2 与 VirtIO-input 的轮询与读坐标。
//! 行为对齐 Linux evdev / QEMU virtio-input；**不含**微软 WDK 或 Windows 驱动示例代码。

const builtin = @import("builtin");
const fb = @import("../../hal/fb_console.zig");

pub const Point = struct {
    x: i32,
    y: i32,
};

pub fn poll() void {
    switch (builtin.target.cpu.arch) {
        .x86_64 => @import("../../hal/x86_64/ps2_mouse.zig").poll(),
        .loongarch64 => @import("../../hal/loongarch64/virtio_hid.zig").Input.poll(),
        else => {},
    }
}

pub fn consumeMoved() bool {
    return switch (builtin.target.cpu.arch) {
        .x86_64 => @import("../../hal/x86_64/ps2_mouse.zig").consumeMoved(),
        .loongarch64 => @import("../../hal/loongarch64/virtio_hid.zig").Input.consumeMoved(),
        else => false,
    };
}

/// 读当前逻辑指针坐标；LoongArch 在读前夹紧到当前 `fb_console` 尺寸（与分辨率切换一致）。
pub fn clampedPosition() Point {
    if (builtin.target.cpu.arch == .x86_64) {
        const ps2 = @import("../../hal/x86_64/ps2_mouse.zig");
        return .{ .x = ps2.pos_x, .y = ps2.pos_y };
    }
    if (builtin.target.cpu.arch == .loongarch64) {
        const H = @import("../../hal/loongarch64/virtio_hid.zig").Input;
        H.clampPointerPosition();
        return .{ .x = H.pos_x, .y = H.pos_y };
    }
    if (!fb.isReady()) return .{ .x = 0, .y = 0 };
    return .{
        .x = @as(i32, @intCast(fb.screenWidth() / 2)),
        .y = @as(i32, @intCast(fb.screenHeight() / 2)),
    };
}

pub fn leftPressedEdge() bool {
    return switch (builtin.target.cpu.arch) {
        .x86_64 => @import("../../hal/x86_64/ps2_mouse.zig").leftPressedEdge(),
        .loongarch64 => @import("../../hal/loongarch64/virtio_hid.zig").Input.leftPressedEdge(),
        else => false,
    };
}

pub fn rightPressedEdge() bool {
    return switch (builtin.target.cpu.arch) {
        .x86_64 => @import("../../hal/x86_64/ps2_mouse.zig").rightPressedEdge(),
        .loongarch64 => @import("../../hal/loongarch64/virtio_hid.zig").Input.rightPressedEdge(),
        else => false,
    };
}

pub fn btnLeft() bool {
    return switch (builtin.target.cpu.arch) {
        .x86_64 => @import("../../hal/x86_64/ps2_mouse.zig").btn_left,
        .loongarch64 => @import("../../hal/loongarch64/virtio_hid.zig").Input.btn_left,
        else => false,
    };
}

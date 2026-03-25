//! PS/2 鼠标（8042 AUX + IRQ12）。QEMU 默认 `-device ps2-mouse` 可用。

const portio = @import("portio.zig");
const pic = @import("pic.zig");
const klog = @import("../../rtl/klog.zig");

var packet: [3]u8 = .{ 0, 0, 0 };
var packet_idx: u8 = 0;

pub var pos_x: i32 = 400;
pub var pos_y: i32 = 300;
pub var btn_left: bool = false;
pub var btn_right: bool = false;
pub var btn_middle: bool = false;

var left_was_down: bool = false;
var right_was_down: bool = false;

pub var moved_since_frame: bool = false;

pub fn consumeMoved() bool {
    const m = moved_since_frame;
    moved_since_frame = false;
    return m;
}

pub fn leftPressedEdge() bool {
    const p = btn_left and !left_was_down;
    left_was_down = btn_left;
    return p;
}

pub fn rightPressedEdge() bool {
    const p = btn_right and !right_was_down;
    right_was_down = btn_right;
    return p;
}

/// 状态寄存器 0x64 bit5：辅助端口（鼠标）数据；勿在轮询里吃掉键盘字节。
fn isAuxData(st: u8) bool {
    return (st & 0x20) != 0;
}

fn waitWrite() void {
    var i: u32 = 0;
    while (i < 200000) : (i += 1) {
        if ((portio.inb(0x64) & 2) == 0) return;
    }
}

fn waitRead() void {
    var i: u32 = 0;
    while (i < 200000) : (i += 1) {
        if ((portio.inb(0x64) & 1) != 0) return;
    }
}

fn writeCmd(cmd: u8) void {
    waitWrite();
    portio.outb(0x64, cmd);
}

fn writeData(b: u8) void {
    waitWrite();
    portio.outb(0x60, b);
}

fn readData() u8 {
    waitRead();
    return portio.inb(0x60);
}

fn flushOutput() void {
    while ((portio.inb(0x64) & 1) != 0) {
        _ = portio.inb(0x60);
    }
}

/// 发送字节到辅助设备（鼠标）。
fn writeMouse(b: u8) void {
    waitWrite();
    portio.outb(0x64, 0xD4);
    waitWrite();
    portio.outb(0x60, b);
}

pub fn init() void {
    flushOutput();

    writeCmd(0xA8);
    writeCmd(0x20);
    var cfg = readData();
    cfg |= 2;
    cfg &= ~@as(u8, 0x20);
    writeCmd(0x60);
    writeData(cfg);

    writeMouse(0xF4);
    _ = readData();

    pic.unmaskIrq(1);
    pic.unmaskIrq(12);
    klog.info("PS/2: keyboard IRQ1 + mouse IRQ12 unmasked", .{});
}

fn applyPacket() void {
    const b0 = packet[0];
    const b1 = packet[1];
    const b2 = packet[2];
    if ((b0 & 8) == 0) return;

    btn_left = (b0 & 1) != 0;
    btn_right = (b0 & 2) != 0;
    btn_middle = (b0 & 4) != 0;

    const dx_i = @as(i32, @as(i8, @bitCast(b1)));
    const dy_i = @as(i32, @as(i8, @bitCast(b2)));
    if (dx_i != 0 or dy_i != 0) moved_since_frame = true;

    pos_x += dx_i;
    pos_y -= dy_i;
    const sw: i32 = @intCast(@import("../fb_console.zig").screenWidth());
    const sh: i32 = @intCast(@import("../fb_console.zig").screenHeight());
    if (pos_x < 0) pos_x = 0;
    if (pos_y < 0) pos_y = 0;
    if (pos_x >= sw) pos_x = sw - 1;
    if (pos_y >= sh) pos_y = sh - 1;
}

fn feedByte(b: u8) void {
    if (packet_idx == 0) {
        if ((b & 8) == 0 and b != 0xFA) return;
    }
    packet[packet_idx] = b;
    packet_idx +%= 1;
    if (packet_idx == 3) {
        packet_idx = 0;
        applyPacket();
    }
}

/// 由 PS/2 8042 去抖（IRQ1 上发现 AUX 位时）转发鼠标包字节。
pub fn feedRawMouseByte(b: u8) void {
    feedByte(b);
}

pub fn onIrq12() void {
    while (true) {
        const st = portio.inb(0x64);
        if ((st & 1) == 0) return;
        if (!isAuxData(st)) return;
        feedByte(portio.inb(0x60));
    }
}

/// 主循环轮询：部分 QEMU/环境下 IRQ12 不可靠时仍能收包。
pub fn poll() void {
    while (true) {
        const st = portio.inb(0x64);
        if ((st & 1) == 0) return;
        if (!isAuxData(st)) return;
        feedByte(portio.inb(0x60));
    }
}

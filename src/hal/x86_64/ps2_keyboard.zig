//! PS/2 键盘（8042 端口 0x60，IRQ1）。扫描码 Set 1；扩展键前缀 0xE0。

const portio = @import("portio.zig");
const mouse = @import("ps2_mouse.zig");
const ntuser = @import("../../subsystems/zircon64/ntuser.zig");

var e0_prefix: bool = false;

fn isAuxData(st: u8) bool {
    return (st & 0x20) != 0;
}

fn vkFromSet1Make(sc: u8) ?u32 {
    return switch (sc) {
        0x01 => 0x1B, // VK_ESCAPE
        0x0F => 0x09, // VK_TAB
        0x1C => 0x0D, // VK_RETURN
        0x39 => 0x20, // VK_SPACE
        else => null,
    };
}

fn postMakeVk(vk: u32) void {
    _ = ntuser.postKeyDownToDesktop(vk);
}

fn postBreakVk(vk: u32) void {
    _ = ntuser.postKeyUpToDesktop(vk);
}

fn feedKeyboardByte(b: u8) void {
    if (b == 0xFA or b == 0xFE) return;

    if (e0_prefix) {
        e0_prefix = false;
        if ((b & 0x80) != 0) {
            if ((b & 0x7F) == 0x5B) postBreakVk(0x5B);
        } else {
            if (b == 0x5B) postMakeVk(0x5B); // VK_LWIN
        }
        return;
    }
    if (b == 0xE0) {
        e0_prefix = true;
        return;
    }
    if (b == 0xE1) return; // Pause 序列，忽略

    if ((b & 0x80) != 0) {
        const mk = b & 0x7F;
        if (vkFromSet1Make(mk)) |vk| postBreakVk(vk);
        return;
    }
    if (vkFromSet1Make(b)) |vk| postMakeVk(vk);
}

pub fn onIrq1() void {
    while (true) {
        const st = portio.inb(0x64);
        if ((st & 1) == 0) return;
        const b = portio.inb(0x60);
        if (isAuxData(st)) {
            mouse.feedRawMouseByte(b);
        } else {
            feedKeyboardByte(b);
        }
    }
}

pub fn init() void {
    while ((portio.inb(0x64) & 1) != 0) {
        _ = portio.inb(0x60);
    }
}

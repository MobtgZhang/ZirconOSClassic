//! x86_64 — minimal bring-up (Multiboot2 / UEFI handoff via shared kernel_main).
const serial = @import("../../hal/x86_64/serial.zig");
const gdt = @import("../../hal/x86_64/gdt.zig");
const pic = @import("../../hal/x86_64/pic.zig");
const pit = @import("../../hal/x86_64/pit.zig");

pub const name: []const u8 = "x86_64";
pub const boot = @import("boot.zig");
pub const paging = @import("paging.zig");

pub const PAGE_SIZE: usize = 4096;

const idt = if (@import("build_options").enable_idt) struct {
    const mod = @import("idt.zig");
    pub fn init() void {
        mod.init();
    }
} else struct {
    pub fn init() void {}
};

comptime {
    if (@import("build_options").enable_idt) {
        _ = @import("isr.zig");
    }
}

pub fn initSerial() void {
    serial.init();
}

pub fn initGdt(kernel_stack: u64) void {
    gdt.init(kernel_stack);
}

pub fn initPic() void {
    pic.init();
}

pub fn initTimer() void {
    pit.init();
}

pub fn initIdt() void {
    idt.init();
}

pub fn sendEoi(irq: u8) void {
    pic.sendEoi(irq);
}

pub fn unmaskIrq(irq: u8) void {
    pic.unmaskIrq(irq);
}

pub fn enableInterrupts() void {
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    asm volatile ("cli");
}

pub fn handleKeyboardIrq() void {
    @import("../../hal/x86_64/ps2_keyboard.zig").onIrq1();
}
pub fn handleMouseIrq() void {
    @import("../../hal/x86_64/ps2_mouse.zig").onIrq12();
}

pub fn consoleWrite(s: []const u8) void {
    serial.write(s);
}

pub fn serialWrite(s: []const u8) void {
    serial.write(s);
}

pub fn waitForInterrupt() void {
    asm volatile ("hlt");
}

pub fn halt() noreturn {
    while (true) {
        waitForInterrupt();
    }
}

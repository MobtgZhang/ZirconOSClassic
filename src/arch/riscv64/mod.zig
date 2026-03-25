const uart = @import("../../hal/riscv64/uart.zig");

pub const boot = @import("boot.zig");

extern fn kernel_main(magic: u32, info_addr: usize) callconv(.c) noreturn;

pub const name: []const u8 = "riscv64";
pub const PAGE_SIZE: usize = 4096;

pub export fn _start() callconv(.c) noreturn {
    kernel_main(0, 0);
}

pub fn initSerial() void {
    uart.init();
}

pub fn consoleWrite(s: []const u8) void {
    uart.write(s);
}

pub fn serialWrite(s: []const u8) void {
    uart.write(s);
}

pub fn waitForInterrupt() void {
    asm volatile ("wfi");
}

pub fn halt() noreturn {
    while (true) {
        waitForInterrupt();
    }
}

//! LoongArch64 — `_start` in crt0.S；UEFI 经 `.uefi_vector` 直入 `kernel_main` + Multiboot2（见 docs/BOOT_ABI.md）。
const uart = @import("../../hal/loongarch64/uart.zig");

pub const boot = @import("boot.zig");

extern fn kernel_main(magic: u32, info_addr: usize) callconv(.c) noreturn;

pub const name: []const u8 = "loongarch64";
pub const PAGE_SIZE: usize = 4096;

/// 对齐 [ChimeraOS main_loong64.zig](https://github.com/MobtgZhang/ChimeraOS/blob/main/src/main_loong64.zig) 中
/// `CRMD = PLV0 | DA | DATF(01) | DATM(01)`（即常数 0xA8 里的 DA + DAT 域），但**保留**固件留下的 **PG/IE/PLV**。
/// Chimera 在整段写入 0xA8 时会关掉 PG（其内核随后用 DMW 等自建映射）；本内核仍依赖 UEFI 恒等映射，整写 0xA8 会关分页导致崩溃。
/// 掩码 0x1E8 = DA(bit3) | DATF(bits5-6) | DATM(bits7-8)。
pub fn applyCrmdCachedDa() void {
    const old = asm volatile ("csrrd %[r], 0x0"
        : [r] "=r" (-> usize),
    );
    const patched = (old & ~@as(usize, 0x1E8)) | 0xA8;
    asm volatile ("csrwr %[val], 0x0"
        :
        : [val] "r" (patched),
        : .{ .memory = true }
    );
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
    asm volatile ("idle 0");
}

pub fn halt() noreturn {
    while (true) {
        waitForInterrupt();
    }
}

/// `qemu_run.sh` 默认 `-smp 2`：若多核均进入 `kernel_main`，会与 BSP 竞态破坏 virtio 等共享状态。
/// `LOONGARCH_CSR_CPUID`（0x20）低 9 位为核号，非 0 核在此自旋。
pub fn parkSecondaryCpusIfNeeded() void {
    const raw = asm volatile ("csrrd %[r], 0x20"
        : [r] "=r" (-> usize),
    );
    if ((raw & 0x1ff) != 0) {
        while (true) {
            asm volatile ("idle 0");
        }
    }
}

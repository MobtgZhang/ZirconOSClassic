//! LoongArch64 QEMU virt：CSR 核心定时器 + EENTRY。具体 trap 里调用的子系统由 `mod.zig` 的
//! `loongarchTrapHandler` 完成，避免与本文件形成 import 环。

const klog = @import("../../rtl/klog.zig");

extern const loongarch_trap_entry: u8;

const CSR_CRMD: u12 = 0x0;
const CSR_ECFG: u12 = 0x4;
const CSR_ESTAT: u12 = 0x5;
const CSR_EENTRY: u12 = 0xc;
const CSR_TCFG: u12 = 0x41;
const CSR_TINTCLR: u12 = 0x44;

const ESTAT_IS_TIMER: usize = 1 << 11;
const CRMD_IE: usize = 1 << 2;

fn csrRd(comptime csr: u12) usize {
    return asm volatile ("csrrd %[out], %[c]"
        : [out] "=r" (-> usize),
        : [c] "i" (csr),
    );
}

fn csrWr(comptime csr: u12, val: usize) void {
    asm volatile ("csrwr %[v], %[c]"
        :
        : [v] "r" (val),
          [c] "i" (csr),
        : .{ .memory = true }
    );
}

pub fn initTimerAndTrap() void {
    const entry = @intFromPtr(&loongarch_trap_entry);
    csrWr(CSR_EENTRY, entry);

    const ecfg = csrRd(CSR_ECFG);
    csrWr(CSR_ECFG, ecfg | ESTAT_IS_TIMER);

    const ticks: usize = 0x100000;
    const tcfg: usize = (ticks << 2) | 1 | 2;
    csrWr(CSR_TCFG, tcfg);

    klog.info("LoongArch: timer+trap (EENTRY=0x%x TCFG ticks=0x%x)", .{ entry, ticks });
}

pub fn enableInterrupts() void {
    const crmd = csrRd(CSR_CRMD);
    csrWr(CSR_CRMD, crmd | CRMD_IE);
    klog.info("LoongArch: CRMD.IE enabled", .{});
}

fn haltForever() noreturn {
    while (true) {
        asm volatile ("idle 0" ::: .{ .memory = true });
    }
}

/// 由 `loongarchTrapHandler` 调用：确认并清除定时器中断；非定时器则停机。
pub fn clearTimerInterruptOrHalt() void {
    const estat = csrRd(CSR_ESTAT);
    if ((estat & ESTAT_IS_TIMER) == 0) {
        klog.err("LoongArch: unexpected ESTAT=0x%x (expected timer)", .{estat});
        haltForever();
    }
    csrWr(CSR_TINTCLR, 1);
}

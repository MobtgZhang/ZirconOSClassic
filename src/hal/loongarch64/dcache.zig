//! QEMU `loongarch64` 客户机下 RAM 与 virtio DMA 通常一致；此前使用的 `cacop` 在 QEMU la464 上
//! 曾导致非法指令/死机（日志止于 `CSRSS: initStub` 之后）。真机若需一致性可再按 CPUCFG 加回行刷新。
//!
//! 此处仅保留内存屏障，保证描述符 / avail / 与 MMIO 顺序。

pub fn syncToDevice(_: usize, _: usize) void {
    asm volatile ("dbar 0"
        :
        :
        : .{ .memory = true }
    );
}

pub fn syncFromDevice(_: usize, _: usize) void {
    asm volatile ("dbar 0"
        :
        :
        : .{ .memory = true }
    );
}

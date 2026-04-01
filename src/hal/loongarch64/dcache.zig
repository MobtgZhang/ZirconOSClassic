//! QEMU `loongarch64` 客户机下 RAM 与 virtio DMA 通常一致；此前使用的 `cacop` 在 QEMU la464 上
//! 曾导致非法指令/死机（日志止于 `CSRSS: initStub` 之后）。真机若需一致性可再按 CPUCFG 加回行刷新。
//!
//! 此处仅保留内存屏障，保证描述符 / avail / 与 MMIO 顺序。
//! 跟进验证：在 `SDL_VIDEODRIVER=dummy` + ramfb/virtio-gpu 下桌面会话可进入会话循环；未见需对线性 FB 额外写回才能显示
//! 的征象前，勿贸然在此加入整区 `cacop`（避免再次触发非法指令）。

pub fn memoryFence() void {
    asm volatile ("dbar 0"
        :
        :
        : .{ .memory = true }
    );
}

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

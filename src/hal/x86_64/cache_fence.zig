//! QEMU x86 上 virtio 环与 RAM 一致性：保守使用 `mfence`（无 LoongArch `cacop` 路径）。
//! 若引导环境将帧缓冲映射为 UC/WC，通常仍安全。

pub fn memoryFence() void {
    asm volatile ("mfence"
        :
        :
        : .{ .memory = true }
    );
}

pub fn syncToDevice(_: usize, _: usize) void {
    memoryFence();
}

pub fn syncFromDevice(_: usize, _: usize) void {
    memoryFence();
}

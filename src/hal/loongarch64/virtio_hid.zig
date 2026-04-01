//! QEMU `virtio-keyboard-pci` + `virtio-tablet-pci`（PCI 1af4:1052）。LoongArch：`virt` ECAM + `dcache` 屏障。
//!
//! **实现**：`hal/virtio_input_pci.zig`（VirtIO 1.x + Linux evdev 公开语义；**不含**微软/WDK 代码）。通过 `Input` 类型访问静态状态与方法。
//! **软件光标**见 `cursor_overlay.zig`，与 `idea1.md` 中软件指针模型对应。

const builtin = @import("builtin");
const pci_ecam = @import("pci_ecam.zig");
const dcache = @import("dcache.zig");

comptime {
    if (builtin.target.cpu.arch != .loongarch64) {
        @compileError("virtio_hid.zig is LoongArch64-only");
    }
}

/// 平台绑定的 VirtIO-input 驱动（单例式 `var` 状态在类型上）。
pub const Input = @import("../virtio_input_pci.zig").Driver(pci_ecam, dcache);

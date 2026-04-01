//! 显示后端启动顺序（x86_64）：Intel 核显探测优先，否则尝试 virtio-gpu；均无则依赖 Multiboot2 GOP。

const builtin = @import("builtin");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");

pub fn tryInitEarlyDisplay() void {
    if (builtin.target.cpu.arch != .x86_64) return;
    if (fb.isReady()) return;

    const intel = @import("../x86_64/intel_igpu.zig");
    if (intel.probeAndEnable()) {
        klog.info("display: using Intel iGPU path (framebuffer from bootloader GOP if present)", .{});
        return;
    }

    const virtio = @import("../x86_64/virtio_gpu.zig");
    virtio.tryInitQemuVirtioGpuFramebuffer();
    if (fb.isReady()) {
        klog.info("display: using virtio-gpu scanout", .{});
    }
}

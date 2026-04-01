//! QEMU `loongarch64` `virt`：PCI virtio-gpu-pci（0x1af4/0x1050），ECAM 见 `pci_ecam.zig`。
//! 核心逻辑在 `hal/virtio_gpu_pci.zig`。

const builtin = @import("builtin");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");
const pci_ecam = @import("pci_ecam.zig");
const dcache = @import("dcache.zig");
const vgpu = @import("../virtio_gpu_pci.zig");
const Impl = vgpu.Gpu(pci_ecam, dcache);

comptime {
    if (builtin.target.cpu.arch != .loongarch64) {
        @compileError("virtio_gpu.zig is LoongArch64-only");
    }
}

const VIRTIO_PCI_VENDOR: u16 = 0x1af4;
const VIRTIO_GPU_DEVICE_MODERN: u16 = 0x1050;

fn findGpuPci() ?vgpu.PciLoc {
    var dev: u8 = 0;
    while (dev < 32) : (dev += 1) {
        const v0 = pci_ecam.read32(0, dev, 0, 0);
        const ven = @as(u16, @truncate(v0));
        if (ven == 0xFFFF) continue;
        const did = @as(u16, @truncate(v0 >> 16));
        if (ven == VIRTIO_PCI_VENDOR and did == VIRTIO_GPU_DEVICE_MODERN) {
            return .{ .bus = 0, .dev = dev, .func = 0 };
        }
    }
    return null;
}

pub fn tryInitQemuVirtioGpuFramebuffer() void {
    if (fb.isReady()) return;

    const loc = findGpuPci() orelse {
        klog.info("virtio-gpu: no PCI 1af4:1050", .{});
        return;
    };
    if (Impl.tryInitAt(loc)) {
        @import("virtio_hid.zig").Input.syncPointerAfterFramebufferChange();
    }
}

pub fn flushScanoutIfActive() void {
    Impl.flushScanoutIfActive();
}

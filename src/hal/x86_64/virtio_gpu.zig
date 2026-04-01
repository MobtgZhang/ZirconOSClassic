//! x86_64：PCI `virtio-gpu-pci`（0x1af4/0x1050），配置空间经 `pci.zig` I/O 端口访问。

const builtin = @import("builtin");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");
const pci = @import("pci.zig");
const cache_fence = @import("cache_fence.zig");
const vgpu = @import("../virtio_gpu_pci.zig");
const Impl = vgpu.Gpu(pci, cache_fence);

comptime {
    if (builtin.target.cpu.arch != .x86_64) {
        @compileError("virtio_gpu.zig is x86_64-only");
    }
}

const VIRTIO_PCI_VENDOR: u16 = 0x1af4;
const VIRTIO_GPU_DEVICE_MODERN: u16 = 0x1050;

fn findGpuPci() ?vgpu.PciLoc {
    var bus: u16 = 0;
    while (bus < 256) : (bus += 1) {
        var dev: u8 = 0;
        while (dev < 32) : (dev += 1) {
            var func: u8 = 0;
            while (func < 8) : (func += 1) {
                const v0 = pci.vendorDevice(@truncate(bus), dev, func);
                const ven = @as(u16, @truncate(v0));
                if (pci.isEmptyVendor(ven)) {
                    if (func == 0) break;
                    continue;
                }
                const did = @as(u16, @truncate(v0 >> 16));
                if (ven == VIRTIO_PCI_VENDOR and did == VIRTIO_GPU_DEVICE_MODERN) {
                    return .{ .bus = @truncate(bus), .dev = dev, .func = func };
                }
                if (func == 0) {
                    const ht = pci.read8(@truncate(bus), dev, 0, 0x0e);
                    if ((ht & 0x80) == 0) break;
                }
            }
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
    _ = Impl.tryInitAt(loc);
}

pub fn flushScanoutIfActive() void {
    Impl.flushScanoutIfActive();
}

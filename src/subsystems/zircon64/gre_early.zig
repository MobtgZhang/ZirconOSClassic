//! Multiboot2 帧缓冲 + 桌面 GRE 早期初始化（x86_64 / aarch64 / loongarch64）。
const builtin = @import("builtin");
const arch = @import("../../arch.zig");
const klog = @import("../../rtl/klog.zig");
const boot = arch.impl.boot;

pub fn initAfterBoot(magic: u32, info_addr: usize) void {
    if (magic != boot.MULTIBOOT2_BOOTLOADER_MAGIC) {
        klog.debug("gre: not Multiboot2 (magic=0x%x), skip GRE", .{magic});
        return;
    }
    const bi = boot.parse(magic, info_addr) orelse {
        klog.warn("gre: Multiboot2 parse failed", .{});
        return;
    };

    const fbmod = @import("../../hal/fb_console.zig");

    if (bi.fb_info) |fbi| {
        if (fbi.fb_type == 2) {
            klog.info("gre: framebuffer tag is EGA text (type=2), skip graphics", .{});
            return;
        }
        if (fbi.width == 0 or fbi.height == 0 or fbi.bpp == 0) {
            klog.warn("gre: invalid FB dimensions %ux%u@%u", .{ fbi.width, fbi.height, fbi.bpp });
            return;
        }

        klog.info("gre: FB addr=0x%x %ux%u pitch=%u bpp=%u bgr=%u type=%u", .{
            @as(usize, @truncate(fbi.addr)),
            fbi.width,
            fbi.height,
            fbi.pitch,
            fbi.bpp,
            fbi.pixel_bgr,
            fbi.fb_type,
        });

        // LoongArch + UEFI：ZBM 常同时带 ramfb 与 GOP tag。若保留 ramfb 地址而屏上实际扫描的是 GOP 物理区，会出现「进不了桌面/黑屏」。
        // x86 上 virtio-gpu 后备缓冲在内核 BSS，必须用 scanout，不可被 GOP tag 覆盖。
        const keep_driver_fb = fbmod.isReady() and builtin.target.cpu.arch != .loongarch64;

        if (keep_driver_fb) {
            klog.info("gre: framebuffer already active (e.g. virtio-gpu), not replacing with GOP tag", .{});
        } else {
            fbmod.initEx(
                @intCast(fbi.addr),
                fbi.width,
                fbi.height,
                fbi.pitch,
                fbi.bpp,
                fbi.pixel_bgr != 0,
            );
            if (builtin.target.cpu.arch == .loongarch64) {
                @import("../../hal/loongarch64/virtio_hid.zig").Input.syncPointerAfterFramebufferChange();
            }
        }
    } else if (fbmod.isReady()) {
        klog.info("gre: linear FB from arch driver (e.g. virtio-gpu / ramfb)", .{});
    } else {
        klog.info("gre: no framebuffer tag (serial-only session)", .{});
        return;
    }

    if (!fbmod.isReady()) return;

    const desktop_session = @import("desktop_session.zig");
    desktop_session.bootstrapFromBootInfo(bi);
    const ntuser = @import("ntuser.zig");
    klog.info("gre: session bootstrap complete (desktop_id=%u)", .{ntuser.interactive_desktop_id});
}

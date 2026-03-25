//! 显示路径聚合（对齐 ZirconOS `drivers/video/`）。
//! 通过 I/O 管理器注册 `\\Device\\Video0`，帧缓冲绘制在 `hal/*/framebuffer.zig`。

const klog = @import("../../rtl/klog.zig");
const io = @import("../../io/mod.zig");

pub fn initStub() void {
    _ = io.videoDevice();
    klog.info("VIDEO: bound to IoMgr Video0 FDO", .{});
}

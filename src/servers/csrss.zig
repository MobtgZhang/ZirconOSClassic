//! Client/Server Runtime 子系统进程（CSRSS）— 用户态服务桩，与 `lpc` 端口对应。

const klog = @import("../rtl/klog.zig");
const lpc = @import("../lpc/mod.zig");

/// SMSS 编排之后：与内核 LPC 握手并登记图形运行时（PID 桩 8）。
pub fn bootstrapAfterSmss() void {
    if (!lpc.isCsrssPortReady()) {
        klog.warn("CSRSS: LPC ApiPort not ready", .{});
        return;
    }
    _ = lpc.csrssClientHello(8);
    _ = lpc.csrssRegisterGre(8);
    klog.info("CSRSS: GRE registered (stub pid=8)", .{});
}

pub fn initStub() void {
    if (lpc.isCsrssPortReady()) {
        klog.info("CSRSS: initStub (handshake done in SMSS bootstrap)", .{});
    } else {
        klog.warn("CSRSS: LPC port not ready", .{});
    }
}

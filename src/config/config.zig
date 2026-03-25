//! 配置入口（NT 5.0 产品线；完整 INI 解析见上游 ZirconOS `config/parser.zig`）。
const defaults = @import("defaults.zig");
const klog = @import("../rtl/klog.zig");

var initialized: bool = false;

pub fn init() void {
    if (initialized) return;
    initialized = true;
    klog.info("Config: embedded defaults (NT 5.0) — system %u bytes, boot %u bytes, desktop %u bytes", .{
        @as(u32, @truncate(defaults.system_conf.len)),
        @as(u32, @truncate(defaults.boot_conf.len)),
        @as(u32, @truncate(defaults.desktop_conf.len)),
    });
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn productName() []const u8 {
    return "ZirconOS Classic (NT 5.0)";
}

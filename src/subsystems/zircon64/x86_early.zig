//! 兼容别名：早期 GRE 路径已合并到 `gre_early.zig`（Multiboot2 + UEFI ZBM）。
pub const initAfterBoot = @import("gre_early.zig").initAfterBoot;

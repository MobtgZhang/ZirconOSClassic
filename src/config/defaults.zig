//! 编译期嵌入默认配置（对齐 ZirconOS `config/defaults.zig`；产品线为 NT 5.0）。
pub const system_conf = @embedFile("system.conf");
pub const boot_conf = @embedFile("boot.conf");
pub const desktop_conf = @embedFile("desktop.conf");

//! 多架构桌面像素尺寸约定：LoongArch ramfb 固定用此分辨率；与 QEMU x86_64 + OVMF 常见 GOP（1280×800）对齐。
//! x86_64 仍由 Multiboot2 tag 8（固件 GOP）决定实际尺寸；若需完全一致可在固件侧设相同模式。
pub const width: u32 = 1280;
pub const height: u32 = 800;
pub const stride: u32 = width * 4;

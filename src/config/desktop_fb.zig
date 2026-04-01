//! LoongArch ramfb / virtio-gpu 后备帧缓冲的像素约定（与 ZBM 在 GOP 上优先设置的 1024×768×32 一致）。
//! 本文件仅被 `src/hal/loongarch64/*` 引用；x86_64 仍由 Multiboot2 tag 8（固件 GOP）决定实际尺寸。
pub const width: u32 = 1024;
pub const height: u32 = 768;
pub const stride: u32 = width * 4;

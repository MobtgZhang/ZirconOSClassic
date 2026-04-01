//! **长期规划**：Intel 显示引擎内核 modeset（无 GOP 时建立线性帧缓冲）。
//!
//! 需分代实现，参考：
//! - Intel Graphics Programmer's Reference Manual（Skylake / Kaby Lake / … 分卷）
//! - Linux `drivers/gpu/drm/i915/`（display、memory、GuC/HuC）
//!
//! 建议里程碑：
//! 1. OpRegion / ACPI 与 stolen memory 范围解析
//! 2. 固定模式单分辨率 pipe/plane 最小序列（Gen9）
//! 3. 与 `fb_console` 及桌面会话的像素格式约定对齐
//!
//! 当前内核阶段：**不实现**上述逻辑；实机依赖 UEFI GOP，`intel_igpu.zig` 仅做 PCI 绑定与日志。
